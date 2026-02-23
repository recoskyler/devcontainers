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
    - devcontainer-claude.md (user-level CLAUDE.md, copied into all images)
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
      - check.yml (PR build check — blocks merge on failure)

## Dockerfile conventions

- Base image ends with `USER dev` and `ENV HOME=/home/dev` — child images that switch to `USER root` must also set `ENV HOME=/root`, and reset it back when switching to `USER dev`
- Use POSIX-compatible redirects in RUN (`>/dev/null 2>&1`, not `&>`) — Docker uses `/bin/sh` (dash)
- Base image is Debian Trixie — package names follow Trixie repos (e.g. `php8.4`, not `php8.3`)

## devcontainer-claude.md maintenance

- `base/devcontainer-claude.md` is the user-level CLAUDE.md installed at `~/.claude/CLAUDE.md` in all images
- Each variant Dockerfile appends its own tools section via `printf >> $HOME/.claude/CLAUDE.md`
- Keep this file in sync when adding/removing tools from the base Dockerfile

## CI/CD notes

- Both workflows use buildx with `driver: docker` so language images can resolve `FROM devcontainer-base:latest` from the local daemon
- `type=gha` cache is not compatible with the `docker` driver

## Testing and validation

- Use `gh` CLI, and the `act` extension to test and validate the CI/CD: `gh act push`
- Use `docker` CLI to test and validate the Dockerfiles

## NEVER

- Push to main PR review
- Push to main testing CI/CD
- Push to main testing Dockerfiles
- Push to main updating documentation if necessary
- Add co-author to commits
