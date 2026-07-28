# Changelog

## Unreleased

### Added

- Added optional `BUILD_ARGS` param, passed as `--build-arg` flags to the
  `check-lifecycle-eligibility`, `get-packages`, and `inject-lifecycle` steps,
  to resolve `ARG` references used in the base image tag or in COPY/ADD source
  paths (requires `operator-foundry` with build-arg support in `check-lifecycle-eligibility`, `get-packages`
  and `inject-lifecycle`).

  Example: if your Dockerfile uses `ARG CATALOG_VERSION` in the `FROM` line,
  or `ARG INPUT_DIR` in a `COPY` source path, pass their values via:

```yaml
  - name: BUILD_ARGS
    value:
      - CATALOG_VERSION=v5.0
      - INPUT_DIR=catalog/v5.0
```

### Changed

- Bumped the `operator-foundry` image digest to pick up build-arg support in
  `check-lifecycle-eligibility`, `get-packages`, and `inject-lifecycle`.

### Fixed

- Changed the `inject-lifecycle` step from `script:` to `command`/`args`.
  This step declares both a task-level result and a step-level result
  (`skip_create_trusted_artifact`); on Tekton Pipelines versions that predate
  the fix for [tektoncd/pipeline#8255](https://github.com/tektoncd/pipeline/issues/8255)
  (fixed by [#10007](https://github.com/tektoncd/pipeline/pull/10007)), that
  combination trips a validation webhook bug when read from a step's
  `script:` field, causing the Task to be rejected admission with a
  "non-existent variable" error. Tekton's step-results validator only
  inspects `script`, not `command`/`args`, so moving the script there avoids
  the bug without changing behavior.

## 0.1

### Added

- Initial version of `fbc-inject-lifecycle-oci-ta` task
- Checks whether a file-based catalog (FBC) component is eligible for lifecycle injection (targets OCP 5.0+)
- Determines target OLM packages from the Dockerfile
- Generates lifecycle JSON files using `plcc2fbc`
- Injects lifecycle data into the catalog source directories
