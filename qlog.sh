#!/bin/bash

# Check if exactly one argument is given
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <app name>"
  exit 1
fi

IMAGE=rqure/logger:$IMAGE_VERSION

APP_NAME=$1

docker run --attach -e APP_NAME $IMAGE
