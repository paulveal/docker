#!/bin/bash

# Log in to Docker Hub
echo "Please log in to Docker Hub:"
docker login

# Detect the architecture
ARCH=$(uname -m)

# Set the tag suffix based on the architecture
if [ "$ARCH" = "x86_64" ]; then
    TAG_SUFFIX="amd"
elif [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
    TAG_SUFFIX="arm"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

# Set the repository name
REPO="paulveal/devimages"

# Fetch and display images from the repository using the v2 API
RESPONSE=$(curl -s https://hub.docker.com/v2/repositories/${REPO}/tags/)
IMAGES=$(echo "$RESPONSE" | jq -r '.results[].name' | grep "${TAG_SUFFIX}")

# Check if there are any images available
if [ -z "$IMAGES" ]; then
    echo "No images found for architecture: $ARCH"
    exit 1
fi

# Display the list of images and prompt the user to select one
echo "Available images for architecture ${ARCH}:"
select IMAGE in $IMAGES; do
    if [ -n "$IMAGE" ]; then
        echo "You selected: $IMAGE"
        break
    else
        echo "Invalid selection. Please try again."
    fi
done

# Check if a directory path is provided as an argument
MOUNT_DIR=$1

# Determine volume option based on user input
if [ -n "$MOUNT_DIR" ]; then
    # Convert relative path to absolute path
    ABS_MOUNT_DIR=$(realpath "$MOUNT_DIR")
    # Create a temporary directory with a sanitized name
    TEMP_DIR=$(mktemp -d)
    ln -s "$ABS_MOUNT_DIR" "$TEMP_DIR/mount"
    VOLUME_OPTION="-v ${TEMP_DIR}/mount:/localmount"
else
    VOLUME_OPTION=""
fi

# Print volume if provided
if [ -n "$VOLUME_OPTION" ]; then
    echo "Volume option: $VOLUME_OPTION"
fi

# Run the selected Docker image, use --rm to remove the container after it exits
docker run --rm -it ${VOLUME_OPTION} ${REPO}:${IMAGE}

# Clean up the temporary directory
if [ -n "$TEMP_DIR" ]; then
    rm -rf "$TEMP_DIR"
fi