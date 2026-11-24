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
fixtures_dir=$(mktemp -d) && cleanup+=("${fixtures_dir}")
render_track=$(mktemp) && cleanup+=("${render_track}")

# Matching fragment/index catalogs (no pruning).
write_matching_catalog() {
    local outfile="$1"
    cat > "${outfile}" <<'EOF'
{"schema":"olm.channel","package":"test-op","name":"stable","entries":[{"name":"test-op.v1.0.0"},{"name":"test-op.v1.1.0"}]}
EOF
}

# Fragment drops test-op.v1.0.0 from stable → pruning FAILURE.
write_pruned_fragment_catalog() {
    local outfile="$1"
    cat > "${outfile}" <<'EOF'
{"schema":"olm.channel","package":"test-op","name":"stable","entries":[{"name":"test-op.v1.1.0"}]}
EOF
}

write_index_catalog() {
    local outfile="$1"
    cat > "${outfile}" <<'EOF'
{"schema":"olm.channel","package":"test-op","name":"stable","entries":[{"name":"test-op.v1.0.0"},{"name":"test-op.v1.1.0"}]}
EOF
}

# Index includes an unrelated package; fragment only has test-op → other-op must be filtered out.
write_index_with_extra_package() {
    local outfile="$1"
    cat > "${outfile}" <<'EOF'
{"schema":"olm.channel","package":"test-op","name":"stable","entries":[{"name":"test-op.v1.0.0"},{"name":"test-op.v1.1.0"}]}
{"schema":"olm.channel","package":"other-op","name":"stable","entries":[{"name":"other-op.v9.9.9"}]}
EOF
}

# Fragment omits stable entirely (only candidate) → entire stable channel prune FAILURE.
write_fragment_without_stable() {
    local outfile="$1"
    cat > "${outfile}" <<'EOF'
{"schema":"olm.channel","package":"test-op","name":"candidate","entries":[{"name":"test-op.v1.1.0"}]}
EOF
}

# Allowed-channel prune: candidate entry removed → SUCCESS (not FAILURE).
write_candidate_index() {
    local outfile="$1"
    cat > "${outfile}" <<'EOF'
{"schema":"olm.channel","package":"test-op","name":"candidate","entries":[{"name":"test-op.v1.0.0"},{"name":"test-op.v1.1.0"}]}
EOF
}

write_candidate_pruned_fragment() {
    local outfile="$1"
    cat > "${outfile}" <<'EOF'
{"schema":"olm.channel","package":"test-op","name":"candidate","entries":[{"name":"test-op.v1.1.0"}]}
EOF
}

mock_utils=$(mktemp --tmpdir mock_utils_XXXXXXXXXX.sh) && cleanup+=("${mock_utils}")
cat > "${mock_utils}" <<'MOCK_UTILS_EOF'
# EXIT trap always invokes handle_error; keep it a no-op under unit tests.
handle_error() { :; }

get_ocp_version_from_fbc_fragment() {
  printf '%s\n' "${MOCK_OCP_VERSIONS_RAW}"
}

make_result_json() {
  local result="UNKNOWN" note=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -r) result="$2"; shift 2 ;;
      -t) note="$2"; shift 2 ;;
      -f|-s) shift 2 ;;
      *) shift ;;
    esac
  done
  printf '{"result":"%s","note":"%s"}\n' "${result}" "${note}"
}

get_image_manifests() {
  echo '{"amd64": "sha256:abc123"}'
}

# Usage: render_opm -t <pullspec> --file
# Honors MOCK_RENDER_FAIL_TAG / MOCK_RENDER_MISSING_FILE_TAG for error paths.
# Tracks created paths in MOCK_RENDER_TRACK for cleanup assertions.
render_opm() {
  local pullspec=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -t) pullspec="$2"; shift 2 ;;
      --file) shift ;;
      *) shift ;;
    esac
  done
  local tag="${pullspec##*:}"

  # Prior render paths must already be cleaned up before the next render_opm call
  if [[ -n "${MOCK_RENDER_TRACK:-}" && -f "${MOCK_RENDER_TRACK}" ]]; then
    local prior
    while IFS= read -r prior; do
      [[ -z "${prior}" ]] && continue
      if [[ -e "${prior}" ]]; then
        echo "render leak: expected prior render file removed before next render_opm: ${prior}" >&2
        return 1
      fi
    done < "${MOCK_RENDER_TRACK}"
  fi

  if [[ -n "${MOCK_RENDER_FAIL_TAG:-}" && "${tag}" == "${MOCK_RENDER_FAIL_TAG}" ]]; then
    # Simulate a partial file left behind on non-zero exit
    local partial
    partial=$(mktemp)
    echo "partial-render-${tag}" > "${partial}"
    if [[ -n "${MOCK_RENDER_TRACK:-}" ]]; then
      printf '%s\n' "${partial}" >> "${MOCK_RENDER_TRACK}"
    fi
    echo "${partial}"
    return 1
  fi

  if [[ -n "${MOCK_RENDER_MISSING_FILE_TAG:-}" && "${tag}" == "${MOCK_RENDER_MISSING_FILE_TAG}" ]]; then
    echo "/tmp/does-not-exist-render-opm-${tag}.json"
    return 0
  fi

  local tmpfile
  tmpfile=$(mktemp)
  if [[ -n "${MOCK_INDEX_CATALOG:-}" && -f "${MOCK_INDEX_CATALOG}" ]]; then
    cat "${MOCK_INDEX_CATALOG}" > "${tmpfile}"
  else
    echo '{"schema":"olm.channel","package":"test-op","name":"stable","entries":[{"name":"test-op.v1.0.0"},{"name":"test-op.v1.1.0"}]}' > "${tmpfile}"
  fi
  if [[ -n "${MOCK_RENDER_TRACK:-}" ]]; then
    printf '%s\n' "${tmpfile}" >> "${MOCK_RENDER_TRACK}"
  fi
  echo "${tmpfile}"
}
MOCK_UTILS_EOF

