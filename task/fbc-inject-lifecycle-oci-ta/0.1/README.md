# fbc-inject-lifecycle-oci-ta task

The fbc-inject-lifecycle-oci-ta task injects lifecycle data into a file-based catalog (FBC) component targeting OCP 5.0+. It determines the target OLM packages from the Dockerfile, generates lifecycle JSON files using `plcc2fbc`, and injects them into the catalog source directories.

Lifecycle injection is skipped (with a successful result) if not all targeted OCP versions are >= 5.0. The task produces an updated `SOURCE_ARTIFACT` containing the injected lifecycle data, which can be consumed by downstream tasks such as `prefetch-dependencies`. `SOURCE_ARTIFACT` is always written, even on failure or when the component is not eligible — in those cases it points to the original, unmodified source artifact.

## Parameters
|name|description|default value|required|
|---|---|---|---|
|CONTEXT|Path to the directory to use as context.|.|false|
|DOCKERFILE|Path to the Dockerfile to build.|./Dockerfile|false|
|SOURCE_ARTIFACT|The Trusted Artifact URI pointing to the artifact with the application source code.||true|
|ociStorage|The OCI repository where the Trusted Artifacts are stored.||true|
|ociArtifactExpiresAfter|Expiration date for the trusted artifacts created in the OCI repository. An empty string means the artifacts do not expire.|""|false|

## Results
|name|description|
|---|---|
|SOURCE_ARTIFACT|The Trusted Artifact URI pointing to the artifact with the application source code, updated to include injected lifecycle data.|
|TEST_OUTPUT|Tekton task test output.|

## Additional info

### Lifecycle Injection Workflow
The task runs four steps in sequence:

1. **check-lifecycle-eligibility** — determines whether the component is eligible for lifecycle injection (i.e. whether it targets OCP 5.0+) and writes the result to /shared/eligible.
2. **get-packages** — if eligible, parses the `COPY`/`ADD` instructions in the Dockerfile and inspects the catalog subdirectories to determine which OLM packages require lifecycle injection.
3. **generate-lifecycle** — runs `plcc2fbc` to fetch lifecycle data from PLCC and generate per-package `lifecycle.json` files.
4. **inject-lifecycle** — injects the generated `lifecycle.json` files into the catalog source directories and writes the `TEST_OUTPUT` result.

### OCP Version Requirement
Lifecycle injection only runs if **all** targeted OCP versions in the Dockerfile are >= 5.0. If any version is below 5.0, the component is not eligible, and the task exits successfully with no packages injected.

### Partial Lifecycle Generation
If `plcc2fbc` is unable to generate lifecycle data for one or more of the requested packages, the task fails rather than injecting a partial set of lifecycle files. The task only proceeds with injection once lifecycle data has been successfully generated for every requested package.

### TEST_OUTPUT
The task writes a `TEST_OUTPUT` result following the Konflux convention, allowing Conforma to evaluate the result without halting the pipeline. A `FAILURE` result is written if:

- the eligibility check fails to produce output,
- package discovery (`get-packages`) errors out,
- the component is eligible but no packages requiring lifecycle injection are found,
- `plcc2fbc` fails or cannot generate lifecycle data for all requested packages, or
- lifecycle injection itself fails.

A `SUCCESS` result is written if the component is not eligible for lifecycle injection.
