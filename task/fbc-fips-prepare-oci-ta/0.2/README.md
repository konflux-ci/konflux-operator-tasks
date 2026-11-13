# fbc-fips-prepare-oci-ta task (0.2, binaryless multi-version)

This is the prepare task for `fbc-fips-check-matrix-based-oci-ta` (0.2). Together they provide the same FIPS compliance checking functionality as the standalone `fbc-fips-check-oci-ta` (0.2 binaryless), but with parallel processing support.

This is the **binaryless** variant: the target OCP versions are read from the `com.redhat.fbc.openshift.version` label of the FBC fragment (a **list** of versions), rather than being derived from a base image. Each targeted OCP version is processed independently - unreleased operator bundles are resolved against that version's index and the surviving relatedImages are grouped **per version**. The images are then split into buckets per version so the check task can fan out a **2-dimensional matrix** (OCP version × bucket index).

Binaryless FBC fragments are only permitted for OCP versions >= v4.15.

In order to resolve unreleased image pullspecs, this task expects an ImageDigestMirrorSet file located at `.tekton/images-mirror-set.yaml` of your FBC fragment git repo. It should map unreleased `registry.redhat.io` pullspecs of relatedImages to their valid quay.io pullspecs. If the ImageDigestMirrorSet is not provided, the task will attempt to process the `registry.redhat.io` pullspecs as is and might fail.

## Why per-version buckets?

A FIPS scan is version-dependent: `check-payload` applies a per-OCP-version exception list (via `-V=<version>`). The same image can therefore pass for one OCP version and fail for another, so the dedupe key is `(image, version)`, not `image`. Each bucket belongs to exactly one OCP version, and the check task scans it with that version's `-V`.

## Parameters
|name|description|default value|required|
|---|---|---|---|
|SOURCE_ARTIFACT|The Trusted Artifact URI pointing to the artifact with the application source code||true|
|image-digest|Image digest to scan||true|
|image-url|Image URL||true|
|image-mirror-set-path|Path to the image mirror set file.|.tekton/images-mirror-set.yaml|false|
|ociStorage|The OCI repository where the Trusted Artifacts are stored||true|
|NUM_BUCKETS|Number of buckets to create **per OCP version** (the matrix grid width)|1|false|
|SIZE_FETCH_PARALLEL|Number of parallel image size fetches for load balancing|5|false|

## Results
|name|description|
|---|---|
|BUCKETS_ARTIFACT|OCI reference to buckets artifact|
|BUCKET_INDICES|Array of bucket indices for matrix expansion (grid width), e.g. `["0","1"]`|
|OCP_VERSIONS|Array of target OCP versions for matrix expansion, e.g. `["4.18","4.19"]`|
|TOTAL_IMAGES|Total number of `(image, version)` pairs to scan|

## Additional info

### Bucket file layout
Each bucket is a file named `bucket-<version>-<index>.txt` inside the buckets artifact (e.g. `bucket-4.18-0.txt`). Every `(version, index)` cell of the grid has a file; cells with no work are empty and are a no-op in the check task. Metadata files (`related-images-map.txt`, `images_processed.txt`, and `test_output.txt` for error propagation) are copied alongside the buckets. A per-bucket OCP version file is intentionally **not** written - each check branch derives its version from the `OCP_VERSION` matrix param.

### Load Balancing Strategy
Within each version, images are distributed across that version's buckets based on their actual sizes:
1. Fetch image sizes in parallel (controlled by `SIZE_FETCH_PARALLEL`)
2. Sort images by size (largest first)
3. Greedily assign each image to the lightest bucket (smallest total size)

### Grid width and padding
`NUM_BUCKETS` is the number of buckets per version (capped at that version's image count). The grid width is the widest version's bucket count, and every version is padded up to that width with empty bucket files so the cartesian matrix is uniform.

### Error propagation
If extraction fails (e.g. the FBC fragment cannot be rendered, or the label has no valid OCP versions), the error is written to `test_output.txt` and a minimal 1×1 grid (`OCP_VERSIONS=["none"]`, `BUCKET_INDICES=["0"]`) is emitted so a single check worker runs and reports the error in its `TEST_OUTPUT` result.

### Usage Example
Use together with `fbc-fips-check-matrix-based-oci-ta` (0.2). The check task fans out a 2-dimensional matrix over `OCP_VERSION` and `BUCKET_INDEX`:

```yaml
tasks:
  - name: fbc-fips-prepare
    taskRef:
      name: fbc-fips-prepare-oci-ta   # 0.2
    params:
      - name: SOURCE_ARTIFACT
        value: $(tasks.clone-repository.results.SOURCE_ARTIFACT)
      - name: image-digest
        value: $(tasks.build-image-index.results.IMAGE_DIGEST)
      - name: image-url
        value: $(tasks.build-image-index.results.IMAGE_URL)
      - name: ociStorage
        value: $(params.output-image)
      - name: NUM_BUCKETS
        value: "2"

  - name: fbc-fips-check
    runAfter:
      - fbc-fips-prepare
    matrix:
      params:
        - name: OCP_VERSION
          value: $(tasks.fbc-fips-prepare.results.OCP_VERSIONS[*])
        - name: BUCKET_INDEX
          value: $(tasks.fbc-fips-prepare.results.BUCKET_INDICES[*])
    taskRef:
      name: fbc-fips-check-matrix-based-oci-ta   # 0.2
    params:
      - name: BUCKETS_ARTIFACT
        value: $(tasks.fbc-fips-prepare.results.BUCKETS_ARTIFACT)
      - name: MAX_PARALLEL
        value: "2"
```

**How it works**: The prepare task returns `OCP_VERSIONS` (e.g. `["4.18","4.19"]`) and `BUCKET_INDICES` (e.g. `["0","1"]`). The matrix produces their cartesian product - up to `versions × width` parallel TaskRuns - each scanning one bucket with its own `-V=<version>`.
