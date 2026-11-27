Closes #

## Summary and rationale

<!-- What changed, why, and which issue requirement does it satisfy? -->

## Acceptance criteria coverage

<!-- Mark each criterion satisfied, not applicable, or unverified. Do not invent evidence. -->

| Criterion | Status | Evidence |
| --- | --- | --- |
|  |  |  |

## Implementation changes

<!-- Describe the important code, test, documentation, or configuration changes. -->

## Review

- **Reviewed commit:** `<full SHA>`
- **Outcome:** Approved / Changes requested / Not yet reviewed
- **Blocking findings:** None / list each finding and its resolution

## Validation

<!-- Use actual commands or CI runs. State "not applicable" or "unverified" explicitly. -->

| Check | Command or CI run | Result |
| --- | --- | --- |
| Restore | `dotnet restore BaboJUPulse.slnx` |  |
| Format | `dotnet format BaboJUPulse.slnx --verify-no-changes --no-restore` |  |
| Build | `dotnet build BaboJUPulse.slnx -c Release --no-restore -warnaserror` |  |
| Tests | `dotnet test BaboJUPulse.slnx -c Release --no-build` |  |
| Repository policy | `dotnet test ... --filter "Category=RepositoryPolicy"` |  |
| Public content | `bash scripts/test-public-content.sh` and `bash scripts/check-public-content.sh --tracked` |  |

- **Not applicable:**
- **Unverified:** Include Windows runtime behavior that was not exercised.

## Risk and rollback

- **Blast radius:**
- **Rollback:**

## Checklist

- [ ] The pull request is linked to the issue and contains no unrequested scope.
- [ ] Every acceptance criterion is addressed or explicitly marked not applicable or unverified.
- [ ] The reviewed commit SHA matches the current head, or a later review covers the difference.
- [ ] Validation results above are actual results for the current head.
- [ ] Behavior changes have tests; a bug fix has a regression test.
- [ ] No diagnostic suppression or quality-gate change was self-authorized. Any approved exception is in a separate PR.
- [ ] No credentials, tokens, account data, local absolute paths, or references to local-only artifacts are included.
- [ ] `bash scripts/check-public-content.sh` was run on this title and body.
