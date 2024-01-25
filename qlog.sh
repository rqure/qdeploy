#!/bin/bash

# Check if exactly one argument is given
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <app name>"
  exit 1
fi

IMAGE=rqure/logger:v1.0.1

APP_NAME=$1

docker run --attach -e APP_NAME $IMAGE
