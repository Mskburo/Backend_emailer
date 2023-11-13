#!/bin/bash

# Check if a file path is provided as a command-line argument
if [ $# -ne 1 ]; then
    echo "Usage: $0 <file_path>"
    exit 1
fi

IMAGE_NAME=emailer
OUTPUT_TARBALL="$IMAGE_NAME.tar"

# Use the provided file path
# FILE_PATH="$1"

# Load environment variables from .env file
if [[ -f .env ]]; then
    source .env
else
    echo "Error: .env file not found. Please create one with the required variables."
    exit 1
fi

# Build the Docker image
docker compose -f ./build.docker-compose.yaml --env-file .env build

# Check if the build was successful
if [ $? -eq 0 ]; then
    echo "Docker image build successful."

    # Save the Docker image to a tarball file
    docker save -o $OUTPUT_TARBALL $IMAGE_NAME:latest

    if [ $? -eq 0 ]; then
        echo "Docker image saved to $OUTPUT_TARBALL"

        # Transfer the tarball to the remote host and load it using ssh
        cat $OUTPUT_TARBALL | ssh -C $REMOTE_HOST "docker load && cd /root/Mskburo && make lazy"

        if [ $? -eq 0 ]; then
            echo "Docker image loaded on the remote host."

            # Now, run the restart.sh script on the remote host
            # ssh -C $REMOTE_HOST 'cd /root/Mskburo && make up'

        else
            echo "Error loading Docker image on the remote host."
            exit 1
        fi

    else
        echo "Error saving Docker image to $OUTPUT_TARBALL"
        exit 1
    fi
else
    echo "Error building Docker image."
    exit 1
fi
