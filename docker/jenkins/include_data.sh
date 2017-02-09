#!/bin/bash
set -exo pipefail

if [[ -z "$GIT_COMMIT" ]]; then
  GIT_COMMIT=$(git rev-parse HEAD)
fi

MODE="$1"
FROM_DOCKER_IMAGE_TAG="mozorg/bedrock_code:${GIT_COMMIT}"
DOCKER_CONTAINER_NAME="bedrock-${BRANCH_NAME}-${GIT_COMMIT}"

if [[ "$MODE" == "demo" ]]; then
    ENV_FILE=demo.env
    DOCKER_IMAGE_TAG="mozorg/bedrock_demo:${GIT_COMMIT}"
    DOCKER_DATA_COMMAND="bin/sync_all"
else
    ENV_FILE=prod.env
    DOCKER_IMAGE_TAG="mozorg/bedrock_l10n:${GIT_COMMIT}"
    DOCKER_DATA_COMMAND="python manage.py l10n_update"
fi

docker run --env-file "docker/$ENV_FILE" --name "$DOCKER_CONTAINER_NAME" "$FROM_DOCKER_IMAGE_TAG" "$DOCKER_DATA_COMMAND"
docker commit --change 'CMD ["./docker/run.sh"]' "$DOCKER_CONTAINER_NAME" "$DOCKER_IMAGE_TAG"
