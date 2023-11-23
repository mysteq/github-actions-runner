# GitHub Self-Hosted Runner Container Image

Based on the work from [myoung34/docker-github-actions-runner](https://github.com/myoung34/docker-github-actions-runner) and [actions/runner](https://github.com/actions/runner).

This repository contains the Dockerfile and scripts to build and run a GitHub self-hosted runner as a container image. A self-hosted runner is a server that has the Github Actions runner application installed. You can use a self-hosted runner to run GitHub Actions workflows on your own hardware.

## Features

- Based on Ubuntu 22.04 LTS and the image from [actions/runner](https://github.com/actions/runner)
- Registers and unregisters the runner automatically
- Handles graceful shutdown and removal of the runner on SIGTERM signal
- Supports custom labels and runner groups

## Usage

To use this image, you need to have a GitHub app. You also need to specify the repository URL and the runner name as environment variables.
The following command will run the image as a daemon and register a runner named `my-runner` to the repository `https://github.com/my-org/my-repo`:



