# Changelog

<!-- Format guidelines: https://keepachangelog.com/en/1.1.0/#how -->

## Unreleased

<!--
When you make changes without bumping the version right away, document them here.
If that's not something you ever plan to do, consider removing this section.
-->

### Changed

- Analyzer MAX+5% (2026-11-05): add `use-trusted-artifact` / `create-trusted-artifact` 64Mi/50m; raise `run-opm-with-user-args` 512Mi/100m → 896Mi/200m; raise `convert-image-tags-to-digests` CPU 250m → 550m; raise `replace-related-images-pullspec-in-file` CPU 50m → 100m; no `limits.cpu` (KONFLUX-14675).

### Added

- Added computeResources to all task-specific steps.

## 0.1

### Added

- The initial version of the `run-opm-command-oci-ta` task!
