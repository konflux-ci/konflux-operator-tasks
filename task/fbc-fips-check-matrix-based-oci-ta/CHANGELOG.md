# Changelog

## Unreleased

## 0.2

### Added

- Binaryless, multi-version variant of `fbc-fips-check-matrix-based-oci-ta`.
- New `OCP_VERSION` param so each matrix branch scans one `(OCP version, bucket)` cell: reads `bucket-<version>-<index>.txt` and writes `target_ocp_version.txt` itself (the prepare task no longer ships a shared one) so `fips-operator-check-step-action` scans with that version's `-V`.
- Designed to be paired with a 2-dimensional Tekton matrix (`OCP_VERSION[*] x BUCKET_INDEX[*]`) over `fbc-fips-prepare-oci-ta` 0.2's `OCP_VERSIONS` and `BUCKET_INDICES` results.

### Note

Designed to work with `fbc-fips-prepare-oci-ta` 0.2. The per-version split is required because `check-payload` applies a per-OCP-version exception set via `-V=<version>`.

### Fixed

- Bumped the `konflux-test` image to `v1.5.9`.
- Updated the `fips-operator-check-step-action` revision parameter to use `check-payload` release `0.4.1`.
- Bumped the `konflux-test` image to `v1.5.7`.
- Updated the `fips-operator-check-step-action` revision parameter to `006b00e`.
- Updated the `fips-operator-check-step-action` revision parameter to use `check-payload` release `0.3.17`.
- Updated the `fips-operator-check-step-action` revision parameter to use `check-payload` release `0.3.15`.
- Updated the `fips-operator-check-step-action` revision parameter to use `check-payload` release `0.3.14`.

## 0.1

### Added

- Initial version of `fbc-fips-check-matrix-based-oci-ta` task
- Matrix-based parallel FIPS checking with Tekton matrix expansion
- Parameters: `BUCKETS_ARTIFACT`, `BUCKET_INDEX`, `MAX_PARALLEL`
- Error propagation from `fbc-fips-prepare-oci-ta` via bucket artifacts

### Note

This is the matrix version of `fbc-fips-check-oci-ta`. Both tasks have the same FIPS compliance checking functionality:
- `fbc-fips-check-oci-ta` - Standalone mode, single task
- `fbc-fips-check-matrix-based-oci-ta` - Matrix mode, parallel processing with `fbc-fips-prepare-oci-ta`
