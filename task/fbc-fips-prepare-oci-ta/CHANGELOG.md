# Changelog

## Unreleased

### Changed

- Set step `computeResources` from analyzer MAX+5% (2026-11-05; short retention): `use-trusted-artifact` 3Gi/50m (no observability → match TA default); `get-unique-related-images` 12Gi+`limits.cpu` → 6Gi/1000m (no `limits.cpu`); `split-into-buckets` 192Mi/350m; `create-buckets-artifact` 64Mi/50m (KONFLUX-14672).

### Fixed

- Bumped the `konflux-test` image to `v1.5.11` using the `latest` digest.
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
