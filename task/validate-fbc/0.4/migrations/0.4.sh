#!/usr/bin/env bash
set -euo pipefail

declare -r pipeline_file=${1:?missing pipeline file}

# Only apply to FBC pipelines — identified by presence of validate-fbc task.
if ! grep -q "validate-fbc" "$pipeline_file"; then
  exit 0
fi

# Determine the tasks path based on the resource kind.
kind=$(yq -e '.kind' "$pipeline_file")
if [[ "$kind" == "PipelineRun" ]]; then
  tasks_selector=".spec.pipelineSpec.tasks[]"
elif [[ "$kind" == "Pipeline" ]]; then
  tasks_selector=".spec.tasks[]"
else
  echo "Unknown kind '$kind' in $pipeline_file, skipping"
  exit 0
fi

# Find the validate-fbc pipeline task by its taskRef name.
validate_fbc_task_name=""
task_selector="${tasks_selector} | select(.taskRef.params[]? | (.name == \"name\" and .value == \"validate-fbc\"))"
if yq -e "$task_selector" "$pipeline_file" >/dev/null 2>&1; then
  validate_fbc_task_name="$(yq -e "${task_selector} | .name" "${pipeline_file}" | head -1)"
fi

if [[ -z "$validate_fbc_task_name" ]]; then
  echo "No validate-fbc task found in $pipeline_file, skipping"
  exit 0
fi

# Idempotent: skip if SOURCE_ARTIFACT is already wired to validate-fbc.
if yq -e \
  "${tasks_selector} | select(.name == \"${validate_fbc_task_name}\") | .params[] | select(.name == \"SOURCE_ARTIFACT\")" \
  "$pipeline_file" >/dev/null 2>&1; then
  echo "SOURCE_ARTIFACT already wired to ${validate_fbc_task_name}, nothing to do"
  exit 0
fi

# Find the best source for SOURCE_ARTIFACT.
# Priority matches fbc-fips-check-oci-ta's wiring in fbc-builder:
#   1. prefetch-dependencies (standard for FBC pipelines)
#   2. fbc-inject-lifecycle  (added by validate-fbc 0.3 migration)
#   3. clone task            (fallback)
source_task_name=""

if yq -e "${tasks_selector} | select(.name == \"prefetch-dependencies\")" \
  "$pipeline_file" >/dev/null 2>&1; then
  source_task_name="prefetch-dependencies"
fi

if [[ -z "$source_task_name" ]]; then
  if yq -e "${tasks_selector} | select(.name == \"fbc-inject-lifecycle\")" \
    "$pipeline_file" >/dev/null 2>&1; then
    source_task_name="fbc-inject-lifecycle"
  fi
fi

if [[ -z "$source_task_name" ]]; then
  for task_refname in "git-clone-oci-ta" "git-clone-oci-ta-min"; do
    task_selector="${tasks_selector} | select(.taskRef.params[]? | (.name == \"name\" and .value == \"${task_refname}\"))"
    if yq -e "$task_selector" "$pipeline_file" >/dev/null 2>&1; then
      source_task_name="$(yq -e "${task_selector} | .name" "${pipeline_file}" | head -1)"
      break
    fi
  done
fi

if [[ -z "$source_task_name" ]]; then
  echo "No SOURCE_ARTIFACT source found in $pipeline_file, skipping"
  exit 0
fi

# Wire SOURCE_ARTIFACT to validate-fbc from the discovered source task.
# shellcheck disable=SC2016  # Tekton $(tasks.*) must not be expanded by Bash
pmt modify -f "$pipeline_file" task "$validate_fbc_task_name" \
  add-param "SOURCE_ARTIFACT" "\$(tasks.${source_task_name}.results.SOURCE_ARTIFACT)"
echo "Wired SOURCE_ARTIFACT to ${validate_fbc_task_name} from ${source_task_name} in $pipeline_file"
