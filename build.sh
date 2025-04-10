#!/usr/bin/env bash

GITHUB_OWNER=ddev
PUSH=""
LOAD=""
IMAGE_NAME="ghcr.io/akibaat/ddev-gitlab-ci"
DDEV_VERSION=""
SUFFIX=${SUFFIX:-""}
MERGE=0

help() {
    echo "Available options:"
    echo "  * v - DDEV version e.g. 'v1.23.1'"
    echo "  * l - Load the image (--load)"
    echo "  * p - Push the image (--push)"
    echo "  * m - Merge the manifests"
}

loadVersionAndTags() {
  # @todo: Currently limited to 99 releases, may use pagination
  ddev_releases=($(curl --silent -L -H "Accept: application/vnd.github+json" https://api.github.com/repos/${GITHUB_OWNER}/ddev/releases?per_page=99 | jq -r '.[].tag_name'))

  IFS='.' read -r -a version <<< "$OPTION_VERSION"
  bugfix_release="${version[2]}"

  if [[ "${version[2]}" == "" ]]; then
    bugfix_release="[0-9]+"
    # Add minor tag version. In cas only major.minor is given, it will be tagged as well
    additional_tag="${version[0]}.${version[1]}"
  fi

  pattern="^${version[0]}\.${version[1]}\.${bugfix_release}$"
  filtered_array=()

  for element in "${ddev_releases[@]}"; do
    if [[ $element =~ $pattern ]]; then
      filtered_array+=("$element")
    fi
  done

  DDEV_VERSION="${filtered_array[0]}"

  # Define image tags
  if [[ $additional_tag == "" ]]; then
    DOCKER_TAGS=("$IMAGE_NAME:${DDEV_VERSION}$SUFFIX")
  else
    DOCKER_TAGS=("$IMAGE_NAME:$additional_tag$SUFFIX" "$IMAGE_NAME:$DDEV_VERSION$SUFFIX")
  fi
}

while getopts ":v:hplm" opt; do
  case $opt in
  h)
    help
    exit 1
    ;;
  v)
    OPTION_VERSION="${OPTARG}"
    ;;
  p)
    PUSH="--push"
    ;;
  l)
    LOAD="--load"
    ;;
  m)
    MERGE=1
    ;;
  *)
    help
    echo "Invalid option: -$OPTARG"
    exit 1
    ;;
  esac
done

# Set version and tag for latest (aka nightly)
if [ "$OPTION_VERSION" = "latest" ]; then
  DDEV_VERSION="latest"
  DOCKER_TAGS=("$IMAGE_NAME:latest$SUFFIX")
elif [ "$OPTION_VERSION" = "stable" ]; then
  DDEV_VERSION="$(curl --silent -L -H "Accept: application/vnd.github+json" https://api.github.com/repos/ddev/ddev/releases/latest | jq -r '.tag_name')"

  if [[ ! "$DDEV_VERSION" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Latest DDEV release '$DDEV_VERSION' is not a valid semver version."
    exit 2
  fi

  # Get version like v1.24
  additional_tag="${DDEV_VERSION%.*}"

  DOCKER_TAGS=("$IMAGE_NAME:stable$SUFFIX" "$IMAGE_NAME:$additional_tag$SUFFIX" "$IMAGE_NAME:$DDEV_VERSION$SUFFIX")
else
  loadVersionAndTags
fi

echo $DDEV_VERSION
echo $DOCKER_TAGS

if [ "$MERGE" = "1" ]; then
  for DOCKER_TAG in "${DOCKER_TAGS[@]}"; do
    echo "Merging ${DOCKER_TAG}"
    docker manifest create ${DOCKER_TAG} ${DOCKER_TAG}-amd64 ${DOCKER_TAG}-arm64
    docker manifest push ${DOCKER_TAG}
  done
else
  BUILD_TAGS=()
  for TAG in "${DOCKER_TAGS[@]}"; do
    BUILD_TAGS+=("-t" "$TAG")
  done
  docker buildx build --allow security.insecure --progress plain --no-cache --pull --provenance=false . -f Dockerfile ${BUILD_TAGS[@]} --build-arg ddev_version="$DDEV_VERSION" $PUSH $LOAD
fi
