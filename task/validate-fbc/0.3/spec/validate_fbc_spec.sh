#!/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

eval "$(shellspec - -c) exit 1"

task_path=validate-fbc.yaml
if [[ -f "../${task_path}" ]]; then
    task_path="../${task_path}"
fi

Describe "validate-fbc result behavior"
    It "writes the final success result in extract-and-validate"
        When call yq -r '.spec.steps[] | select(.name == "extract-and-validate") | .script' "${task_path}"
        The output should include 'make_result_json -r SUCCESS -s $check_num'
        The output should include '$(results.TEST_OUTPUT.path)'
        The status should be success
    End

    It "does not run the OCI related-image mediaType check"
        When call yq -r '.spec.steps[].name' "${task_path}"
        The output should not include 'check-related-images-mediatype'
        The status should be success
    End
End
