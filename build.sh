#!/bin/bash

DEBUG_OPTION=""
NOCACHE_OPTION=""
DOCKERFILE_NAME=""

# Parse command-line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            DEBUG_OPTION="--debug"
            shift
            ;;
        --nocache)
            NOCACHE_OPTION="--no-cache"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# List all Dockerfiles matching the pattern <name>_Dockerfile
DOCKERFILES=($(ls *_Dockerfile 2>/dev/null))
if [ ${#DOCKERFILES[@]} -eq 0 ]; then
    echo "No Dockerfiles found matching the pattern <name>_Dockerfile"
    exit 1
fi

# Present the list to the user for selection
echo "Select a Dockerfile to build:"
select DOCKERFILE in "${DOCKERFILES[@]/_Dockerfile/}"; do
    if [ -n "$DOCKERFILE" ]; then
        DOCKERFILE_NAME="${DOCKERFILE}_Dockerfile"
        break
    else
        echo "Invalid selection. Please try again."
    fi
done

# Detect the architecture
ARCH=$(uname -m)

# Set the tag suffix based on the architecture
if [ "$ARCH" == "x86_64" ]; then
    ARCH_TAG="amd"
elif [ "$ARCH" == "arm64" ] || [ "$ARCH" == "aarch64" ]; then
    ARCH_TAG="arm"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

# Set the repository name
REPO="paulveal/devimages"

# Build the Docker image with a temporary tag and log output to dockerbuild.log
TEMP_TAG="temp_image"
echo "Building Docker image..."
if [ "$DEBUG_OPTION" == "--debug" ]; then
    docker build --rm $NOCACHE_OPTION -f ${DOCKERFILE_NAME} -t ${TEMP_TAG} .
else
    docker build --rm $NOCACHE_OPTION -f ${DOCKERFILE_NAME} -t ${TEMP_TAG} . > dockerbuild.log 2>&1
fi

# Check if the build was successful
if [ $? -eq 0 ]; then
    echo "Build successful."

    # Extract labels from the built image
    OS_TYPE=$(docker inspect --format='{{index .Config.Labels "os_type"}}' ${TEMP_TAG})
    PURPOSE=$(docker inspect --format='{{index .Config.Labels "purpose"}}' ${TEMP_TAG})

    # Tag the image with the appropriate tag and repository name
    FINAL_TAG="${REPO}:${ARCH_TAG}_${OS_TYPE}_${PURPOSE}"
    docker tag ${TEMP_TAG} ${FINAL_TAG}
    echo "Tag: $FINAL_TAG"

    # Check if the image already exists
    EXISTING_IMAGE=$(docker images -q ${FINAL_TAG})
    if [ -n "$EXISTING_IMAGE" ]; then
        # Compare the digests of the existing and new images
        EXISTING_DIGEST=$(docker inspect --format='{{if .RepoDigests}}{{index .RepoDigests 0}}{{end}}' ${FINAL_TAG})
        NEW_DIGEST=$(docker inspect --format='{{if .RepoDigests}}{{index .RepoDigests 0}}{{end}}' ${TEMP_TAG})
        if [ -n "$EXISTING_DIGEST" ] && [ -n "$NEW_DIGEST" ] && [ "$EXISTING_DIGEST" == "$NEW_DIGEST" ]; then
            echo "Image already exists and has not changed. No push required."
        else
            echo "Build successful, pushing to Docker Hub..."
            docker push ${FINAL_TAG}
        fi
    else
        echo "Build successful, pushing to Docker Hub..."
        docker push ${FINAL_TAG}
    fi
    # Remove the temporary tag and suppress the "Untagged" message
    docker rmi ${TEMP_TAG} > /dev/null 2>&1

    # Remove the log file if the build was successful and not in debug mode
    if [ "$DEBUG_OPTION" != "--debug" ]; then
        rm -f dockerbuild.log
    fi
else
    if [ "$DEBUG_OPTION" != "--debug" ]; then
        echo -e "Build failed. See dockerbuild.log for details.\n\n"
        echo "----------------------------------------------"
        cat dockerbuild.log
    else
        echo -e "Build failed. Check the output above or dockerbuild.log for details.\n\n"
    fi
    exit 1
fi