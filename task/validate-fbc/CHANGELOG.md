# Changelog

## Unreleased

### Changed

- Refreshed the `operator-foundry:0.1` image digest to the current tag digest.

### Removed

- Removed deprecated 0.1 and 0.2 task versions, Tekton pipelines, and migration scripts.

## 0.3

### Added

- New `check-related-images-mediatype` step that validates related images use
  Docker V2 manifest media types for OCP versions below 4.21, delegating to
  `operator-foundry fbc check-related-images-mediatype`.

### Changed

- `extract-and-validate` no longer writes a final `SUCCESS` `TEST_OUTPUT` on the
  happy path. That step still writes `FAILURE`/`ERROR` when its own checks fail.
  On success, final `TEST_OUTPUT` is written by `check-related-images-mediatype`.
- Migration script now uses `yq` instead of `sed` for all pipeline YAML edits,
  for cross-platform compatibility (macOS + Linux) and safer, structure-aware
  modifications (e.g. distinguishing actual task objects from string matches
  on `bundle_ref` or param values).
- Added `BUILD_ARGS` param wiring to `fbc-inject-lifecycle`, sourced from
  `$(params.build-args[*])` and normalized to a list value.

### Fixed

- Migration script for `fbc-inject-lifecycle-oci-ta` now resolves the task bundle
  digest dynamically at migration time instead of using a hardcoded pin, preventing
  digest-mismatch errors for teams that had not yet merged the MintMaker PR for `0.2`.

## 0.2

### Changed

- Version bump to trigger automated rollout of the new `fbc-inject-lifecycle-oci-ta`
  task to all FBC builder pipelines via MintMaker. No functional changes to this task.
