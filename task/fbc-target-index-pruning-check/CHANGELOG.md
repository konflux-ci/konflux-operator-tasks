# Changelog

## Unreleased

## 0.1

### Added

- Initial version of `fbc-target-index-pruning-check`.
- Single OCP version pruning check against `TARGET_INDEX:<ocp_version>` from the FBC fragment label.
- Pruning allowed only in channels that contain `dev-preview`, `pre-ga`, or `candidate` in their names.
- Multi-OCP support for binaryless FBC fragments that declare multiple versions via the `com.redhat.fbc.openshift.version` label (string or JSON array).
- Per-version pruning checks against each `TARGET_INDEX:<ocp_version>`, with aggregated `TEST_OUTPUT`.
- Empty-version / missing-label guard with a clear failure message.
- Package filtering of released index channels to packages present in the FBC fragment (efficiency).
- Continue across OCP versions on render/empty-index errors; remove large rendered files after use to reduce memory pressure.
- Normalize OCP versions with a `v` prefix before building target index pullspecs.

### Fixed

- Initialize `digests_processed` before use under `set -u`.
- Use exact (`grep -Fxq`) channel/entry membership checks to avoid false substring matches.
- Deduplicate OCP versions before the multi-version pruning loop.

### Note

- Task parameters and results are unchanged. Traditional single-version fragments continue to work alongside multi-OCP / binaryless fragments.
