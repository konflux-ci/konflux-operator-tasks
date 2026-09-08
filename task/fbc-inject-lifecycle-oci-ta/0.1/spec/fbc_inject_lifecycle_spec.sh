#!/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

eval "$(shellspec - -c) exit 1"

task_path=fbc-inject-lifecycle-oci-ta.yaml
if [[ -f "../${task_path}" ]]; then
    task_path="../${task_path}"
fi

cleanup=()
trap 'rm -rf "${cleanup[@]}"' EXIT

results_dir=$(mktemp -d) && cleanup+=("${results_dir}")
tekton_steps_dir=$(mktemp -d) && cleanup+=("${tekton_steps_dir}")
shared_dir=$(mktemp -d) && cleanup+=("${shared_dir}")
fake_bin=$(mktemp -d) && cleanup+=("${fake_bin}")
inject_flags_file=$(mktemp) && cleanup+=("${inject_flags_file}")

# operator-foundry mock: records inject-lifecycle flags; echoes valid JSON for make-result-json
cat > "${fake_bin}/operator-foundry" << MOCK_EOF
#!/bin/bash
if [[ "\$1 \$2 \$3" == "fbc inject-lifecycle" ]]; then
    echo "\$*" > "${inject_flags_file}"
    exit 0
fi
echo '{"result":"SUCCESS","successes":1}'
MOCK_EOF
chmod +x "${fake_bin}/operator-foundry"
export PATH="${fake_bin}:${PATH}"

mkdir -p \
    "${tekton_steps_dir}/step-check-lifecycle-eligibility" \
    "${tekton_steps_dir}/step-get-packages" \
    "${tekton_steps_dir}/step-generate-lifecycle" \
    "${shared_dir}/lifecycle"

extract_inject_script() {
    local script
    script="$(mktemp --tmpdir inject_script_XXXXXXXXXX.sh)"
    # inject-lifecycle uses command/args, not script — the bash code is in args[0]
    yq -r ".spec.steps[] | select(.name == \"inject-lifecycle\").args[0]" "${task_path}" > "${script}"

    sed -i "s|\$(results.SOURCE_ARTIFACT.path)|${results_dir}/SOURCE_ARTIFACT|g" "${script}"
    sed -i "s|\$(results.TEST_OUTPUT.path)|${results_dir}/TEST_OUTPUT|g" "${script}"
    sed -i "s|\$(step.results.skip_create_trusted_artifact.path)|${results_dir}/skip_create_trusted_artifact|g" "${script}"
    sed -i "s|\$(context.task.name)|fbc-inject-lifecycle-oci-ta|g" "${script}"
    sed -i "s|/tekton/steps/|${tekton_steps_dir}/|g" "${script}"
    sed -i "s|/shared/|${shared_dir}/|g" "${script}"

    chmod +x "${script}"
    echo "${script}"
}

inject_script="$(extract_inject_script)"
cleanup+=("${inject_script}")

setup() {
    rm -f "${results_dir}"/* "${inject_flags_file}"

    echo "0" > "${tekton_steps_dir}/step-check-lifecycle-eligibility/exitCode"
    echo "true" > "${shared_dir}/eligible"
    echo "0" > "${tekton_steps_dir}/step-get-packages/exitCode"
    echo "my-operator" > "${shared_dir}/packages.txt"
    echo "0" > "${tekton_steps_dir}/step-generate-lifecycle/exitCode"

    export DOCKERFILE=./Dockerfile
    export CONTEXT=.
    export SOURCE_ARTIFACT="oci://example.com/source@sha256:abc"
    export CATALOG_PATH=""
}

Describe "inject-lifecycle step: INJECT_FLAGS flag selection"
    BeforeEach setup

    It "passes --dockerfile when CATALOG_PATH is empty"
        export CATALOG_PATH=""
        When call bash "${inject_script}"
        The status should be success
        The contents of file "${inject_flags_file}" should include "--dockerfile"
        The contents of file "${inject_flags_file}" should not include "--catalog-path"
        The contents of file "${results_dir}/skip_create_trusted_artifact" should equal "false"
    End

    It "passes --catalog-path when CATALOG_PATH is non-empty"
        export CATALOG_PATH=".konflux/catalog"
        When call bash "${inject_script}"
        The status should be success
        The contents of file "${inject_flags_file}" should include "--catalog-path .konflux/catalog"
        The contents of file "${inject_flags_file}" should not include "--dockerfile"
        The contents of file "${results_dir}/skip_create_trusted_artifact" should equal "false"
    End
End

Describe "inject-lifecycle step: eligibility check failures"
    BeforeEach setup

    It "reports FAILURE and skips injection when eligibility step exits non-zero"
        echo "1" > "${tekton_steps_dir}/step-check-lifecycle-eligibility/exitCode"
        When call bash "${inject_script}"
        The status should be success
        The contents of file "${results_dir}/TEST_OUTPUT" should include "FAILURE"
        The contents of file "${results_dir}/skip_create_trusted_artifact" should equal "true"
        The file "${inject_flags_file}" should not be exist
    End

    It "skips injection and reports SUCCESS when component is not eligible"
        echo "false" > "${shared_dir}/eligible"
        When call bash "${inject_script}"
        The status should be success
        The contents of file "${results_dir}/TEST_OUTPUT" should include "SUCCESS"
        The contents of file "${results_dir}/skip_create_trusted_artifact" should equal "true"
        The file "${inject_flags_file}" should not be exist
    End
End

Describe "inject-lifecycle step: downstream step failures"
    BeforeEach setup

    It "reports FAILURE when get-packages step exits non-zero"
        echo "1" > "${tekton_steps_dir}/step-get-packages/exitCode"
        When call bash "${inject_script}"
        The status should be success
        The contents of file "${results_dir}/TEST_OUTPUT" should include "FAILURE"
        The contents of file "${results_dir}/skip_create_trusted_artifact" should equal "true"
    End

    It "reports FAILURE when eligible but no packages found"
        echo "" > "${shared_dir}/packages.txt"
        When call bash "${inject_script}"
        The status should be success
        The contents of file "${results_dir}/TEST_OUTPUT" should include "FAILURE"
        The contents of file "${results_dir}/skip_create_trusted_artifact" should equal "true"
    End

    It "reports FAILURE when generate-lifecycle step exits non-zero"
        echo "1" > "${tekton_steps_dir}/step-generate-lifecycle/exitCode"
        When call bash "${inject_script}"
        The status should be success
        The contents of file "${results_dir}/TEST_OUTPUT" should include "FAILURE"
        The contents of file "${results_dir}/skip_create_trusted_artifact" should equal "true"
    End
End
