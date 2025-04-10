#!/usr/bin/env bash
set -e

# docker run -e USER_UID=1001 -e USER_GID=1001
USER_UID=${USER_UID:-1000}
USER_GID=${USER_GID:-1000}

# Check if the container is running in privileged mode.
if grep -q "CapEff:.*ffffffffff" /proc/self/status; then
  # Start the Docker daemon in the background, capturing output.
  dockerd-entrypoint.sh > /tmp/dockerd.log 2>&1 &

  # Wait until the Docker daemon is fully up and running.
  TIMEOUT=30
  START_TIME=$(date +%s)
  until docker info > /dev/null 2>&1; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$(( CURRENT_TIME - START_TIME ))
    if [ $ELAPSED -gt $TIMEOUT ]; then
      echo "Timeout waiting for the Docker daemon to be ready."
      echo "Dockerd error message:"
      cat /tmp/dockerd.log
      exit 1
    fi
    sleep 1
  done
else
  echo "Can't start dockerd as this container is not in privileged mode"
fi

if [ "$(id -u)" = "0" ] && [ "$#" -gt 0 ]; then
  current_gid=$(id -g ddev)
  current_uid=$(id -u ddev)

  if [ "${current_gid}" != "${USER_GID}" ]; then
    groupmod -g "${USER_GID}" ddev
  fi

  # only change user if UID differs
  if [ "${current_uid}" != "${USER_UID}" ]; then
    usermod -u "${USER_UID}" ddev
  fi

  chown ddev:ddev /home/ddev
  exec gosu ddev "$@"
fi

exec "$@"
