# syntax=docker/dockerfile:1-labs
FROM docker:latest

LABEL org.opencontainers.image.source=https://github.com/ddev/ddev-gitlab-ci

ARG ddev_version
ENV DDEV_VERSION=${ddev_version}
ENV DOCKER_HOST=unix:///var/run/docker.sock

COPY ddev-install.sh ddev-install.sh
COPY dockerd-entrypoint.sh /usr/local/bin/dockerd-entrypoint.sh
RUN ash ddev-install.sh \
    && addgroup ddev docker
RUN --security=insecure apk add --no-cache yq fuse-overlayfs \
    && dockerd-entrypoint.sh \
    && docker pull busybox:latest \
    && docker pull ddev/ddev-ssh-agent:${DDEV_VERSION} \
    && docker pull ddev/ddev-traefik-router:${DDEV_VERSION} \
    && docker pull ddev/ddev-utilities:latest \
    && docker pull ddev/ddev-webserver:${DDEV_VERSION} \
    && kill -SIGTERM $(cat /var/run/docker.pid) \
    && rm -rf /var/run/docker.* \
    && rm -rf /var/run/docker/containerd/conntainerd*
USER ddev
RUN mkcert -install
