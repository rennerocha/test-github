generate-tfvars:
	terraform apply -refresh-only -auto-approve
	bin/generate-tfvars

key-pair:
	ssh-keygen -t ED25519 -f ~/.ssh/my_awesome_sixie_project_default_key -N ""

plan:
	terraform plan

deploy:
	terraform apply -auto-approve

INSTANCE_IP :=  $(shell ./bin/ip | sed 's/"//g')

config:
	ssh -oStrictHostKeyChecking=no -i ~/.ssh/my_awesome_sixie_project_default_key \
		ubuntu@$(INSTANCE_IP) \
		'curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--tls-san $(INSTANCE_IP)" K3S_KUBECONFIG_MODE="644" sh -s -'
	ssh -oStrictHostKeyChecking=no -i ~/.ssh/my_awesome_sixie_project_default_key \
		ubuntu@$(INSTANCE_IP) cat /etc/rancher/k3s/k3s.yaml \
		> ~/.kube/my_awesome_sixie_project.ec2.config
	sed -ie 's/127.0.0.1/$(INSTANCE_IP)/' ~/.kube/my_awesome_sixie_project.ec2.config
	sed -ie 's/default/my_awesome_sixie_project-ec2-cluster/' ~/.kube/my_awesome_sixie_project.ec2.config
	export KUBECONFIG=~/.kube/my_awesome_sixie_project.ec2.config
	kubectl config get-contexts
	kubectl config use-context my_awesome_sixie_project-ec2-cluster
	# do not apply cloudconfig in sandbox
	# kubectl apply -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/release-1.20/releases/cnpg-1.20.0.yaml
	kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.12.0/cert-manager.yaml
	kubectl apply -f config.yml

ssh:
	./bin/ssh

show-ip:
	@./bin/ip

destroy:
	terraform destroy

kubecreds:
	aws sso login --profile=my_awesome_sixie_project
	aws ecr get-login-password --region us-east-1 | docker login --username AWS \
		--password-stdin 000000000000.dkr.ecr.us-east-1.amazonaws.com
	kubectl delete secret regcred -n my-awesome-sixie-project --ignore-not-found
	kubectl delete secret regcred -n my-awesome-sixie-project-sandbox --ignore-not-found
	kubectl create secret docker-registry regcred -n my-awesome-sixie-project \
		--docker-server=000000000000.dkr.ecr.us-east-1.amazonaws.com \
		--docker-username=AWS \
		--docker-password=$(shell aws ecr get-login-password)
	kubectl create secret docker-registry regcred -n my-awesome-sixie-project-sandbox \
		--docker-server=000000000000.dkr.ecr.us-east-1.amazonaws.com \
		--docker-username=AWS \
		--docker-password=$(shell aws ecr get-login-password)