extract_script() {
    local script
    script="$(mktemp --tmpdir script_XXXXXXXXXX.sh)"
    yq -r ".spec.steps[] | select(.name == \"$1\").script" "${task_path}" > "${script}"

    # This task sources utils with bash `source`; other tasks use POSIX `.` — cover both.
    sed -i "s|source /utils.sh|source ${mock_utils}|g" "${script}"
    sed -i "s|\. /utils.sh|source ${mock_utils}|g" "${script}"
    sed -i 's|$(results.TEST_OUTPUT.path)|'"${results_dir}"'/TEST_OUTPUT|g' "${script}"
    sed -i 's|$(results.IMAGES_PROCESSED.path)|'"${results_dir}"'/IMAGES_PROCESSED|g' "${script}"
    sed -i 's|$(context.task.name)|fbc-target-index-pruning-check|g' "${script}"
    # Point rendered FBC fragment at our temp shared dir
    sed -i "s|/shared|${shared_dir}|g" "${script}"

    chmod +x "${script}"
    echo "${script}"
}

pruning_script="$(extract_script run-pruning-check)"
cleanup+=("${pruning_script}")

assert_tracked_renders_removed() {
    local path
    while IFS= read -r path; do
        [[ -z "${path}" ]] && continue
        if [[ -e "${path}" ]]; then
            echo "expected render file to be removed: ${path}" >&2
            return 1
        fi
    done < "${MOCK_RENDER_TRACK}"
}

