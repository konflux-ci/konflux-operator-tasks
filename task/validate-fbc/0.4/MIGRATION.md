# Migration from 0.3 to 0.4

## What Changed

`validate-fbc` now reads the ImageDigestMirrorSet file from the git source
to resolve registry mirrors during the `check-related-images-mediatype` check.
This requires two new parameters:

- `SOURCE_ARTIFACT` (**required**, no default) — trusted artifact URI for the git source
- `image-mirror-set-path` (default: `.tekton/images-mirror-set.yaml`) — path within
  the repo to the IDMS file

Because `SOURCE_ARTIFACT` is required, **this is a breaking change** for any
pipeline that uses `validate-fbc` without it.

## What the Migration Script Does

MintMaker will open a PR that wires `SOURCE_ARTIFACT` to `validate-fbc` using
the first available upstream source, in priority order:

1. `prefetch-dependencies`
2. `fbc-inject-lifecycle`
3. `git-clone-oci-ta` / `git-clone-oci-ta-min`

If none of these tasks are present, the script skips the file and logs a warning.

## Action from Users

- **Most pipelines**: review and merge the MintMaker PR once CI passes.
- **If the MintMaker PR is missing or CI fails**: manually add `SOURCE_ARTIFACT`
  to `validate-fbc` params, pointing to whichever upstream task produces it.
- **If your IDMS file is not at `.tekton/images-mirror-set.yaml`**: add 
  image-mirror-set-path to validate-fbc params in your pipeline and set it to the 
  correct path.
