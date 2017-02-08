#!/bin/bash

set -exo pipefail

if [[ -z "$GIT_COMMIT" ]]; then
  GIT_COMMIT=$(git rev-parse HEAD)
fi

DOCKER_REPO="${DOCKER_REPO:-mozorg}"
BASE_IMAGE_TAG="${DOCKER_REPO}/bedrock_base:${GIT_COMMIT}"
BUILD_IMAGE_TAG="${DOCKER_REPO}/bedrock_build:${GIT_COMMIT}"
CODE_IMAGE_TAG="${DOCKER_REPO}/bedrock_code:${GIT_COMMIT}"

function imageExists() {
  docker history -q "$1" > /dev/null 2>&1
  return $?
}

function generateDockerfile() {
  echo "FROM $BASE_IMAGE_TAG" | cat - "docker/dockerfiles/bedrock_$1" > Dockerfile-$1
}

rm -f Dockerfile-*

generateDockerfile code
exit 0

# build base image
if ! imageExists "$BASE_IMAGE_TAG"; then
  docker build -t "$BASE_IMAGE_TAG" --pull -f docker/dockerfiles/bedrock_base .
fi

# build a builder image
if ! imageExists "$BUILD_IMAGE_TAG"; then
  generateDockerfile build
  echo "FROM $BASE_IMAGE_TAG" | cat - docker/dockerfiles/bedrock_build > Dockerfile-build
  docker build -t "$BUILD_IMAGE_TAG" -f Dockerfile-build .
fi

# build the static files using the builder image
# and include those and the app in a code image
if ! imageExists "$CODE_IMAGE_TAG"; then
  docker run --user $(id -u) -v "$PWD:/app" --env-file docker/prod.env "$BUILD_IMAGE_TAG" \
      docker/jenkins/build_staticfiles.sh

  echo "${GIT_COMMIT}" > static/revision.txt

  # build the code image
  generateDockerfile code
  docker build -t "$CODE_IMAGE_TAG" -f Dockerfile-code .
fi
