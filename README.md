# Konflux Operator Tasks Catalog

## Introduction

This repository contains a collection of [Tekton](https://tekton.dev/) resources and helpers designed to support building and running operator checks in the [Konflux CI](https://konflux-ci.dev/docs/) pipelines. The goal is to provide a trusted set of operator testing tasks that can be used to ensure the quality of the operator images that are built in the Konflux CI system.

The tasks within this repository were migrated from the [Konflux build definitions repository](https://github.com/konflux-ci/build-definitions), which now holds the base build pipeline definitions and templates that reference these tasks.

## Structure

This repository is organized into several key directories, each serving a specific purpose for Tekton-related resources:

- `tasks/`: Contains the Tekton Task definitions used in the operator build and test pipelines.
- `pipelines/`: Contains the Tekton Pipeline definitions that orchestrate the tasks.
- `tests/`: Contains test cases and validation scripts for the tasks and pipelines.
- `docs/`: Contains additional documentation and guides.

## Migration Script Immutability Constraint

**Important:** Once a migration script has been executed and its changes have been applied to the repository, the script itself must be treated as immutable. Do not modify, delete, or rename existing migration scripts. If a migration script contains an error or needs to be corrected, create a new migration script to address the issue rather than altering the original. This ensures a clear and auditable history of all changes made to the repository structure and content.

## Contributing

Contributions are welcome! Please follow the standard Konflux CI contribution guidelines and ensure that all new tasks and pipelines are properly tested before submitting a pull request.
