#!/bin/bash

# Check if exactly one argument is given
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <app name>"
  exit 1
fi

NETWORK=qservice_default
IMAGE=rqure/logger:v1.0.2
APP_NAME=$1

# Run docker and get the container ID
CONTAINER_ID=$(docker run --network $NETWORK -d -e APP_NAME=$APP_NAME $IMAGE)
docker logs -f $CONTAINER_ID
docker stop $CONTAINER_ID
