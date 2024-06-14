# Useful Podman commands

## About Podman

[Podman](https://podman.io/get-started) is an utility to create and maintain containers from Red Hat. 
It was designed to address some of the shortcomings of Docker, including but not restricted to:
- single point of failure
- dangling processes in case of failures
- security vulnerabilities building and running containers
- restricted to Docker containers only

Please refer to [this blog post](https://developers.redhat.com/blog/2019/02/21/podman-and-buildah-for-docker-users#how_does_docker_work_) to get more information.

## Useful commands

| Task description                                            | `shell` command                                                                           |
| ----------------------------------------------------------- | ----------------------------------------------------------------------------------------- |
| Load local Docker images into local Podman image repository | `➜  ~ docker images --format docker-daemon:{{.Repository}}:{{.Tag}} \| xargs podman pull` |