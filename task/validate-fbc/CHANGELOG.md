# Changelog

## 0.3

### Fixed

- Migration script for `fbc-inject-lifecycle-oci-ta` now resolves the task bundle
  digest dynamically at migration time instead of using a hardcoded pin, preventing
  digest-mismatch errors for teams that had not yet merged the MintMaker PR for `0.2`.

### Changed

- Migration script now uses `yq` instead of `sed` for all pipeline YAML edits,
  for cross-platform compatibility (macOS + Linux) and safer, structure-aware
  modifications (e.g. distinguishing actual task objects from string matches
  on `bundle_ref` or param values).
- Added `BUILD_ARGS` param wiring to `fbc-inject-lifecycle`, sourced from
  `$(params.build-args[*])` and normalized to a list value.

## 0.2

### Changed

- Version bump to trigger automated rollout of the new `fbc-inject-lifecycle-oci-ta`
  task to all FBC builder pipelines via MintMaker. No functional changes to this task.
