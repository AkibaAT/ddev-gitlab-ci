#!/usr/bin/env bash
set -e

# Check if the container is running in privileged mode.
if sudo grep -q "CapEff:.*ffffffffff" /proc/self/status; then
  # Start the Docker daemon in the background, capturing output.
  sudo sh -c 'dockerd > /tmp/dockerd.log 2>&1 &'
  DOCKER_PID=$!

  # Wait for the Docker socket to be available.
  TIMEOUT=30
  START_TIME=$(date +%s)
  while [ ! -S /var/run/docker.sock ]; do
    CURRENT_TIME=$(date +%s)
    ELAPSED=$(( CURRENT_TIME - START_TIME ))
    if [ $ELAPSED -gt $TIMEOUT ]; then
      echo "Timeout waiting for /var/run/docker.sock to be created."
      echo "Dockerd error message:"
      cat /tmp/dockerd.log
      exit 1
    fi
    sleep 1
  done

  # Wait until the Docker daemon is fully up and running.
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

# If command-line arguments are provided, execute them.
# Otherwise, use the default command.
if [ "$#" -gt 0 ]; then
  exec "$@"
fi
