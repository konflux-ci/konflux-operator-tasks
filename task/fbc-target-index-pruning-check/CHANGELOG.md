# Changelog

## Unreleased

### Added

- Multi-OCP support for binaryless FBC fragments that declare multiple versions via the `com.redhat.fbc.openshift.version` label (must be a JSON array, e.g. `["v4.18","v4.19"]`).
- Per-version pruning checks against each `TARGET_INDEX:<ocp_version>`, with aggregated `TEST_OUTPUT`.
- Empty-version guard with a clear failure message.
- Package filtering of released index channels to packages present in the FBC fragment (efficiency).
- Continue across OCP versions on render/empty-index issues; remove large rendered files after use to reduce memory pressure.
- Normalize OCP versions with a `v` prefix before building target index pullspecs.

### Changed

- Target-index render failures and empty-index issues still produce `ERROR` (infra/precondition), while pruning violations remain `FAILURE`. The task continues across remaining OCP versions and aggregates both in `TEST_OUTPUT` (`ERROR` takes precedence if any render/index errors occurred).
- Multi-OCP / binaryless support ships in task version `0.1` by team decision (no new Konflux component). Behavior is additive: traditional single-version fragments keep the same params and results.

### Fixed

- Initialize `digests_processed` before use under `set -u`.
- Exact channel/entry membership via string compare (avoids `grep -q` SIGPIPE under `pipefail` on large lists).
- Normalize `v` prefix before deduplicating OCP versions so `4.18` and `v4.18` are not checked twice.
- Guard `render_opm` failures so `set -e` does not abort the multi-OCP loop.

### Note

Task parameters and results are unchanged. Traditional single-version fragments continue to work alongside multi-OCP / binaryless fragments. Render/empty-index problems remain `ERROR`; pruning policy hits remain `FAILURE`.

## 0.1

### Added

- Initial version of `fbc-target-index-pruning-check`.
- Single OCP version pruning check against `TARGET_INDEX:<ocp_version>` from the FBC fragment label.
- Pruning allowed only in channels that contain `dev-preview`, `pre-ga`, or `candidate` in their names.
