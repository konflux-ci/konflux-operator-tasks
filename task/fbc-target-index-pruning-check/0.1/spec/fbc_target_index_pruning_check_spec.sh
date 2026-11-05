#!/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

eval "$(shellspec - -c) exit 1"

task_path=fbc-target-index-pruning-check.yaml
if [[ -f "../${task_path}" ]]; then
    task_path="../${task_path}"
fi

cleanup=()
trap 'rm -rf "${cleanup[@]}"' EXIT

results_dir=$(mktemp -d) && cleanup+=("${results_dir}")
shared_dir=$(mktemp -d) && cleanup+=("${shared_dir}")
catalog_file="${shared_dir}/catalog.json"

export MOCK_OCP_VERSIONS="v4.16"
export RENDER_CALLS_FILE
RENDER_CALLS_FILE=$(mktemp) && cleanup+=("${RENDER_CALLS_FILE}")
export MOCK_FRAGMENT_CATALOG="${catalog_file}"
export MOCK_INDEX_CATALOG=""

mock_utils=$(mktemp --tmpdir mock_utils_XXXXXXXXXX.sh) && cleanup+=("${mock_utils}")
cat > "${mock_utils}" << 'MOCK_UTILS_EOF'
handle_error() { :; }
get_image_manifests() { echo '{"amd64": "sha256:abc123"}'; }
get_ocp_version_from_fbc_fragment() { printf '%s' "${MOCK_OCP_VERSIONS}"; }
make_result_json() {
  local result="UNKNOWN" failures="0"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -r) result="$2"; shift 2 ;;
      -f) failures="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  echo "{\"result\":\"${result}\",\"failures\":${failures}}"
}
render_opm() {
  local target=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -t) target="$2"; shift 2 ;;
      *) shift ;;
    esac
  done
  echo "${target}" >> "${RENDER_CALLS_FILE}"
  local tmpfile
  tmpfile=$(mktemp)
  if [[ -n "${MOCK_INDEX_CATALOG:-}" && -f "${MOCK_INDEX_CATALOG}" ]]; then
    cat "${MOCK_INDEX_CATALOG}" > "${tmpfile}"
  else
    cat "${MOCK_FRAGMENT_CATALOG}" > "${tmpfile}"
  fi
  echo "${tmpfile}"
}
MOCK_UTILS_EOF

extract_script() {
  local raw script
  raw="$(mktemp --tmpdir script_raw_XXXXXXXXXX.sh)"
  script="$(mktemp --tmpdir script_XXXXXXXXXX.sh)"
  cleanup+=("${raw}" "${script}")

  yq -r '.spec.steps[] | select(.name == "run-pruning-check").script' "${task_path}" > "${raw}"

  # Avoid sed -i (SELinux context issues in some environments)
  python3 - "${raw}" "${script}" "${mock_utils}" "${results_dir}" "${catalog_file}" <<'PY'
import sys
src, dst, mock_utils, results_dir, catalog_file = sys.argv[1:]
text = open(src).read()
text = text.replace("source /utils.sh", f"source {mock_utils}")
text = text.replace(". /utils.sh", f"source {mock_utils}")
text = text.replace("$(results.TEST_OUTPUT.path)", f"{results_dir}/TEST_OUTPUT")
text = text.replace("$(results.IMAGES_PROCESSED.path)", f"{results_dir}/IMAGES_PROCESSED")
text = text.replace("$(context.task.name)", "fbc-target-index-pruning-check")
text = text.replace("/shared/catalog.json", catalog_file)
open(dst, "w").write(text)
PY

  chmod +x "${script}"
  echo "${script}"
}

write_matching_catalogs() {
  cat > "${catalog_file}" << 'EOF'
{"schema":"olm.package","name":"test-operator"}
{"schema":"olm.channel","package":"test-operator","name":"stable","entries":[{"name":"test-operator.v1.0.0"},{"name":"test-operator.v1.1.0"}]}
EOF
  export MOCK_FRAGMENT_CATALOG="${catalog_file}"
  export MOCK_INDEX_CATALOG=""
}

write_pruning_index_catalog() {
  local index_file
  index_file=$(mktemp) && cleanup+=("${index_file}")
  cat > "${catalog_file}" << 'EOF'
{"schema":"olm.package","name":"test-operator"}
{"schema":"olm.channel","package":"test-operator","name":"stable","entries":[{"name":"test-operator.v1.1.0"}]}
EOF
  cat > "${index_file}" << 'EOF'
{"schema":"olm.package","name":"test-operator"}
{"schema":"olm.channel","package":"test-operator","name":"stable","entries":[{"name":"test-operator.v1.0.0"},{"name":"test-operator.v1.1.0"}]}
EOF
  export MOCK_FRAGMENT_CATALOG="${catalog_file}"
  export MOCK_INDEX_CATALOG="${index_file}"
}

pruning_script="$(extract_script)"

setup_test() {
  rm -f "${results_dir}"/* 
  : > "${RENDER_CALLS_FILE}"
  export IMAGE_URL="registry.io/test/fbc-fragment"
  export IMAGE_DIGEST="sha256:abc123"
  export TARGET_INDEX="registry.redhat.io/redhat/redhat-operator-index"
  export MOCK_OCP_VERSIONS="v4.16"
  write_matching_catalogs
}

Describe "fbc-target-index-pruning-check multi-OCP support"
  BeforeEach setup_test

  It "succeeds for legacy single OCP version string"
    export MOCK_OCP_VERSIONS="v4.16"
    When call bash "${pruning_script}"
    The output should include "OCP versions to check: v4.16"
    The output should include "Checking pruning against OCP version: v4.16"
    The output should include "Rendering target index: registry.redhat.io/redhat/redhat-operator-index:v4.16"
    The status should be success
    The contents of file "${results_dir}/TEST_OUTPUT" should include '"result":"SUCCESS"'
    The contents of file "${RENDER_CALLS_FILE}" should include "registry.redhat.io/redhat/redhat-operator-index:v4.16"
  End

  It "renders target index for each version in a JSON array"
    export MOCK_OCP_VERSIONS='["v4.16","v4.17"]'
    When call bash "${pruning_script}"
    The output should include "OCP versions to check: v4.16 v4.17"
    The output should include "Checking pruning against OCP version: v4.16"
    The output should include "Checking pruning against OCP version: v4.17"
    The status should be success
    The contents of file "${results_dir}/TEST_OUTPUT" should include '"result":"SUCCESS"'
    The contents of file "${RENDER_CALLS_FILE}" should include "registry.redhat.io/redhat/redhat-operator-index:v4.16"
    The contents of file "${RENDER_CALLS_FILE}" should include "registry.redhat.io/redhat/redhat-operator-index:v4.17"
  End

  It "errors when OCP version helper returns an empty string"
    export MOCK_OCP_VERSIONS=""
    When call bash "${pruning_script}"
    The output should include "No OCP versions returned"
    The status should be success
    The contents of file "${results_dir}/TEST_OUTPUT" should include '"result":"ERROR"'
  End

  It "aggregates pruning failures across OCP versions"
    write_pruning_index_catalog
    export MOCK_OCP_VERSIONS='["v4.16","v4.17"]'
    When call bash "${pruning_script}"
    The output should include "!FAILURE!"
    The output should include "prunes test-operator.v1.0.0"
    The status should be success
    The contents of file "${results_dir}/TEST_OUTPUT" should include '"result":"FAILURE"'
    The contents of file "${results_dir}/TEST_OUTPUT" should include '"failures":2'
  End
End
