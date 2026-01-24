#!/bin/bash
set -e

IMAGE_NAME="${IMAGE_NAME:-spinogrizz/unifi-proxy}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

cd "$(dirname "$0")/.."

echo "Building ${IMAGE_NAME}:${IMAGE_TAG}"
docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" .

echo "Done: ${IMAGE_NAME}:${IMAGE_TAG}"
