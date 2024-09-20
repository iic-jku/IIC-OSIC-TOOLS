# Devcontainer image and template

In the subfolders you can find support for the
[devcontainers](https://containers.dev/) infrastructure:

- The Docker image variant prepared for devcontainers
- The template for Visual Studio code to add it easily

## Docker Image

The docker image takes the IIC-OSIC-TOOLS Docker image as base and performs a
very minor operation: Properly creating the user directly. Later we might need
to add more devcontainer-specific support once we run into issues, or might
deprecate the image in case that the base image works directly.

## Template

This is the template to be released as a GitHub Package.