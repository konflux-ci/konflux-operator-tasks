# Changelog

## Unreleased

### Added

- Added optional `CATALOG_PATH` param (default `""`). When set, Dockerfile
  parsing is skipped for the `inject-lifecycle` step and `lifecycle.json` is
  injected directly into `<CATALOG_PATH>/<package>/` for each package. Intended
  for FBC images whose COPY instructions targeting `/configs` all use
  `--from=<stage>`, making the catalog source directory inaccessible on local
  disk. `DOCKERFILE` is still used by the `check-lifecycle-eligibility` and
  `get-packages` steps; `CATALOG_PATH` and `DOCKERFILE` are mutually exclusive
  only at the inject step.

- Added a built-in `SKIP_PACKAGES` list passed via `--skip-packages` to
  `operator-foundry` in the `get-packages` step. When all discovered packages
  are on the skip list, the resulting `packages.txt` is empty and the
  `inject-lifecycle` step treats it as a no-op success (0 successes, 0
  failures). More broadly, the `inject-lifecycle` step now treats _any_ empty
  `packages.txt` as a success rather than a failure. This is safe because the
  step runs under `set -euo pipefail`: the only way `packages.txt` can be empty
  is when every discovered package was filtered by the skip list.  The case
  where no packages are discoverable at all never reaches `inject-lifecycle` —
  `operator-foundry get-packages` errors out and `set -e` terminates the
  `get-packages` step, which is reported as a `FAILURE` via `TEST_OUTPUT`. The
  skip list is an internal operational control managed via task releases (not
  user-configurable), tied to the PLMCORE-16364 data remediation effort.

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

- Bumped the `operator-foundry` image digest to
  `sha256:3d7c066a0bd46421b2e3dced9d9c7d5ce3891ea5bf88ccbfe19770c3413f9146`
  (adds `--catalog-path`, build-arg, and `--skip-packages` support).

- Bumped the `generate-lifecycle` step image (`quay.io/konflux-ci/fbc-update-planner`)
  to `0.1.0@sha256:756516302435356d73911a79e2de2ef20a8adf4296009c5aa2b521563e1610dd`.

- Passed `--validators none` to `plcc2fbc` in the `generate-lifecycle` step, so
  lifecycle generation no longer runs PLCC validators.

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
