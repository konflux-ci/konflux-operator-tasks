## Deprecation notice

This task version is deprecated. Please migrate to [validate-fbc 0.3](../0.3/README.md).
Pipelines still referencing this version will receive a Conforma warning until 2026-09-28
and a violation after that date.

# validate-fbc task

Ensures file-based catalog (FBC) components are uniquely linted for proper construction as part of build pipeline. The manifest data of container images is checked using OpenShift Operator Framework's opm CLI tool. The opm binary is extracted from the container's base image, which must come from a trusted source.

## Parameters
|name|description|default value|required|
|---|---|---|---|
|IMAGE_URL|Fully qualified image name.||true|
|IMAGE_DIGEST|Image digest.||true|

## Results
|name|description|
|---|---|
|RELATED_IMAGE_ARTIFACT|The Trusted Artifact URI pointing to the artifact with the related images for the FBC fragment.|
|TEST_OUTPUT_ARTIFACT|The Trusted Artifact URI pointing to the artifact with the related images for the FBC fragment.|
|TEST_OUTPUT|Tekton task test output.|
|RELATED_IMAGES_DIGEST|Digest for attached json file containing related images|
|IMAGES_PROCESSED|Images processed in the task.|
|RENDERED_CATALOG_DIGEST|Digest for attached json file containing the FBC fragment's opm rendered catalog.|


## Additional info
