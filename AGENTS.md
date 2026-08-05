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

## OCI-TA variants

Generated from base tasks by `task-generator/trusted-artifacts/`. Run `hack/generate-ta-tasks.sh` after modifying a base task that has an OCI-TA counterpart. Do not edit `*-oci-ta` task YAMLs by hand.

## CI checks

YAML lint, Checkton, ShellSpec, Tekton integration tests, Go tests (task-generator), and migration validation all run on PRs. Check `.github/workflows/` for details.

## Migration scripts

Migration scripts (`task/<name>/<version>/migrations/<version>.sh`) are **immutable once merged**. The CI check `hack/validate-migration.sh` rejects any PR that modifies or deletes an existing migration file.

To fix a broken migration:

1. Bump the `app.kubernetes.io/version` label in the task YAML (e.g., `0.2` → `0.2.1`)
2. Create a new migration script (e.g., `migrations/0.2.1.sh`) that supersedes the broken one
3. Use `hack/create-task-migration.sh` to scaffold the new migration

**Never edit an existing migration script in place.**

Additional constraints enforced by `hack/validate-migration.sh`:

- One migration per task per PR
- Version-label match requirement
- Migration must modify at least one Konflux pipeline
- OCI-TA variant migrations must exist if the base task has an OCI-TA counterpart

