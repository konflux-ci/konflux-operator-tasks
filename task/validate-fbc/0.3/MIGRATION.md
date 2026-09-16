# Migration from 0.2 to 0.3

## What Changed

This version adds a new `check-related-images-mediatype` validation step
that verifies related images use Docker V2 manifest media types for OCP < 4.20.
It also triggers the automated rollout of the `fbc-inject-lifecycle-oci-ta` task
into FBC builder pipelines via MintMaker.

## What the Migration Script Does

MintMaker will open a PR that automatically:

1. Adds the `fbc-inject-lifecycle` task after the clone task.
2. Rewires `SOURCE_ARTIFACT` so downstream tasks consume the output of
   `fbc-inject-lifecycle` instead of the clone task directly.
3. Updates `runAfter` dependencies for affected downstream tasks.

The task is safe for all FBC pipelines — it skips injection at runtime for
components not targeting OCP 5.0+.

## Action from Users

No action required. Review and merge the MintMaker PR once CI passes.

If the migration script fails, manually add `fbc-inject-lifecycle` following the
standard FBC pipeline blueprint in `build-definitions`.

**Note:** The `fbc-inject-lifecycle-oci-ta` task accepts an optional
`BUILD_ARGS` parameter (defaults to empty). If your pipeline already declares a
`build-args` parameter, the migration wires it into `fbc-inject-lifecycle`
automatically. No action needed.
