# AGENTS.md

## Repository

Tekton task catalog for Konflux CI. Tasks live under `task/<name>/<version>/`.

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
    ├── recipe.yaml          # OCI-TA tasks only
    ├── spec/                # ShellSpec tests
    └── tests/               # Tekton integration tests
```

## Multi-version task consistency

Some tasks have multiple version directories (e.g., `task/validate-fbc/0.1/` and `0.2/`). When modifying a task that has more than one version:

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

Generated from base tasks by `task-generator/trusted-artifacts/`. Run `hack/generate-ta-tasks.sh` after modifying a base task that has an OCI-TA counterpart. Do not edit `*-oci-ta` task YAMLs by hand.

## CI checks

YAML lint, Checkton, ShellSpec, Tekton integration tests, Go tests (task-generator), and migration validation all run on PRs. Check `.github/workflows/` for details.
