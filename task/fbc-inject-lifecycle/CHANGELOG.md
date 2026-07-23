# Changelog

## 0.1

### Added

- Initial version of `fbc-inject-lifecycle` task
- Checks whether a file-based catalog (FBC) component is eligible for lifecycle injection (targets OCP 5.0+)
- Determines target OLM packages from the Dockerfile
- Generates lifecycle JSON files using `plcc2fbc`
- Injects lifecycle data into the catalog source directories

### Note

Workspace-source variant; the Trusted Artifacts equivalent is `fbc-inject-lifecycle-oci-ta`.
