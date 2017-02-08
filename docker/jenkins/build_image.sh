#!/bin/bash

set -euxo pipefail

if [[ -z "$GIT_COMMIT" ]]; then
  GIT_COMMIT=$(git rev-parse HEAD)
fi

DOCKER_REPO="${DOCKER_REPO:-mozorg}"
BASE_IMAGE_TAG="${DOCKER_REPO}/bedrock_base:${GIT_COMMIT}"

# build base image
docker build -t "$BASE_IMAGE_TAG" --pull -f docker/dockerfiles/bedrock_base .

# build a build image
cat << EOF > Dockerfile-build
FROM $DOCKER_IMAGE_TAG

ENV PATH=/node_modules/.bin:\$PATH
ENV PIPELINE_LESS_BINARY=lessc
ENV PIPELINE_SASS_BINARY=node-sass
ENV PIPELINE_YUGLIFY_BINARY=yuglify

RUN apt-get install -y --no-install-recommends nodejs-legacy npm

COPY ./node_modules /
COPY ./package.json /
COPY ./lockdown.json /
# --unsafe-perm required for lockdown to function
RUN cd / && npm install --production --unsafe-perm
EOF

BUILD_IMAGE_TAG="${DOCKER_REPO}/bedrock_build:${GIT_COMMIT}"

# build the builder image
docker build -t "$BUILD_IMAGE_TAG" -f Dockerfile-build .

# build the static files using the builder image
docker run --user $(id -u) -v "$PWD:/app" --env-file docker/prod.env "$BUILD_IMAGE_TAG" \
    docker/jenkins/build_staticfiles.sh

echo "${GIT_COMMIT}" > static/revision.txt

# build the code image
cat << EOF > Dockerfile-code
FROM $DOCKER_IMAGE_TAG

COPY bedrock ./
COPY lib ./
COPY root_files ./
COPY scripts ./
COPY static ./
COPY vendor-local ./
COPY wsgi ./
COPY LICENSE ./
COPY contribute.json ./
COPY manage.py ./
EOF

CODE_IMAGE_TAG="${DOCKER_REPO}/bedrock_code:${GIT_COMMIT}"
docker build -t "$CODE_IMAGE_TAG" -f Dockerfile-code .
