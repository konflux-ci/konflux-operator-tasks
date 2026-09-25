#!/usr/bin/env bash
set -euo pipefail

declare -r pipeline_file=${1:?missing pipeline file}

# Only apply to FBC pipelines - identified by presence of validate-fbc task,
# which is required in all FBC builder pipelines.
if ! grep -q "validate-fbc" "$pipeline_file"; then
  exit 0
fi

# Determine the tasks path based on the resource kind.
# - Pipeline: tasks live at .spec.tasks
# - PipelineRun: tasks live at .spec.pipelineSpec.tasks (embedded spec)
#
# has_build_args is also determined here since the check differs by kind:
# - Pipeline: only .spec.params declares params, so that's the sole check.
# - PipelineRun: build-args may be declared on the embedded pipelineSpec
#   (.spec.pipelineSpec.params) and/or supplied as a runtime value
#   (.spec.params), so both are checked.
has_build_args="false"
kind=$(yq -e '.kind' "$pipeline_file")
if [[ "$kind" == "PipelineRun" ]]; then
  tasks_selector=".spec.pipelineSpec.tasks[]"
  # Check both pipeline-level param declarations and runtime param values
  if yq -e '.spec.pipelineSpec.params[]? | select(.name == "build-args")' "$pipeline_file" >/dev/null 2>&1 ||
     yq -e '.spec.params[]? | select(.name == "build-args")' "$pipeline_file" >/dev/null 2>&1; then
    has_build_args="true"
  fi
elif [[ "$kind" == "Pipeline" ]]; then
  tasks_selector=".spec.tasks[]"
  if yq -e '.spec.params[]? | select(.name == "build-args")' "$pipeline_file" >/dev/null 2>&1; then
    has_build_args="true"
  fi
else
  echo "Unknown kind '$kind' in $pipeline_file, skipping"
  exit 0
fi

# Skip if already added (idempotent).
# Uses yq to check for an actual task object rather than grep, which would
# false-positive on SOURCE_ARTIFACT references or bundle_ref strings.
if yq -e "${tasks_selector} | select(.name == \"fbc-inject-lifecycle\")" "$pipeline_file" >/dev/null 2>&1; then
  exit 0
fi

# Dynamic bundle ref discovery via skopeo, with retry on transient failures
task_image="quay.io/konflux-ci/tekton-catalog/task-fbc-inject-lifecycle-oci-ta:0.1"

digest=""
max_attempts=3
last_err=""
for ((attempt = 1; attempt <= max_attempts; attempt++)); do
  err_file=$(mktemp)
  if digest=$(skopeo inspect --no-tags "docker://${task_image}" 2>"$err_file" | jq -r '.Digest'); then
    if [[ -n "$digest" && "$digest" != "null" ]]; then
      rm -f "$err_file"
      break
    fi
  fi
  last_err=$(cat "$err_file")
  rm -f "$err_file"
  if [[ "$attempt" -lt "$max_attempts" ]]; then
    sleep "$((2 ** (attempt - 1)))"
  fi
  digest=""
done

if [[ -z "$digest" ]]; then
  echo "ERROR: Failed to resolve digest for ${task_image} after ${max_attempts} attempts" >&2
  if [[ -n "$last_err" ]]; then
    echo "Last skopeo error:" >&2
    echo "$last_err" >&2
  fi
  exit 1
fi

# Validate digest format before handing it to pmt add-task.
if [[ ! "$digest" =~ ^sha256:[0-9a-f]{64}$ ]]; then
  echo "ERROR: Resolved digest '${digest}' does not match expected sha256:<hex64> format" >&2
  exit 1
fi

bundle_ref="${task_image}@${digest}"

clone_task_name=""

