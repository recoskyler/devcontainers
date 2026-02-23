# CLAUDE.md

## About this project

This is a project containing pre-configured Dockerfiles for building and hosting DevContainer Docker images on GitHub.

- All Dev Container images should have the necessary tools for development
- Different configurations should be possible using build-time arguments
- Repository and the hosted Docker images are private

## Project structure

- ROOT
  - base
    - Dockerfile (shared base image — debian:trixie with all common tools)
  - [DOCKER_IMAGE_NAME]
    - Dockerfile (extends devcontainer-base with language-specific tools)
  - scripts
    - setup-claude.sh
    - ntfy-hook.sh
    - suggest-context7-hook.sh
    - init-claude-mcp.sh
  - .github
    - workflows
      - build.yml

## Testing and validation

- Use `gh` CLI, and the `act` extension to test and validate the CI/CD: `gh act push`
- Use `docker` CLI to test and validate the Dockerfiles
