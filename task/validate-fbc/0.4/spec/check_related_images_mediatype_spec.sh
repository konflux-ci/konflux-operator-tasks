#!/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

eval "$(shellspec - -c) exit 1"

task_path=validate-fbc.yaml
if [[ -f "../${task_path}" ]]; then
    task_path="../${task_path}"
fi

cleanup=()
trap 'rm -rf "${cleanup[@]}"' EXIT

results_dir=$(mktemp -d) && cleanup+=("${results_dir}")
shared_dir=$(mktemp -d) && cleanup+=("${shared_dir}")
fake_bin=$(mktemp -d) && cleanup+=("${fake_bin}")
foundry_flags_file="${TMPDIR:-/tmp}/foundry_flags_$$" && cleanup+=("${foundry_flags_file}")

# operator-foundry mock: records check-related-images-mediatype flags; echoes valid JSON for make-result-json
cat > "${fake_bin}/operator-foundry" << MOCK_EOF
#!/bin/bash
if [[ "\$1 \$2" == "fbc check-related-images-mediatype" ]]; then
    echo "\$*" > "${foundry_flags_file}"
    # Parse --output flag to write result file
    output_file=""
    shift 2
    while [[ \$# -gt 0 ]]; do
        case "\$1" in
            --output) output_file="\$2"; shift ;;
        esac
        shift
    done
    if [[ -n "\${output_file}" && -n "\${MOCK_FOUNDRY_RESULT:-}" ]]; then
        echo "\${MOCK_FOUNDRY_RESULT}" > "\${output_file}"
    fi
    exit "\${MOCK_FOUNDRY_EXIT_CODE:-0}"
fi
# make-result-json: parse --result, --successes, --failures, --note and echo matching JSON
result="SUCCESS"
successes=0
failures=0
note=""
shift  # skip 'make-result-json'
while [[ \$# -gt 0 ]]; do
    case "\$1" in
        --result) result="\$2"; shift ;;
        --successes) successes="\$2"; shift ;;
        --failures) failures="\$2"; shift ;;
        --note) note="\$2"; shift ;;
    esac
    shift
done
echo "{\"result\":\"\${result}\",\"successes\":\${successes},\"failures\":\${failures},\"note\":\"\${note}\"}"
MOCK_EOF
chmod +x "${fake_bin}/operator-foundry"

SED_I=(sed -i)
if sed --version 2>/dev/null | grep -q GNU; then :; else SED_I=(sed -i ''); fi

export PATH="${fake_bin}:${PATH}"

extract_script() {
    local step_name="$1"
    local script
    script="$(mktemp "${TMPDIR:-/tmp}/script_XXXXXXXXXX.sh")"
    yq -r ".spec.steps[] | select(.name == \"${step_name}\").script" "${task_path}" > "${script}"

    "${SED_I[@]}" "s|\$(results.TEST_OUTPUT.path)|${results_dir}/TEST_OUTPUT|g" "${script}"
    "${SED_I[@]}" "s|/shared/|${shared_dir}/|g" "${script}"

    chmod +x "${script}"
    echo "${script}"
}

check_script="$(extract_script check-related-images-mediatype)"
cleanup+=("${check_script}")

