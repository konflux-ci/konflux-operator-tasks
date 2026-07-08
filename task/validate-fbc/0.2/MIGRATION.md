# Migration from 0.1 to 0.2

## What Changed

No functional changes were made to `validate-fbc` itself. This version bump
is used to automatically inject the new `fbc-inject-lifecycle-oci-ta` task
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
