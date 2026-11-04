# fbc-target-index-pruning-check task

Ensures file-based catalog (FBC) components do not remove versions of operators already added to a released catalog. Pruning is allowed only in channels that contain dev-preview, pre-ga, or candidate in their names.

## Parameters
|name|description|default value|required|
|---|---|---|---|
|IMAGE_URL|Fully qualified image name.||true|
|IMAGE_DIGEST|Image digest.||true|
|TARGET_INDEX|Image name of target index, minus tag.|registry.redhat.io/redhat/redhat-operator-index|false|
|RENDERED_CATALOG_DIGEST|Digest for attached json file containing the FBC fragment's opm rendered catalog.||true|

## Results
|name|description|
|---|---|
|TEST_OUTPUT|Tekton task test output.|
|IMAGES_PROCESSED|Images processed in the task.|


## Additional info

### What this check does:
- Resolves OCP version(s) from the FBC fragment via `get_ocp_version_from_fbc_fragment` (a single string for traditional fragments, or a JSON array when `com.redhat.fbc.openshift.version` is set for binaryless fragments).
- Runs `opm render` on the FBC fragment and on each `TARGET_INDEX:OCP_VERSION` image.
- Compares the channel data of the FBC fragment against each version's released target index (index channels are filtered to packages present in the fragment for efficiency).
- Checks if the FBC fragment will remove channels or channel entries previously added to any version's target index.
- Allows pruning only in channels that contain dev-preview, pre-ga, or candidate in their names.
- Aggregates pruning violations across all OCP versions into a single `TEST_OUTPUT` result.

## Source repository for image:
https://github.com/konflux-ci/konflux-test

## Additional links:
https://olm.operatorframework.io/docs/reference/file-based-catalogs/
https://github.com/containers/skopeo
https://docs.openshift.com/container-platform/4.12/cli_reference/opm/cli-opm-install.html
