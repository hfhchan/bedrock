#!/bin/bash
#
# Runs unit_tests
#
set -exo pipefail

if [[ -z "$GIT_COMMIT" ]]; then
  GIT_COMMIT=$(git rev-parse HEAD)
fi

DOCKER_REPO="${DOCKER_REPO:-mozorg}"
CODE_IMAGE_TAG="${DOCKER_REPO}/bedrock_code:${GIT_COMMIT}"
TEST_IMAGE_TAG="${DOCKER_REPO}/bedrock_test:${GIT_COMMIT}"

cat << EOF > Dockerfile-test
FROM $CODE_IMAGE_TAG
CMD ['docker/run-tests.sh']
RUN pip install --no-cache-dir -r requirements/test.txt
EOF

docker build -t "$TEST_IMAGE_TAG" -f Dockerfile-test .
docker run --env-file docker/test.env "$TEST_IMAGE_TAG"
