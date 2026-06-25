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

## OCI-TA variants

Generated from base tasks by `task-generator/trusted-artifacts/`. Run `hack/generate-ta-tasks.sh` after modifying a base task that has an OCI-TA counterpart. Do not edit `*-oci-ta` task YAMLs by hand.

## CI checks

YAML lint, Checkton, ShellSpec, Tekton integration tests, Go tests (task-generator), and migration validation all run on PRs. Check `.github/workflows/` for details.
