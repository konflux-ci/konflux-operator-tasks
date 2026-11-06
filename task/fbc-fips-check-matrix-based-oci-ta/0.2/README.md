# fbc-fips-check-matrix-based-oci-ta task (0.2, binaryless multi-version)

This is the matrix version of `fbc-fips-check-oci-ta` 0.2 (binaryless). Both tasks have the same
FIPS compliance checking functionality, but this version supports parallel processing via a
**2-dimensional** Tekton matrix expansion over `OCP_VERSION` and `BUCKET_INDEX`.

## Why per-(version, bucket) matrix cells?

Binaryless FBC fragments target a **list** of OCP versions (read from the
`com.redhat.fbc.openshift.version` label by `fbc-fips-prepare-oci-ta` 0.2). A FIPS scan is
version-dependent: `check-payload` applies a per-OCP-version exception list via `-V=<version>`, so
the same image digest can pass under one version and fail under another. The scan unit is
therefore `(image, version)`, never deduplicated across versions.

This task processes exactly one `(OCP_VERSION, BUCKET_INDEX)` cell per invocation. The pipeline
expands the full grid with a matrix, so `versions × bucket-width` instances run in parallel across
the cluster:

- **Faster execution**: scanning fans out horizontally across many pods instead of looping inside one
- **Correct per-version scanning**: each branch scans its images with that version's own `-V`
- **Load balancing**: within a version, images are distributed across that version's buckets by size
- **Resource efficiency**: each parallel task uses fewer resources than scanning everything in one pod

**Choose the right task:**
- `fbc-fips-check-oci-ta` 0.2 - Standalone mode, single task, in-pod loop over every targeted version
- `fbc-fips-check-matrix-based-oci-ta` 0.2 - Matrix mode, parallel processing, recommended for large
  binaryless fragments with many related images and/or many targeted versions

This task is designed to work with `fbc-fips-prepare-oci-ta` 0.2 using matrix expansion on the
`OCP_VERSION` and `BUCKET_INDEX` parameters.
The prepare task reads the fragment's target OCP versions, extracts unreleased relatedImages per
version, deduplicates them within each version, and distributes them across per-version buckets for
parallel processing.

## Usage

This task requires pairing with `fbc-fips-prepare-oci-ta` 0.2:

1. **fbc-fips-prepare-oci-ta**: Extracts unique related images per OCP version and creates bucket artifacts
2. **fbc-fips-check-matrix-based-oci-ta**: Processes one (OCP version, bucket) cell (run with matrix expansion)

Example pipeline snippet:
```yaml
- name: fbc-fips-prepare
  taskRef:
    name: fbc-fips-prepare-oci-ta   # 0.2
  params:
    - name: NUM_BUCKETS
      value: "2"
    # ... other params

- name: fbc-fips-check
  taskRef:
    name: fbc-fips-check-matrix-based-oci-ta   # 0.2
  matrix:
    params:
      - name: OCP_VERSION
        value: $(tasks.fbc-fips-prepare.results.OCP_VERSIONS[*])
      - name: BUCKET_INDEX
        value: $(tasks.fbc-fips-prepare.results.BUCKET_INDICES[*])
  params:
    - name: BUCKETS_ARTIFACT
      value: $(tasks.fbc-fips-prepare.results.BUCKETS_ARTIFACT)
```

## Parameters
|name|description|default value|required|
|---|---|---|---|
|BUCKETS_ARTIFACT|OCI reference to buckets artifact from fbc-fips-prepare-oci-ta||true|
|OCP_VERSION|Which target OCP version's bucket to process (e.g. "4.18", or "none" for the minimal fallback grid)||true|
|BUCKET_INDEX|Which bucket to process within the OCP version (0, 1, 2, ...)||true|
|MAX_PARALLEL|Maximum number of images to process in parallel within this bucket|2|false|

## Results
|name|description|
|---|---|
|IMAGES_PROCESSED|Images processed in the task|
|TEST_OUTPUT|Tekton task test output|

## Additional info
### Bucket selection and OCP version
Each instance reads `bucket-${OCP_VERSION}-${BUCKET_INDEX}.txt` from the buckets artifact. Unlike
the 0.1 matrix family, `fbc-fips-prepare-oci-ta` 0.2 does not ship a shared `target_ocp_version.txt`
(since a single check-payload `-V` no longer applies to every branch). Instead, this task's
`prepare-bucket-images` step writes `target_ocp_version.txt` itself from the `OCP_VERSION` param, so
`fips-operator-check-step-action` scans with the correct `-V=${OCP_VERSION}`.

### Parallel Processing
The MAX_PARALLEL parameter controls how many related images are scanned concurrently within each
bucket. The default value is "2", which is lower than the standalone task since many matrix cells
(versions × bucket width) run in parallel.

### Error Propagation
If the prepare task encounters an error (e.g. cannot render FBC fragment, or no valid OCP version
found on the label), the error is propagated through the bucket artifact's `test_output.txt` and
reported in the TEST_OUTPUT result of the single minimal-grid check branch
(`OCP_VERSION=none`, `BUCKET_INDEX=0`).

### Empty grid cells
`fbc-fips-prepare-oci-ta` 0.2 pads every OCP version to a uniform bucket count (the grid width).
Padded cells have an empty bucket file; this task no-ops to success for them (no images to check).
