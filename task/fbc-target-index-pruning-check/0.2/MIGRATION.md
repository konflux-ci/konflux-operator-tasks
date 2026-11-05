# Migration from 0.1 to 0.2

Version 0.2 adds multi-OCP / binaryless FBC support. Task parameters and results are unchanged.

Use **0.2** when fragments may declare multiple OCP versions via `com.redhat.fbc.openshift.version`.
Keep **0.1** only if you intentionally want the legacy single-version check.

## Action from users

Bump the task reference version in your pipeline from `"0.1"` to `"0.2"`. No parameter changes are required.

```diff
     - name: fbc-target-index-pruning-check
       taskRef:
         name: fbc-target-index-pruning-check
-        version: "0.1"
+        version: "0.2"
       params:
       - name: IMAGE_URL
         value: $(tasks.build-image-index.results.IMAGE_URL)
       - name: IMAGE_DIGEST
         value: $(tasks.build-image-index.results.IMAGE_DIGEST)
       - name: RENDERED_CATALOG_DIGEST
         value: $(tasks.fbc-related-image-check.results.RENDERED_CATALOG_DIGEST)
```

After `0.2` is published to the task catalog / build-definitions, update any hard-coded bundle digests or `fbc-builder` references to the new version.
