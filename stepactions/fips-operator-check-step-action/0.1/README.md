## fips-operator-check-step-action

This stepAction scans relatedImages of operator bundle image builds for FIPS compliance using the check-payload tool. Images are processed in parallel to improve performance.
* The relatedImages are expected to be in a file located at `/tekton/home/unique_related_images.txt`.
* If the check-payload scan is desired to be run with the built-in exception list, the target OCP version (`v4.x`) should be in a file located at `/tekton/home/target_ocp_version.txt`.
* It also supports replacing relatedImages pullspecs with their first mirror. In order to use that, a mapping like {"source_registry_and_repo": ["mirror_registry_and_repo"]} should be stored in a file located at `/tekton/home/related-images-map.txt`

## Parameters:

| name               | description                                                 | default |
|--------------------|-------------------------------------------------------------|---------|
| MAX_PARALLEL       | Maximum number of images to process in parallel             | 8       |

## Results:

| name               | description                          |
|--------------------|--------------------------------------|
| TEST_OUTPUT        | Tekton task test output.             |


## Outputs:

`/tekton/home/fips-report.json` — A structured FIPS scan report written at the end of the step. Contains a UTC timestamp, summary counters, and a per-image array with the result and findings for each scanned image.

```json
{
  "timestamp": "2025-01-31T12:00:00Z",
  "summary": {"total": 3, "successes": 1, "failures": 1, "warnings": 0, "errors": 1},
  "images": [
    {"image": "quay.io/...@sha256:abc", "result": "SUCCESS"},
    {"image": "quay.io/...@sha256:def", "result": "FAILURE", "findings": [
      {"rpm": "openssl-libs", "binary": "/usr/lib64/libcrypto.so.3", "message": "operating system is not FIPS certified"}
    ]},
    {"image": "quay.io/...@sha256:ghi", "result": "ERROR", "error": "Could not inspect image for labels"}
  ]
}
```

## Additional links:
https://github.com/openshift/check-payload