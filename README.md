# Developer Docker Images

This repository contains Dockerfiles and scripts to create repeatable developer images for various Linux distributions. The images are designed to provide a consistent development environment with essential tools and configurations.

## Description of Files

### Dockerfiles

- **[Ubuntu_General_Dockerfile](Ubuntu_General_Dockerfile)**: Builds a general-purpose Ubuntu-based Docker image with essential development tools.
- **[Ubuntu_Python_Dockerfile](Ubuntu_Python_Dockerfile)**: Builds an Ubuntu-based Docker image tailored for Python development, including popular Python libraries.
- **[AmazonLinux_General_Dockerfile](AmazonLinux_General_Dockerfile)**: Builds a general-purpose Amazon Linux-based Docker image with essential development tools.
- **[AmazonLinux2_General_Dockerfile](AmazonLinux2_General_Dockerfile)**: Builds a general-purpose Amazon Linux 2-based Docker image with essential development tools.

### Scripts

- **[build.sh](build.sh)**: Script to build Docker images. It lists available Dockerfiles and allows the user to select one for building.
- **[run.sh](run.sh)**: Script to run a Docker container from the built images. It handles Docker login, image selection, and volume mounting.
- **[unminimise.sh](unminimise.sh)**: Script used in Dockerfiles to unminimize the base image, restoring essential packages and documentation.

### Configuration

- **[docker.zshrc](docker.zshrc)**: Configuration file for `oh-my-zsh` used in the Docker images to set up the Zsh shell with the `agnoster` theme.

## Usage

1. **Build an Image**: Use the `build.sh` script to build a Docker image.

   ```sh
   ./build.sh
   ```

2. **Run a Container**: Use the `run.sh` script to run a Docker container from the built image.

   ```sh
   ./run.sh [optional_mount_directory]
   ```

## License

This project is licensed under the MIT License.