setup_test() {
    rm -f "${results_dir}"/* "${shared_dir}"/*
    : > "${render_track}"
    unset MOCK_RENDER_FAIL_TAG MOCK_RENDER_MISSING_FILE_TAG || true
    export MOCK_RENDER_TRACK="${render_track}"
    export MOCK_INDEX_CATALOG="${fixtures_dir}/index.json"
    write_index_catalog "${MOCK_INDEX_CATALOG}"
    write_matching_catalog "${shared_dir}/catalog.json"
    export MOCK_OCP_VERSIONS_RAW='v4.18'
}

Describe "fbc-target-index-pruning-check multi-OCP"
    export IMAGE_URL=registry.io/test-operator/fbc-fragment:tag
    export IMAGE_DIGEST=sha256:abc123
    export TARGET_INDEX=registry.redhat.io/redhat/redhat-operator-index

    BeforeEach setup_test

    It "checks each version from a JSON array of OCP versions"
        export MOCK_OCP_VERSIONS_RAW='["4.18","4.19"]'
        When call "${pruning_script}"
        The output should include "OCP versions to check: v4.18 v4.19"
        The output should include "Checking pruning against OCP version: v4.18"
        The output should include "Checking pruning against OCP version: v4.19"
        The output should include "Rendering target index: ${TARGET_INDEX}:v4.18"
        The output should include "Rendering target index: ${TARGET_INDEX}:v4.19"
        The contents of file "${results_dir}/TEST_OUTPUT" should include '"result":"SUCCESS"'
        The status should be success
        Assert assert_tracked_renders_removed
    End

    It "supports a single string OCP version from the helper"
        export MOCK_OCP_VERSIONS_RAW='v4.18'
        When call "${pruning_script}"
        The output should include "OCP versions to check: v4.18"
        The output should include "Checking pruning against OCP version: v4.18"
        The contents of file "${results_dir}/TEST_OUTPUT" should include '"result":"SUCCESS"'
        The status should be success
        Assert assert_tracked_renders_removed
    End

    It "continues after a render failure and reports ERROR"
        export MOCK_OCP_VERSIONS_RAW='["4.18","4.19"]'
        export MOCK_RENDER_FAIL_TAG='v4.18'
        When call "${pruning_script}"
        The output should include "Unable to render the target index image: ${TARGET_INDEX}:v4.18"
        The output should include "Checking pruning against OCP version: v4.19"
        The contents of file "${results_dir}/TEST_OUTPUT" should include '"result":"ERROR"'
        The status should be success
        Assert assert_tracked_renders_removed
    End

    It "continues after render_opm returns a missing file path and reports ERROR"
        export MOCK_OCP_VERSIONS_RAW='["4.18","4.19"]'
        export MOCK_RENDER_MISSING_FILE_TAG='v4.18'
        When call "${pruning_script}"
        The output should include "!ERROR!"
        The output should include "Unable to render the target index image: ${TARGET_INDEX}:v4.18"
        The output should include "Checking pruning against OCP version: v4.19"
        The contents of file "${results_dir}/TEST_OUTPUT" should include '"result":"ERROR"'
        The status should be success
    End

    It "reports FAILURE when a non-allowed channel entry is pruned"
        export MOCK_OCP_VERSIONS_RAW='v4.18'
        write_pruned_fragment_catalog "${shared_dir}/catalog.json"
        When call "${pruning_script}"
        The output should include "!FAILURE!"
        The output should include "prunes test-op.v1.0.0 from test-op.stable channel"
        The contents of file "${results_dir}/TEST_OUTPUT" should include '"result":"FAILURE"'
        The status should be success
    End

    It "allows pruning from candidate channel and reports SUCCESS"
        export MOCK_OCP_VERSIONS_RAW='v4.18'
        write_candidate_index "${MOCK_INDEX_CATALOG}"
        write_candidate_pruned_fragment "${shared_dir}/catalog.json"
        When call "${pruning_script}"
        The output should include "Pruning in candidate channel is allowed"
        The output should not include "!FAILURE!"
        The contents of file "${results_dir}/TEST_OUTPUT" should include '"result":"SUCCESS"'
        The status should be success
    End

    It "filters index packages to those present in the FBC fragment"
        export MOCK_OCP_VERSIONS_RAW='v4.18'
        write_index_with_extra_package "${MOCK_INDEX_CATALOG}"
        When call "${pruning_script}"
        The output should not include "other-op"
        The output should not include "!FAILURE!"
        The contents of file "${results_dir}/TEST_OUTPUT" should include '"result":"SUCCESS"'
        The status should be success
    End

    It "reports FAILURE when an entire non-allowed channel is pruned"
        export MOCK_OCP_VERSIONS_RAW='v4.18'
        write_fragment_without_stable "${shared_dir}/catalog.json"
        When call "${pruning_script}"
        The output should include "!FAILURE!"
        The output should include "prunes entire test-op.stable channel"
        The contents of file "${results_dir}/TEST_OUTPUT" should include '"result":"FAILURE"'
        The status should be success
    End

    It "aggregates render ERROR with pruning FAILURE across OCP versions"
        export MOCK_OCP_VERSIONS_RAW='["4.18","4.19"]'
        export MOCK_RENDER_FAIL_TAG='v4.18'
        write_pruned_fragment_catalog "${shared_dir}/catalog.json"
        When call "${pruning_script}"
        The output should include "!ERROR!"
        The output should include "Unable to render the target index image: ${TARGET_INDEX}:v4.18"
        The output should include "!FAILURE!"
        The output should include "prunes test-op.v1.0.0 from test-op.stable channel"
        The contents of file "${results_dir}/TEST_OUTPUT" should include '"result":"ERROR"'
        The contents of file "${results_dir}/TEST_OUTPUT" should include '1 OCP version render/index error(s).'
        The contents of file "${results_dir}/TEST_OUTPUT" should include 'Also found 1 pruning violation(s).'
        The status should be success
    End

    It "reports ERROR when OCP version helper returns empty"
        export MOCK_OCP_VERSIONS_RAW=''
        When call "${pruning_script}"
        The output should include "Unable to determine OCP version(s)."
        The contents of file "${results_dir}/TEST_OUTPUT" should include '"result":"ERROR"'
        The contents of file "${results_dir}/TEST_OUTPUT" should include 'Unable to determine OCP version(s).'
        The status should be success
    End

    It "reports ERROR when OCP version list is an empty JSON array"
        export MOCK_OCP_VERSIONS_RAW='[]'
        When call "${pruning_script}"
        The output should include "Parsed OCP version list is empty."
        The contents of file "${results_dir}/TEST_OUTPUT" should include '"result":"ERROR"'
        The contents of file "${results_dir}/TEST_OUTPUT" should include 'Parsed OCP version list is empty.'
        The status should be success
    End

    It "reports ERROR when OCP version array contains only empty strings"
        export MOCK_OCP_VERSIONS_RAW='[""]'
        When call "${pruning_script}"
        The output should include "Parsed OCP version list is empty."
        The contents of file "${results_dir}/TEST_OUTPUT" should include '"result":"ERROR"'
        The contents of file "${results_dir}/TEST_OUTPUT" should include 'Parsed OCP version list is empty.'
        The status should be success
    End
End

