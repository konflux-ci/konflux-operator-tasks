# Changelog

## 0.2

### Added

- Multi-OCP support for binaryless FBC fragments that declare multiple versions via the `com.redhat.fbc.openshift.version` label (string or JSON array).
- Per-version pruning checks against each `TARGET_INDEX:<ocp_version>`, with aggregated `TEST_OUTPUT`.
- Empty-version / missing-label guard with a clear failure message.
- Package filtering of released index channels to packages present in the FBC fragment (efficiency).
- Fail-fast comments and `tee` for render/debug visibility; remove large rendered files after use to reduce memory pressure.

### Compatibility

- Task parameters and results are unchanged from 0.1. Traditional single-version fragments continue to work.
- Consumers that need multi-OCP / binaryless support should use task version `0.2`. Version `0.1` remains the legacy single-OCP behavior.

## 0.1

### Added

- Initial version of `fbc-target-index-pruning-check`.
- Single OCP version pruning check against `TARGET_INDEX:<ocp_version>` from the FBC fragment label.
- Pruning allowed only in channels that contain `dev-preview`, `pre-ga`, or `candidate` in their names.
