# Konflux Operator Tasks Catalog

## Introduction

This repository contains a collection of [Tekton](https://tekton.dev/) resources and helpers designed to support building and running operator checks in the [Konflux CI](https://konflux-ci.dev/docs/) pipelines. The goal is to provide a trusted set of operator testing tasks that can be used to ensure the quality of the operator images that are built in the Konflux CI system.

The tasks within this repository were migrated from the [Konflux build definitions repository](https://github.com/konflux-ci/build-definitions), which now holds the base build pipeline definitions and templates that reference these tasks.

## Structure

This repository is organized into several key directories, each serving a specific purpose for Tekton-related resources:

- `tasks/` - Contains the Tekton Task definitions for various operator checks and build steps
- `pipelines/` - Contains Tekton Pipeline definitions that orchestrate the tasks
- `helpers/` - Contains helper scripts and utilities used by the tasks
- `docs/` - Contains documentation and guides for using the tasks

## Conventions

### Compute Resources

When defining task steps, follow these conventions for `computeResources`:

1. **Do not use empty maps**: Never specify `computeResources: {}` in task steps. If no specific resource limits are needed, omit the `computeResources` field entirely.

2. **Specify explicit values**: When resource limits are required, specify explicit values for both `requests` and `limits`:

   ```yaml
   computeResources:
     requests:
       cpu: "100m"
       memory: "128Mi"
     limits:
       cpu: "500m"
       memory: "512Mi"
   ```

3. **Use appropriate units**: Use Kubernetes resource units (e.g., `m` for millicores, `Mi` for mebibytes, `Gi` for gibibytes).

4. **Match step requirements**: Set resource values that are appropriate for the specific step's workload. For example:
   - Lightweight steps (e.g., script execution, file operations): `cpu: "100m"`, `memory: "128Mi"`
   - Build steps (e.g., compilation, image building): `cpu: "500m"`, `memory: "1Gi"`
   - Test steps (e.g., running operator tests): `cpu: "500m"`, `memory: "1Gi"`

5. **Consistency**: Maintain consistent resource allocations across similar task steps to ensure predictable behavior and resource usage.

## Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository and create a feature branch
2. Make your changes with appropriate tests
3. Ensure all tasks pass validation
4.
