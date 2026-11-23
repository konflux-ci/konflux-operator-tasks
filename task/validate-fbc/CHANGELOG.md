# Changelog

## 0.4

### Added

- New `check-related-images-mediatype` step that validates OCI mediaType of
  related images using the `operator-foundry` CLI. This check ensures related
  images use the correct mediaType for the target OCP version, with support
  for ImageDigestMirrorSet-based registry mirroring.
- `image-mirror-set-path` param (default `.tekton/images-mirror-set.yaml`) to
  locate the ImageDigestMirrorSet file for the related-images mediaType check.
- Required `SOURCE_ARTIFACT` param: unpacks the FBC fragment git source via a
  new `use-trusted-artifact` step so `image-mirror-set-path` resolves under
  `/var/workdir/source/` (same contract and layout as `fbc-fips-check-oci-ta`).

### Changed

- The `extract-and-validate` step no longer writes the final `SUCCESS`
  `TEST_OUTPUT`. That responsibility moved to `check-related-images-mediatype`,
  which runs last and merges the extract step's check count with its own result
  (12 + 1 on success).
- The `extract-and-validate` step now persists `check-num` and `ocp-version` to
  `/shared/` so the mediaType step can consume them.

## 0.3

### Removed

- Removed deprecated 0.1 and 0.2 task versions, Tekton pipelines, and migration scripts.

### Changed

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
