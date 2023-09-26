print(
    """
-----------------------------------------------------------------
✨ Hello Tilt! This appears in the (Tiltfile) pane whenever Tilt
   evaluates this file.
-----------------------------------------------------------------
""".strip()
)

load("ext://syncback", "syncback")

docker_build(
    "my_awesome_sixie_project_local_django",
    context="backend",
    build_args={"DEVEL": "yes"},
    live_update=[
        sync("./backend/my_awesome_sixie_project", "/app/src/my_awesome_sixie_project"),
    ],
)

docker_build(
    "my_awesome_sixie_project_local_frontend",
    context="frontend",
    live_update=[
        sync("./frontend", "/app"),
    ],
)

k8s_yaml(
    kustomize("./k8s/local/")
)

syncback(
    "backend-sync",
    "deploy/django",
    "/app/src/my_awesome_sixie_project/",
    target_dir="./backend/my_awesome_sixie_project",
    rsync_path='/app/bin/rsync.tilt',
)

syncback(
    "frontend-sync",
    "deploy/frontend",
    "/app/",
    target_dir="./frontend",
    rsync_path='/app/rsync.tilt',
)

k8s_resource(workload='frontend', port_forwards=3000)
k8s_resource(workload='django', port_forwards=8000)
k8s_resource(workload='mailhog', port_forwards=8025)
k8s_resource(workload='postgres', port_forwards=5432)