for task_refname in "git-clone-oci-ta" "git-clone-oci-ta-min"; do
    task_selector="${tasks_selector} | select(.taskRef.params[]? | (.name == \"name\" and .value == \"${task_refname}\"))"
    if yq -e "$task_selector" "$pipeline_file" >/dev/null 2>&1; then
        clone_task_name="$(yq -e "${task_selector} | .name" "${pipeline_file}" | head -1)"
        break
    fi
done

if [[ -z "$clone_task_name" ]]; then
    echo "No git-clone-oci-ta task found in $pipeline_file, skipping"
    exit 0
fi

# Step 1: Rewire SOURCE_ARTIFACT param references from the clone task to fbc-inject-lifecycle.
# Uses yq for cross-platform compatibility (macOS + Linux).
# This runs BEFORE pmt add-task so that fbc-inject-lifecycle's own param is inserted
# after this pass and remains untouched.
yq -i "
  (${tasks_selector} |
   .params[]? |
   select(.value == \"\$(tasks.${clone_task_name}.results.SOURCE_ARTIFACT)\")
  ).value = \"\$(tasks.fbc-inject-lifecycle.results.SOURCE_ARTIFACT)\"
" "$pipeline_file"

# Step 2: Inject fbc-inject-lifecycle after the clone task.
# Because this runs after Step 1, its own SOURCE_ARTIFACT param referencing the clone task
# is inserted fresh and will not be overwritten by the yq pass.
# BUILD_ARGS is only included when the pipeline declares a build-args param (see check above).
# shellcheck disable=SC2016  # Tekton $(params.*) expressions must not be expanded by Bash
pmt_params=(
  --param 'DOCKERFILE=$(params.dockerfile)'
  --param 'CONTEXT=$(params.path-context)'
  --param "SOURCE_ARTIFACT=\$(tasks.${clone_task_name}.results.SOURCE_ARTIFACT)"
  --param 'ociStorage=$(params.output-image).lifecycle'
  --param 'ociArtifactExpiresAfter=$(params.image-expires-after)'
)
if [[ "$has_build_args" == "true" ]]; then
  pmt_params+=(--param 'BUILD_ARGS=$(params.build-args[*])')
fi

pmt add-task "$bundle_ref" \
  "$pipeline_file" \
  --run-after "$clone_task_name" \
  --pipeline-task-name "fbc-inject-lifecycle" \
  "${pmt_params[@]}"

# Step 2a: Fix taskRef bundle name — pmt doesn't strip the 'task-' prefix when
# deriving the pipeline task name from the OCI repo name.
yq -i "
  (${tasks_selector} |
   select(.name == \"fbc-inject-lifecycle\") |
   .taskRef.params[] |
   select(.name == \"name\")).value = \"fbc-inject-lifecycle-oci-ta\"
" "$pipeline_file"

# Step 2b: Ensure BUILD_ARGS is a list value (only relevant if it was injected above).
if [[ "$has_build_args" == "true" ]]; then
  yq -i "
    (${tasks_selector} |
     select(.name == \"fbc-inject-lifecycle\") |
     .params[] |
     select(.name == \"BUILD_ARGS\")
    ).value = [\"\$(params.build-args[*])\"]
  " "$pipeline_file"
fi

# Step 3: Update runAfter ONLY for tasks that consume SOURCE_ARTIFACT from fbc-inject-lifecycle
# (i.e. tasks that were rewired in Step 1). This intentionally excludes tasks like build-images
# whose runAfter: [clone-repository] is redundant — they are implicitly ordered via their
# prefetch-dependencies param references and do not need updating.
yq -i "
  (${tasks_selector} |
   select(.name != \"fbc-inject-lifecycle\") |
   select(.params[]?.value == \"\$(tasks.fbc-inject-lifecycle.results.SOURCE_ARTIFACT)\") |
   .runAfter[]? |
   select(. == \"${clone_task_name}\")) = \"fbc-inject-lifecycle\"
" "$pipeline_file"

echo "Successfully injected fbc-inject-lifecycle after $clone_task_name in $pipeline_file"
