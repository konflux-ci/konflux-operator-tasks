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
kind=$(yq -e '.kind' "$pipeline_file")
if [[ "$kind" == "PipelineRun" ]]; then
  tasks_selector=".spec.pipelineSpec.tasks[]"
elif [[ "$kind" == "Pipeline" ]]; then
  tasks_selector=".spec.tasks[]"
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

bundle_ref="quay.io/konflux-ci/tekton-catalog/task-fbc-inject-lifecycle-oci-ta:0.1@sha256:9b6d61e5e887a8f30940c1fed0e118b8974c382d0a6328db99705a44365f6b0b"
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
# This runs BEFORE pmt add-task so that fbc-inject-lifecycle's own param is inserted
# after the sed pass and remains untouched.
sed -i "s/\$(tasks\.${clone_task_name}\.results\.SOURCE_ARTIFACT)/\$(tasks.fbc-inject-lifecycle.results.SOURCE_ARTIFACT)/g" \
  "$pipeline_file"

# Step 2: Inject fbc-inject-lifecycle after the clone task.
# Because this runs after Step 1, its own SOURCE_ARTIFACT param referencing the clone task
# is inserted fresh and will not be overwritten by sed.
# shellcheck disable=SC2016  # Tekton $(params.*) expressions must not be expanded by Bash
pmt add-task "$bundle_ref" \
  "$pipeline_file" \
  --run-after "$clone_task_name" \
  --pipeline-task-name "fbc-inject-lifecycle" \
  --param 'DOCKERFILE=$(params.dockerfile)' \
  --param 'CONTEXT=$(params.path-context)' \
  --param "SOURCE_ARTIFACT=\$(tasks.${clone_task_name}.results.SOURCE_ARTIFACT)" \
  --param 'ociStorage=$(params.output-image).lifecycle' \
  --param 'ociArtifactExpiresAfter=$(params.image-expires-after)'

# Step 2a: Fix taskRef bundle name — pmt doesn't strip the 'task-' prefix when
# deriving the pipeline task name from the OCI repo name.
yq -i "
  (${tasks_selector} |
   select(.name == \"fbc-inject-lifecycle\") |
   .taskRef.params[] |
   select(.name == \"name\")).value = \"fbc-inject-lifecycle-oci-ta\"
" "$pipeline_file"

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
