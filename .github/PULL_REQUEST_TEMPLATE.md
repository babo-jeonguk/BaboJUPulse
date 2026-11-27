Closes #

## Summary

<!-- Use the smallest representation that makes the change clear: pseudocode, call tree, component tree, shallow file tree, diff sketch, Mermaid, control/data flow, or a short paragraph for a trivial change. Do not repeat the implementation details here. -->

```text
<smallest sufficient representation>
```

## Acceptance criteria coverage

<!-- Mark each criterion satisfied, not applicable, or unverified. Do not invent evidence. -->

| Criterion | Status | Evidence |
| --- | --- | --- |
|  |  |  |

## Implementation changes

<!-- Describe the important code, test, documentation, or configuration changes. Do not duplicate the Summary. -->

## Review and final head

- **Reviewed implementation commit:** `<full SHA>`
- **Final PR head:** `<full SHA>`
- **Review outcome:** Approved / Changes requested / Not yet reviewed
- **Review report:** <link to PR review or summarize the template fields>
- **Blocking findings:** None / list each finding ID and its resolution
- **Non-blocking findings:** None / list each finding ID and its disposition
- **Documentation-only delta after approval:** None / `<approved SHA>..<final SHA>` and changed files
- **Documentation validation:** `bash scripts/check-documentation.sh` / CI run / not applicable
- **Reason independent re-review was not required:** None / explain why the complete delta contains no production code, executable configuration, dependency, test, quality-gate, or substantive policy change

## Validation

<!-- Use actual commands or CI runs. State "not applicable" or "unverified" explicitly. -->

| Check | Command or CI run | Result |
| --- | --- | --- |
| Restore | `dotnet restore BaboJUPulse.slnx` |  |
| Format | `dotnet format BaboJUPulse.slnx --verify-no-changes --no-restore` |  |
| Build | `dotnet build BaboJUPulse.slnx -c Release --no-restore -warnaserror` |  |
| Tests | `dotnet test BaboJUPulse.slnx -c Release --no-build` |  |
| Repository policy | `dotnet test ... --filter "Category=RepositoryPolicy"` |  |
| Documentation | `bash scripts/test-check-documentation.sh` and `bash scripts/check-documentation.sh` |  |
| Public content | `bash scripts/test-public-content.sh` and `bash scripts/check-public-content.sh --tracked` |  |
| Workflow scripts | `bash scripts/check-workflow-shell.sh` and `bash scripts/test-workflow.sh` |  |

- **Not applicable:**
- **Unverified:** Include Windows runtime behavior that was not exercised.
- **Known limitations:** Include constraints, deferred work, or behavior that remains unsupported.

## Documentation review

- **Inspected:**
- **Updated:**
- **No changes needed:**
- **Remaining concerns:**

## Merge Danger

- **Door:** Two-way / One-way
- **Reason:**
- **Blast radius:**
- **Failure scenarios:**
- **Mitigation:**
- **Rollback or recovery:**
- **Maintainer decision required:** Yes / No

<!-- Keep a two-way-door assessment proportionate. For a one-way door, identify the irreversible consequence, explain why a Git revert is insufficient, and document safeguards or migration steps. -->

## Checklist

- [ ] The pull request is linked to the issue and contains no unrequested scope.
- [ ] Every acceptance criterion is addressed or explicitly marked not applicable or unverified.
- [ ] The reviewed implementation commit and final PR head are recorded accurately.
- [ ] Any documentation-only delta was verified from the complete approved-to-final diff and contains no production code, executable configuration, dependency, test, quality-gate, or substantive policy change.
- [ ] Validation results above are actual results for the final head.
- [ ] Documentation validation passed for the final head when documentation changed.
- [ ] The documentation freshness review is recorded (inspected, updated, unchanged, remaining concerns).
- [ ] The Merge Danger assessment is proportionate and records any required maintainer decision.
- [ ] Behavior changes have tests; a bug fix has a regression test.
- [ ] Domain terminology and relationships match `GLOSSARY.md`, or an unresolved conflict is recorded.
- [ ] No diagnostic suppression or quality-gate change was self-authorized. Any approved exception is in a separate PR.
- [ ] No credentials, tokens, account data, local absolute paths, workspace identifiers, session data, or references to local-only artifacts are included.
- [ ] The review record is understandable without a local report or inaccessible artifact.
- [ ] `bash scripts/check-public-content.sh` was run on this title and body.
