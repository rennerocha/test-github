TAG?=dev
PGPORT?=5432
DUMPFILE?=sandbox.dump
RELEASE_TAG?=unspecified

sandbox-release: RELEASE_DATE :=  $(shell date +"%Y-%m-%d")
sandbox-release: RELEASE_LETTER := $(strip $(shell git tag -l | grep $(RELEASE_DATE) | wc -l | tr 0123456789 abcdefghij ))
sandbox-release: RELEASE_TAG := $(RELEASE_DATE)$(RELEASE_LETTER)

build: export DOCKER_BUILDKIT = 1
build: ./backend/Dockerfile backend/requirements/production.txt ./frontend/Dockerfile ## Create the build and runtime images
	@docker build -t test_project_local_django:$(TAG) ./backend
	

#build-front-end:  ## Build the front-end React app
#	@docker-compose exec front-end npm run build

destroy-data: ## Remove the database volumes and start with a clean database
	@docker-compose stop db
	@docker-compose rm -f db
	@docker volume rm test_project_local_postgres_data
	@docker volume rm test_project_local_postgres_data_backups
	@docker-compose up -d db


clean: ## Remove the latest build
	@docker rmi -f test_project_local_django:$(TAG)


squeaky-clean:  clean  ## Removes the resources not associated with a container, this is a quick way to get rid of old images, containers, volumes, and networks
	@docker rmi python:3.10-slim-bullseye
	@docker rmi postgres:14
	@docker rmi mailhog/mailhog:v1.0.0
	@docker rmi node:16-bullseye-slim
	@docker rmi redis:6.2
	@docker system prune -a
	@for image in `docker images -f "dangling=true" -q`; do \
		echo removing $$image && docker rmi $$image ; done

update: ## Pull the latest image from a registry
	@docker pull python:3.10-slim-bullseye
	@docker pull postgres:14
	@docker pull mailhog/mailhog:v1.0.0
	@docker pull node:16-bullseye-slim
	@docker pull redis:6.2


## Release/Deployment Targets

.PHONY: ci
ci: test secure build  ## Execute the same checks used in CI/CD

check-lint-and-formatting:  ## Execute check of lint and formatting using existing pre-commit hooks
	pip install pre-commit; \
	cd backend/; \
	pre-commit install; \
	pre-commit run -a

sandbox-release: ## create release tag and push to master
	@echo "release tag: $(RELEASE_TAG)"
	@git tag $(RELEASE_TAG)
	@git push --tags

staging-release: ## update pipeline tag and execute
ifeq ($(RELEASE_TAG), unspecified)
	@echo "provide a valid RELEASE_TAG argument"
	git tag -l
endif
	@echo "release tag: $(RELEASE_TAG)"
	@git tag -l | grep $(RELEASE_TAG) | wc -l | awk '$$1 != 1 {print "RELEASE_TAG does not match any git tag"; exit 1 }'
	@aws --profile=test_project-deploy ecr batch-get-image --repository-name test_project --image-ids imageTag=$(RELEASE_TAG) \
		| jq '.images | length'| awk '$$1 != 1 {print "RELEASE_TAG does not match any ECR images"; exit 1 }'
	@aws --profile=test_project-deploy codepipeline get-pipeline --name test_project-staging \
		| jq 'del(.metadata) | .pipeline.stages[0].actions[0].configuration.ImageTag = "$(RELEASE_TAG)"' \
		| xargs -0 aws --profile=test_project-deploy codepipeline update-pipeline --cli-input-json 1>/dev/null
	@aws --profile=test_project-deploy codepipeline start-pipeline-execution --name test_project-staging

prod-release: ## update pipeline tag and execute
ifeq ($(RELEASE_TAG), unspecified)
	@echo "provide a valid RELEASE_TAG argument"
	git tag -l
endif
	@echo "release tag: $(RELEASE_TAG)"
	@git tag -l | grep $(RELEASE_TAG) | wc -l | awk '$$1 != 1 {print "RELEASE_TAG does not match any git tag"; exit 1 }'
	@aws --profile=test_project-deploy ecr batch-get-image --repository-name test_project --image-ids imageTag=$(RELEASE_TAG) \
		| jq '.images | length'| awk '$$1 != 1 {print "RELEASE_TAG does not match any ECR images"; exit 1 }'
	@aws --profile=test_project-deploy codepipeline get-pipeline --name test_project-prod \
		| jq 'del(.metadata) | .pipeline.stages[0].actions[0].configuration.ImageTag = "$(RELEASE_TAG)"' \
		| xargs -0 aws --profile=test_project-deploy codepipeline update-pipeline --cli-input-json 1>/dev/null
	@aws --profile=test_project-deploy codepipeline start-pipeline-execution --name test_project-prod

check-x-release = @aws --profile=test_project-deploy codepipeline get-pipeline-state --name test_project-$(subst check-,,$(subst -release,,$@))  | jq '.stageStates[0].latestExecution.pipelineExecutionId as $$execId | { Pipeline: .pipelineName, Started: .stageStates[0].actionStates[0].latestExecution.lastStatusChange, Actions: .stageStates | map( .latestExecution.pipelineExecutionId as $$stage_execId | .actionStates | map( { (.actionName): (if $$stage_execId == $$execId then .latestExecution.status else "Pending" end) } ))  | flatten | add }'

