# fbc-inject-lifecycle task

The fbc-inject-lifecycle task injects lifecycle data into a file-based catalog (FBC) component targeting OCP 5.0+. It determines the target OLM packages from the Dockerfile, generates lifecycle JSON files using `plcc2fbc`, and injects them into the catalog source directories.

Lifecycle injection is skipped (with a successful result) if not all targeted OCP versions are >= 5.0.

## Parameters
|name|description|default value|required|
|---|---|---|---|
|CONTEXT|Path to the directory to use as context.|.|false|
|DOCKERFILE|Path to the Dockerfile to build.|./Dockerfile|false|
|BUILD_ARGS|Array of --build-arg values ("arg=value" strings) used to resolve ARG references in the Dockerfile (e.g. in the base image tag or in COPY/ADD source paths).|[]|false|
|caTrustConfigMapName|The name of the ConfigMap containing the CA bundle for TLS verification.|trusted-ca|false|
|caTrustConfigMapKey|The key in the ConfigMap containing the CA bundle.|ca-bundle.crt|false|

## Results
|name|description|
|---|---|
|TEST_OUTPUT|Tekton task test output.|

## Workspaces
|name|description|optional|
|---|---|---|
|workspace||false|

## Additional info

### Lifecycle Injection Workflow
The task runs four steps in sequence:

1. **check-lifecycle-eligibility** — determines whether the component is eligible for lifecycle injection (i.e. whether it targets OCP 5.0+) and writes the result to /shared/eligible.
2. **get-packages** — if eligible, parses the `COPY`/`ADD` instructions in the Dockerfile and inspects the catalog subdirectories to determine which OLM packages require lifecycle injection.
3. **generate-lifecycle** — runs `plcc2fbc` to fetch lifecycle data from PLCC and generate per-package `lifecycle.json` files.
4. **inject-lifecycle** — injects the generated `lifecycle.json` files into the catalog source directories and writes the `TEST_OUTPUT` result.

The task operates directly on the `workspace` PVC — the source tree under `<workspace>/source` is mutated in place, and any downstream task in the same pipeline that mounts the same workspace binding sees the injected lifecycle data without further steps. The pipeline author is responsible for ordering (e.g. `runAfter`) any task that needs to see the mutated tree, since Tekton does not infer task order from shared workspace usage the way it does from result references.

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

### Note

This is the workspace-source variant; the Trusted Artifacts equivalent is `fbc-inject-lifecycle-oci-ta`.
