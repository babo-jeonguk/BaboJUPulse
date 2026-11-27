Closes #

## Summary

<!-- What changed, and why? Link the issue above. -->

## Evidence

<!-- Keep this self-contained. Do not link to local-only artifacts or absolute paths. -->

- **Before:**
- **After:**
- **Verification:** <commit SHA · commands or CI run · result>
- **Not verified:**

## Risk

- **Blast radius:**
- **Rollback:**

## Checklist

- [ ] The change matches the linked issue and adds no unrequested scope.
- [ ] `dotnet format`, build, and tests pass on the final commit.
- [ ] New behavior has tests; a bug fix has a regression test.
- [ ] No diagnostic suppression or gate change was self-authorized. Any exception is maintainer-approved and in a separate PR.
- [ ] No credentials, tokens, account data, local absolute paths, or references to local-only artifacts are included.
- [ ] `bash scripts/check-public-content.sh` was run on this body and any new published text.
