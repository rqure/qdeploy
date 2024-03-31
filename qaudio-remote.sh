#!/bin/bash

# Function to handle the SIGINT signal (Ctrl+C)
cleanup() {
    echo "Caught SIGINT signal. Stopping the container..."
    docker stop "$CONTAINER_ID"
    exit 0
}

# Check if exactly one argument is given
if [ "$#" -ne 1 ]; then
  echo "Usage: $0 <app name>"
  exit 1
fi

# Trap the SIGINT signal
trap cleanup SIGINT

NETWORK=qservice_default
IMAGE=rqure/audio-remote:v1.0.1
AUDIO_FILE=$1

# Run docker and get the container ID
CONTAINER_ID=$(docker run --network $NETWORK -d --rm -e AUDIO_FILE=$AUDIO_FILE $IMAGE)
