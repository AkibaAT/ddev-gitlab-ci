FROM docker:latest

LABEL org.opencontainers.image.source=https://github.com/akibaat/ddev-gitlab-ci

ARG ddev_version
ENV DDEV_VERSION=${ddev_version}
ENV DOCKER_HOST=unix:///var/run/dind-docker.sock

COPY ddev-install.sh ddev-install.sh
COPY ddev-entrypoint.sh /usr/local/bin/ddev-entrypoint.sh
RUN ash ddev-install.sh \
    && addgroup ddev docker \
    && apk --no-cache add fuse-overlayfs shadow yq \
    && sudo -u ddev mkcert -install

COPY --from=tianon/gosu /gosu /usr/local/bin/
COPY --chown=ddev:ddev global-config.yaml /home/ddev/.ddev/global_config.yaml
WORKDIR /home/ddev
ENTRYPOINT ["/usr/local/bin/ddev-entrypoint.sh"]
CMD ["tail", "-f", "/dev/null"]
