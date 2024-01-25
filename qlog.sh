#!/bin/bash

# Function to handle the SIGINT signal (Ctrl+C)
cleanup() {
    echo "Caught SIGINT signal. Stopping the Docker container..."
    docker stop "$CONTAINER_ID"
    exit 0
}

# Check if exactly one argument is given
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <app name>"
  exit 1
fi

NETWORK=qservice_default
IMAGE=rqure/logger:v1.0.2
APP_NAME=$1

# Trap the SIGINT signal
trap cleanup SIGINT

# Run docker and get the container ID
CONTAINER_ID=$(docker run --network $NETWORK --attach STDOUT --attach STDERR -e APP_NAME=$APP_NAME $IMAGE)

# Wait for the container to stop
docker wait "$CONTAINER_ID"
