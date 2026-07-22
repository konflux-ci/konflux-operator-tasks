# Changelog

## Unreleased

### Added

- Added optional `BUILD_ARGS` param, passed as `--build-arg` flags to
  `check-lifecycle-eligibility` to resolve `ARG` references in the base image tag.

### Changed

- Bumped the `operator-foundry` image digest (`sha256:f6c0c59ac0891511c9edee848d138c63fa854327c2735f025fb86aa6666a0348` → `sha256:d83358368862108fcd3db9bf0241456bdf68cb1c77c6a4ca1a99bf0085094162`),
  which provides the `--build-arg` support consumed by the new `BUILD_ARGS` param above.

## 0.1

### Added

- Initial version of `fbc-inject-lifecycle-oci-ta` task
- Checks whether a file-based catalog (FBC) component is eligible for lifecycle injection (targets OCP 5.0+)
- Determines target OLM packages from the Dockerfile
- Generates lifecycle JSON files using `plcc2fbc`
- Injects lifecycle data into the catalog source directories
