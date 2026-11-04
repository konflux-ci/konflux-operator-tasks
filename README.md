# Konflux Operator Tasks Catalog

## Introduction

This repository contains a collection of [Tekton](https://tekton.dev/) resources and helpers designed to support building and running operator checks in the [Konflux CI](https://konflux-ci.dev/docs/) pipelines. The goal is to provide a trusted set of operator testing tasks that can be used to ensure the quality of the operator images that are built in the Konflux CI system.

The tasks within this repository were migrated from the [Konflux build definitions repository](https://github.com/konflux-ci/build-definitions), which now holds the base build pipeline definitions and templates that reference these tasks.

## Structure

This repository is organized into several key directories, each serving a specific purpose for Tekton-related resources:

- **`tasks/`**: Contains the Tekton Task definitions for various operator checks and build steps.
- **`pipelines/`**: Contains Tekton Pipeline definitions that orchestrate the tasks.
- **`templates/`**: Contains Tekton PipelineTemplate and TaskTemplate definitions.
- **`hack/`**: Contains helper scripts for development and maintenance.
- **`test/`**: Contains test files and fixtures.

## Development

### Generating TA Tasks

The `hack/generate-ta-tasks.sh` script is used to generate Tekton Task definitions for Trusted Artifact (TA) related steps.

> **Note:** The `hack/generate-ta-tasks.sh` script **cannot be run in the agent sandbox** due to its dependencies on external tools and network access that are not available in the sandboxed environment. If you need to regenerate TA tasks, please run this script in a full development environment with appropriate permissions and network access.

### Building and Testing

To build and test the tasks in this repository, you can use the following commands:

```bash
# Lint the repository
make lint

# Test the repository
make test
```

## Contributing

Please read the [CONTRIBUTING.md](CONTRIBUTING.md) file for details on our code of conduct and the process for submitting pull requests.

## License

This project is licensed under the [Apache License 2.0](LICENSE).
