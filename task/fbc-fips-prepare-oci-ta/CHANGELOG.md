# Changelog

## 0.2

### Added

- Binaryless, multi-version variant of `fbc-fips-prepare-oci-ta`.
- Reads the **list** of target OCP versions from the `com.redhat.fbc.openshift.version` label and extracts unreleased relatedImages **per version** (dedupe key is `(image, version)`), sharing the fragment render and per-bundle render across all versions.
- Splits images into per-version buckets named `bucket-<version>-<index>.txt` and pads every version to a uniform grid width.
- New `OCP_VERSIONS` array result (alongside `BUCKET_INDICES`) so the check task can fan out a 2-dimensional matrix (`OCP_VERSION` × `BUCKET_INDEX`).
- `NUM_BUCKETS` now means buckets **per OCP version** (the matrix grid width).
- `TOTAL_IMAGES` now counts `(image, version)` pairs.

### Fixed

- Fail with a clear error instead of crashing on a `jq` parse error when `get_ocp_version_from_fbc_fragment` falls back to a plain version string (returned when the `com.redhat.fbc.openshift.version` label is missing) instead of the expected JSON array.

### Note

Designed to work with `fbc-fips-check-matrix-based-oci-ta` 0.2. The per-version split is required because `check-payload` applies a per-OCP-version exception set via `-V=<version>`.

## Unreleased

### Fixed

- Bumped the `konflux-test` image to `v1.5.9`.
- Bumped the `konflux-test` image to `v1.5.7`.
- Replace the ad-hoc 4-line minor-version arithmetic with a call to the shared `get_prev_ocp_version()` helper now available in `utils.sh` (`konflux-test:v1.5.0`). The helper correctly handles the v5.0 → v4.22 cross-major boundary.

## 0.1

### Added

- Initial version of `fbc-fips-prepare-oci-ta` task
- Extracts unique relatedImages from unreleased FBC operator bundles
- Size-based load balancing across configurable number of buckets
- Parallel image size fetching with mirror support
- Creates OCI artifact with bucket files for matrix expansion
- Error propagation via `test_output.txt` in bucket artifact

### Note

This task is designed to work with `fbc-fips-check-matrix-based-oci-ta` for parallel FIPS checking.
