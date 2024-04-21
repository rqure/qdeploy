#!/bin/bash

# Function to handle the SIGINT signal (Ctrl+C)
cleanup() {
    echo "Caught SIGINT signal. Stopping the container..."
    docker stop "$CONTAINER_ID"
    exit 0
}

while getopts ":f:t:" OPTION; do
    case "${OPTION}" in
        f)
            FILE_PATH=${OPTARG}
            ;;
        t)
            TEXT=${OPTARG}
            ;;
        *)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

# Trap the SIGINT signal
trap cleanup SIGINT

NETWORK=qservice_default
IMAGE=rqure/audio-remote:v1.1.3

# Run docker and get the container ID
CONTAINER_ID=$(docker run --network $NETWORK -d --rm -e AUDIO_FILE="$FILE_PATH" -e TEXT_TO_SPEECH="$TEXT" $IMAGE)