check-sandbox-release check-staging-release check-prod-release: ## check status of release pipeline
	$(check-x-release)

## Development Targets

backend/requirements/local.txt: compile
backend/requirements/production.txt: compile
backend/requirements/tests.txt: compile

build-dev: export DOCKER_BUILDKIT = 1
build-dev: ./backend/Dockerfile backend/requirements/local.txt ./frontend/Dockerfile ## Create the dev build and runtime images
	@docker build --build-arg DEVEL=yes --build-arg TEST=yes -t test_project_local_django:dev ./backend
	

outdated: ## Show all the outdated packages with their latest versions in the container
	@docker run --rm test_project_local_django:$(TAG) pip list --outdated

pipdeptree: ## Show the dependencies of installed packages as a tree structure
	@docker run --rm test_project_local_django:$(TAG) pipdeptree

compile: backend/requirements/base.in backend/requirements/tests.in ## compile latest requirements to be built into the docker image
	@docker run --rm -v $(shell pwd)/backend/requirements:/local python:3.10-slim-bullseye /bin/bash -c \
		"apt-get update; apt-get install -y libpq-dev; \
		 pip install pip-tools; \
		 touch /local/base.txt; touch /local/production.txt; touch /local/tests.txt; touch /local/local.txt; \
		 python -m piptools compile --upgrade --allow-unsafe --generate-hashes --output-file /local/base.txt /local/base.in; \
		 python -m piptools compile --upgrade --allow-unsafe --generate-hashes --output-file /local/production.txt /local/production.in; \
		 python -m piptools compile --upgrade --allow-unsafe --generate-hashes --output-file /local/tests.txt /local/tests.in; \
		 python -m piptools compile --upgrade --allow-unsafe --output-file /local/local.txt /local/local.in"

load-dump: destroy-data ## Fresh load the data file passed in
	@sleep 5
	pg_restore -h localhost -p $(PGPORT) -j 4 -n public --no-owner -U test_project -W -d test_project $(DUMPFILE)

clean-dev: ## Force removal of the latest image
	@docker rmi -f test_project_local_django:dev

up: ## start up the cluster locally
	@docker-compose -f ./docker-compose.yml -f ./docker-compose.override.yml up

down: ## shut down the cluster
	@docker-compose -f ./docker-compose.yml down

down-clean: ## Remove containers for services not defined in the docker-compose.yml file
	@docker-compose -f ./docker-compose.yml down --remove-orphans

test:  ## Run unit tests with PyTest in a running container
	@docker-compose exec django pytest

shell:  ## Shell into the running Django container
	@docker-compose exec django /bin/bash

.PHONY: secure
secure:  ## Analyze dependencies for security issues
	@docker-compose exec django safety check
	#@docker-compose exec django pip-audit --desc

node:  ## Shell into the running Node container
	@docker-compose exec frontend /bin/bash

sandbox-secrets: ## Substitute with secrets template with env variable and run kubeseal
	@echo "Sealing secrets from sandbox template to $$(kubectl config current-context)"
	envsubst < k8s/templates/sandbox.secrets.yaml.template | kubeseal --format yaml > k8s/sandbox/secrets.yaml
	# append the sealedsecrets annotation to the generated secrets manifest for the sandbox namespace
	sed -i -e 's/namespace: test-project/namespace: test-project-sandbox/' -e'/spec:/ {N; s/spec:\n/  annotations:\n    sealedsecrets.bitnami.com\/managed: "true"\nspec:\n/}' k8s/sandbox/secrets.yaml

prod-secrets: ## Substitute with secrets template with env variable and run kubeseal
	@echo "Sealing secrets from prod template to $$(kubectl config current-context)"
	envsubst < k8s/templates/prod.secrets.yaml.template | kubeseal --format yaml > k8s/prod/secrets.yaml
	# append the sealedsecrets annotation to the generated secrets manifest
	sed -i '/spec:/ {N; s/spec:\n/  annotations:\n    sealedsecrets.bitnami.com\/managed: "true"\nspec:\n/}' k8s/prod/secrets.yaml

help: ## Show the list of all the commands and their help text
	@awk 'BEGIN 	{ FS = ":.*##"; target="";printf "\nUsage:\n  make \033[36m<target>\033[33m\n\nTargets:\033[0m\n" } \
		/^[a-zA-Z_-]+:.*?##/ { if(target=="")print ""; target=$$1; printf " \033[36m%-10s\033[0m %s\n\n", $$1, $$2 } \
		/^([a-zA-Z_-]+):/ {if(target=="")print "";match($$0, "(.*):"); target=substr($$0,RSTART,RLENGTH) } \
		/^\t## (.*)/ { match($$0, "[^\t#:\\\\]+"); txt=substr($$0,RSTART,RLENGTH);printf " \033[36m%-10s\033[0m", target; printf " %s\n", txt ; target=""} \
		/^## .*/ {match($$0, "## (.+)$$"); txt=substr($$0,4,RLENGTH);printf "\n\033[33m%s\033[0m\n", txt ; target=""} \
	' $(MAKEFILE_LIST)

.PHONY: help build build-dev outdated pipdeptree compile destroy-data load-dump clean clean-dev squeaky_clean update check-sandbox-release check-staging-release check-prod-release

.DEFAULT_GOAL := help