setup() {
    rm -f "${results_dir}"/* "${foundry_flags_file}"
    rm -f "${shared_dir}"/*

    printf '%s' "12" > "${shared_dir}/check-num"
    printf '%s' "v4.18" > "${shared_dir}/ocp-version"
    echo '[{"image":"registry.redhat.io/test/img@sha256:abc"}]' > "${shared_dir}/related-images.json"

    mkdir -p "${shared_dir}/../mediatype-home/.docker" 2>/dev/null || true

    export MOCK_FOUNDRY_EXIT_CODE=0
    export MOCK_FOUNDRY_RESULT='{"result":"SUCCESS","successes":1,"failures":0}'
    export SOURCE_CODE_DIR="/var/workdir"
    export IMAGE_MIRROR_SET_PATH=".tekton/images-mirror-set.yaml"
}

Describe "check-related-images-mediatype step: bail on prior failure"
    BeforeEach setup

    It "bails when TEST_OUTPUT already contains content from previous step"
        echo '{"result":"FAILURE"}' > "${results_dir}/TEST_OUTPUT"
        When call bash "${check_script}"
        The status should be success
        The output should include "Test failed in previous step"
        The contents of file "${results_dir}/TEST_OUTPUT" should include "FAILURE"
        The file "${foundry_flags_file}" should not be exist
    End
End

Describe "check-related-images-mediatype step: missing shared files"
    BeforeEach setup

    It "reports ERROR when check-num is missing"
        rm -f "${shared_dir}/check-num"
        When call bash "${check_script}"
        The status should be success
        The output should include "Extract check count not available"
        The contents of file "${results_dir}/TEST_OUTPUT" should include "ERROR"
    End

    It "reports ERROR when ocp-version is missing"
        rm -f "${shared_dir}/ocp-version"
        When call bash "${check_script}"
        The status should be success
        The output should include "OCP version not available"
        The contents of file "${results_dir}/TEST_OUTPUT" should include "ERROR"
    End

    It "reports ERROR when related-images.json is missing"
        rm -f "${shared_dir}/related-images.json"
        When call bash "${check_script}"
        The status should be success
        The output should include "Related images not available"
        The contents of file "${results_dir}/TEST_OUTPUT" should include "ERROR"
    End
End

Describe "check-related-images-mediatype step: operator-foundry invocation"
    BeforeEach setup

    It "passes correct flags to operator-foundry"
        When call bash "${check_script}"
        The status should be success
        The output should include "SUCCESS"
        The contents of file "${foundry_flags_file}" should include "fbc check-related-images-mediatype"
        The contents of file "${foundry_flags_file}" should include "--ocp-version v4.18"
        The contents of file "${foundry_flags_file}" should include "--related-images-json-path"
        The contents of file "${foundry_flags_file}" should include "--image-mirror-set-path /var/workdir/source/.tekton/images-mirror-set.yaml"
        The contents of file "${foundry_flags_file}" should include "--output"
    End

    It "reports ERROR when operator-foundry exits non-zero"
        export MOCK_FOUNDRY_EXIT_CODE=1
        When call bash "${check_script}"
        The status should be success
        The output should include "ERROR"
        The contents of file "${results_dir}/TEST_OUTPUT" should include "ERROR"
    End

    It "reports ERROR when operator-foundry exits 0 but writes no output"
        export MOCK_FOUNDRY_RESULT=""
        When call bash "${check_script}"
        The status should be success
        The output should include "ERROR"
        The contents of file "${results_dir}/TEST_OUTPUT" should include "ERROR"
    End
End

Describe "check-related-images-mediatype step: result folding"
    BeforeEach setup

    It "writes SUCCESS with folded check count on pass"
        export MOCK_FOUNDRY_RESULT='{"result":"SUCCESS","successes":1,"failures":0}'
        When call bash "${check_script}"
        The status should be success
        The output should include "SUCCESS"
        The contents of file "${results_dir}/TEST_OUTPUT" should include "SUCCESS"
        The contents of file "${results_dir}/TEST_OUTPUT" should include '"successes":13'
    End

    It "writes FAILURE with original check count on mediatype failure"
        export MOCK_FOUNDRY_RESULT='{"result":"FAILURE","successes":0,"failures":1,"note":"bad mediatype"}'
        When call bash "${check_script}"
        The status should be success
        The output should include "FAILURE"
        The contents of file "${results_dir}/TEST_OUTPUT" should include "FAILURE"
        The contents of file "${results_dir}/TEST_OUTPUT" should include '"successes":12'
        The contents of file "${results_dir}/TEST_OUTPUT" should include '"failures":1'
    End
End
