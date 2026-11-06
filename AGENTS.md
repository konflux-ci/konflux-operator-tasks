# AGENTS.md

## Repository

Tekton task catalog for Konflux CI. Tasks live under `task/<name>/<version>/`.

## Issue tracking

Work is tracked in Jira, not GitHub Issues. PR titles follow the format `type(JIRA-ID): description` (e.g., `feat(CLOUDDST-32936): deprecate validate-fbc 0.1 and 0.2`). A Jira ticket reference in the PR title constitutes valid work authorization — do not flag PRs as missing a linked issue when a Jira ID is present.

## Testing

Every change to a task **must** include or update tests. Two testing layers exist:

### ShellSpec (unit tests)

- Location: `task/<name>/<version>/spec/*_spec.sh`
- Run locally: `hack/test-shellspec.sh` (auto-installs shellspec if missing)
- Pattern: extract the step script from the task YAML with `yq`, mock external commands, assert output/status
- See `task/fbc-fips-check/0.1/spec/fbc_fips_check_spec.sh` for a representative example

### Tekton integration tests

- Location: `task/<name>/<version>/tests/test-*.yaml`
- Setup hook: `tests/pre-apply-task-hook.sh` creates required k8s resources
- Runs in CI via `.github/scripts/test_tekton_tasks.sh` on a Kind cluster
- Use annotation `test/assert-task-failure` to test expected failures

### Running tests

```bash
# ShellSpec (runs only for changed files relative to main)
hack/test-shellspec.sh
```

## Task structure

```
task/<name>/
├── CHANGELOG.md
└── <version>/
    ├── <name>.yaml          # Tekton Task definition
    ├── README.md
    ├── recipe.yaml          # Generated OCI-TA tasks only
    ├── spec/                # ShellSpec tests
    └── tests/               # Tekton integration tests
```

## Step conventions

When adding or modifying steps in a Tekton task, follow these conventions.

### securityContext

Steps that access container registries (using `oras`, `skopeo`, `operator-foundry`, `konflux-test`, or any tool that reads OCI/Docker credentials) typically need elevated privileges:

```yaml
securityContext:
  runAsUser: 0
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
    add:
      - SETFCAP
  readOnlyRootFilesystem: true
```

Steps that only perform local computation (no registry access, no credential files) should minimize privileges:

```yaml
securityContext:
  allowPrivilegeEscalation: false
  capabilities:
    drop:
      - ALL
  readOnlyRootFilesystem: true
```

When adding a new step, check whether it accesses registries or reads credential files. If it does not, omit `runAsUser: 0` and `SETFCAP`. See `task/validate-fbc/0.3/validate-fbc.yaml` for both patterns in one task.

### volumeMounts

Common shared volumes:

- **`/shared`** (`emptyDir: {}`) — inter-step data exchange within a task. Typically mounted via `stepTemplate` so all steps share it.
- **`/tmp`** (`emptyDir: {}`) — required per-step when `readOnlyRootFilesystem: true` is set, since the container's `/tmp` is not writable otherwise. Also used for Docker credential access (`/tmp/.docker/config.json`) in registry-accessing steps.

### env variables

- **`HOME=/tmp`** — the standard setting for steps that access registries. Tekton's credential initializer copies pull-secret credentials into `$HOME/.docker/config.json`, so setting `HOME=/tmp` (with a `/tmp` emptyDir mount) makes credentials available. When a non-root step runs after root steps that wrote to `/tmp/.docker`, use a step-local HOME (e.g., `HOME=/tmp/mediatype-home`) to avoid permission conflicts.
- **`DOCKER_CONFIG`** — set explicitly only when the step needs a non-default Docker config path (e.g., `DOCKER_CONFIG=/tmp/mediatype-home/.docker` for non-root steps that need their own credential directory).

### TEST_OUTPUT formatting

Steps that produce test results must write structured JSON to `$(results.TEST_OUTPUT.path)`. Two approaches exist:

- **`make_result_json`** (shell function from the `konflux-test` image) — the established pattern used by most tasks: `TEST_OUTPUT=$(make_result_json -r "SUCCESS" -s 1 -t "$note")`
- **`operator-foundry make-result-json`** (CLI from the `operator-foundry` image) — the newer tool for tasks using that image: `operator-foundry make-result-json --result SUCCESS --successes 1 --note "$note"`

Use whichever tool is available in the step's container image. **Every exit path** (success, failure, error, unexpected) must write a valid TEST_OUTPUT result — missing output on any path risks silent failures. Check that no code path can reach `exit` without first writing to `$(results.TEST_OUTPUT.path)`.

### Prior-step failure check

Steps that run after other result-producing steps should check whether a prior step already wrote a failure result, and bail out early if so:

```bash
if [[ -s $(results.TEST_OUTPUT.path) ]]; then
  echo "Test failed in previous step. Bailing."
  exit 0
fi
```

This works because Tekton task results are shared across all steps. Use `exit 0` (not a failure code) so the task completes normally — the prior step's TEST_OUTPUT already carries the failure information. See `task/validate-fbc/0.3/validate-fbc.yaml` for this pattern.

## Multi-version task consistency

Some tasks have multiple version directories (e.g., `task/foo/0.1/` and `0.2/`). When modifying a task that has more than one version:

1. **Check for other versions.** List the version directories under `task/<name>/` before making changes.
2. **Propagate changes to all versions** unless there is a documented reason for divergence. If a newer version's `CHANGELOG.md` states "no functional changes," it should mirror the older version's logic.
3. **Check `CHANGELOG.md`** to understand the relationship between versions and whether divergence is intentional.
4. **Update documentation across all versions.** Keep `README.md` and any other docs in sync when the underlying behavior changes.

## Workspace/OCI-TA variant consistency

Some tasks exist as both a workspace variant (PVC-based) and an OCI-TA variant (trusted-artifact-based), e.g., `fbc-fips-check` and `fbc-fips-check-oci-ta`. When creating or modifying a task that has a variant counterpart:

1. **Check for the counterpart variant** under `task/`. If `task/foo/` exists, check for `task/foo-oci-ta/` and vice versa.
2. **Use the same container image digests** across both variants unless a documented reason for divergence exists.
3. **Keep parameter sets aligned.** Both variants should have the same functional parameters. Only parameters inherent to the delivery mechanism should differ (e.g., `SOURCE_ARTIFACT` for OCI-TA, `workspaces` for workspace).
4. **Maintain step logic consistency.** The same directory creation, error handling, and output format should appear in both variants.
5. **Cross-reference the counterpart's CHANGELOG** when making changes.

This guidance applies to both standalone OCI-TA tasks (which have no `recipe.yaml`) and generated ones. For generated OCI-TA tasks, the generation script handles consistency; for standalone pairs, this manual guidance fills the gap.

## OCI-TA variants

Some `*-oci-ta` tasks are **generated** from base tasks by `task-generator/trusted-artifacts/`. These tasks have a `recipe.yaml` file that references their base task. After modifying a base task that has a generated OCI-TA counterpart, run `hack/generate-ta-tasks.sh` to regenerate. Do not edit generated `*-oci-ta` task YAMLs by hand — check for `recipe.yaml` first.

Other `*-oci-ta` tasks are **standalone** — they have no base task and no `recipe.yaml`. These are authored and edited directly like any other task.

## CI checks

YAML lint, Checkton, ShellSpec, Tekton integration tests, Go tests (task-generator), and migration validation all run on PRs. Check `.github/workflows/` for details.
