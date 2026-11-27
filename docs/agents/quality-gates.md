# Quality gates

Authoritative for verification, static-analysis enforcement, suppression approval, and gate integrity. Code rules live in [CODING_STANDARDS.md](../../CODING_STANDARDS.md); environment and command definitions live in [Development](../development.md#quality-gates), [Development tests](../development.md#tests), and [Development documentation validation](../development.md#documentation-validation).

## Required gates

The required CI workflow is [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml). It runs on `windows-latest` and is the required `build` check. A separate [documentation workflow](../../.github/workflows/docs.yml) runs lightweight documentation validation on every pull request and push to `main`; it is not a branch-protection required check by default.

| Gate | Enforces |
| --- | --- |
| Restore | Pinned NuGet source and transitive audit |
| Format | `.editorconfig` formatting and style |
| Build | Compiler, nullable analysis, warnings-as-errors, .NET analyzers, BannedApiAnalyzers |
| Test | Behavior tests and repository-invariant tests |
| Repository policy | Syntax- and configuration-aware checks described below |
| Documentation | Relative links, heading fragments, ignored and local-only targets, table shape, fence closure, and public-content policy |
| Public content | Publication policy and local-reference checks |
| Workflow scripts | ShellCheck static analysis and synthetic Git repositories with stubbed GitHub/Paseo commands for workspace, validation, merge, and cleanup behavior |
| CodeQL | C# security analysis; advisory, not required |
| Dependency review | New dependency vulnerabilities and licenses; advisory, not required |

The exact quality-gate commands are in [Development](../development.md#quality-gates); the repository-policy and public-content commands are in [Development tests](../development.md#tests); the documentation commands are in [Development documentation validation](../development.md#documentation-validation). Do not duplicate them in new documents.

## Workflow automation

[`scripts/workflow/`](../../scripts/workflow/) is the deterministic entry point for workspace preparation, validation, merge inspection and execution, and cleanup. It sequences the existing gates; it does not replace or weaken them.

- `validate.sh full` runs restore, format, build, tests, repository-policy tests, documentation, public content, ShellCheck, and workflow-script tests.
- `validate.sh targeted` runs only the named checks after a slice. `--workflow` runs ShellCheck and the workflow-script tests.
- `validate.sh docs` runs documentation and public-content checks only.
- `validate.sh range` verifies and prints a review range.
- `merge.sh` separates read-only inspection from execution and requires the explicit verified SHA. It does not decide whether a review finding is acceptable.
- `cleanup.sh` is idempotent and retains anything it cannot remove safely. Failed Git state queries and fork or unverified head repositories retain local resources.

`scripts/check-workflow-shell.sh` runs ShellCheck over `scripts/workflow/*.sh` and `scripts/test-workflow.sh` with source following and the optional `check-extra-masked-returns` check for masked exit statuses (SC2312). SC2310 was evaluated and is intentionally not enabled because the workflow helpers are invoked in conditions and return explicit statuses. `scripts/test-workflow.sh` supplies synthetic Git repositories and stubbed GitHub/Paseo commands. Both run locally and in the documentation workflow. A change to a workflow script needs its test coverage and review; do not treat the script's convenience as a reason to skip the underlying gate. Missing `jq` or ShellCheck is an explicit dependency failure, not a skipped check.

A validation result applies only to the commit it names. `validate.sh` exits with status 3 when HEAD or the working tree changes during the run, because the evidence may no longer describe the inspected state. A merge script result is mechanical evidence, not an architecture approval or a substitute for authorized engineering judgment.


## Enforcement coverage

| Area | Automated now | Remaining manual or deferred |
| --- | --- | --- |
| Formatting, style, naming | `dotnet format` and IDE analyzers | Judgment about whether a name or layout is clear |
| Nullability and type safety | Compiler nullable analysis and the prohibition on null-forgiving operators | Avoiding `dynamic`, reflection, and dishonest annotations |
| Blocking waits and selected unsafe APIs | `BannedApiAnalyzers` with `BannedSymbols.txt` | Synchronous I/O that is not in the banned list |
| Async correctness | `CA1849`, `CA2012`, `CA2016`, banned blocking waits | `async void`, fire-and-forget, and ownership of background work |
| Resource ownership | `CA1001`, `CA1063`, `CA1816`, `CA2000`, `CA2213` | Event unsubscription and native handle lifetime |
| Exception handling | `CA1031`, `CA2201` | Error-message quality and the correct boundary for a failure |
| Complexity and coupling | `CA1502` and configured `CA1506` thresholds | God classes, method length, and whether an abstraction earns its keep |
| Architecture boundaries and cycles | Repository configuration tests; compiler rejects project-reference cycles | Namespace cycles and domain/UI/provider dependency direction until separate assemblies exist; then ArchUnitNET |
| Duplication | None | Review; introduce a focused analyzer only after a recurring failure |
| Workflow shell correctness | ShellCheck with source following and SC2312 masked-status checks; SC2310 evaluated but not enabled | Whether a script's external command contract and filesystem assumptions are correct |
| Security | CodeQL, NuGet audit, dependency review, secret scanning, banned TLS/process APIs | Threat modeling, credential handling, and data-flow review |

The table records coverage, not permission to ignore a manual rule.

## Suppression policy

There are three different actions. Do not treat them as the same.

### Narrow, justified suppression

A narrow suppression is **not self-authorized**. It requires maintainer approval. The conditions below describe an approvable exception, not a checklist an implementation agent may satisfy alone.

A line-level or member-level suppression is acceptable only when all of these are true:

1. The diagnostic is a genuine false positive for this exact code, not an inconvenience.
2. The suppression is the narrowest form available.
3. A comment states why the code is safe.
4. The PR description records the diagnostic ID, the scope, and the alternative considered.
5. The suppression does not hide a real defect, a failing test, or an unhandled resource leak.

A narrow suppression for a documented false positive is reviewed like any other code. It is not a quality-gate change.

### Project-wide configuration change

Changing `.editorconfig`, `Directory.Build.props`, `BannedSymbols.txt`, an analyzer package, or a CI gate changes the rules for everyone. It needs its own PR with:

- The diagnostic or gate being changed and the concrete problem it causes.
- Evidence that the change does not reduce coverage for an existing class of defect.
- The scope of the change and the files affected.

Strengthening a gate is normal maintenance. Weakening it is not.

### Weakening a quality gate

Removing a banned symbol, lowering a severity, disabling an analyzer, adding project-wide `NoWarn`, disabling nullable, lowering `AnalysisLevel`, excluding files from analysis, or removing a CI step is a weakening. It requires:

- A separate PR, never bundled with a feature or bug fix.
- An ADR that records why the gate is wrong or impractical, what replaces it, and what risk is accepted.
- Maintainer approval.

### No self-authorized suppressions

The agent that introduces a violation must not declare its own violation acceptable.

- A comment, a `SuppressMessage` justification, a passing test, or an agent-generated review does **not** authorize a suppression.
- A comment claiming that a blocking call runs outside the UI thread, that a broad exception handler is needed for stability, or that a diagnostic is "known safe" is not evidence.
- If an analyzer appears to report a genuine false positive, stop and provide reproducible evidence: the diagnostic, the exact code, why the analyzer is wrong, and the alternative considered.
- Request explicit maintainer approval. Approval must come from the maintainer, not another coding agent.
- Approved exceptions must be narrowly scoped, auditable, and supported by evidence.
- Suppressing a warning merely to pass CI is prohibited.

No approved-exception framework exists yet. Do not invent one to land a change. If a real approved false positive appears, add the smallest maintainer-controlled mechanism that cannot be self-authorized by an implementation agent.

## Automated integrity checks

These checks run as tests and as a dedicated `Category=RepositoryPolicy` CI step. They cover active configuration, not merely text presence.

| Check | Detects |
| --- | --- |
| Source policy | `#pragma warning disable`, `#nullable disable`, `SuppressMessage`, and `UnconditionalSuppressMessage` in tracked handwritten `.cs` files; tracked generated-file suffixes and `GeneratedCode` markers are rejected |
| Null-forgiving policy | Every postfix `!` null-forgiving operator in tracked handwritten C#, including inactive preprocessor branches; a comment is not an exception |
| Project policy | `NoWarn`, `WarningsNotAsErrors`, false `TreatWarningsAsErrors`/`EnableNETAnalyzers`/`RunAnalyzers*`/`CodeAnalysisTreatWarningsAsErrors`/`EnableDefaultCompileItems`, lowered `AnalysisLevel`, `AnalysisMode=None/Minimum`, disabled nullable, `Compile Remove`, `AutoGen` source exclusion, or `DefaultItemExcludes` for C# |
| Nested configuration | Nested `.editorconfig`, `.globalconfig`, `Directory.Build.props`, or `Directory.Build.targets` overrides |
| Banned symbols | Every active entry is required; removing or commenting out any entry fails the policy test |
| Coupling thresholds | `CA1506(Type) <= 40` and `CA1506(Method) <= 20` |
| CI policy | Mandatory steps exist, are unconditional, are not `continue-on-error`, and do not contain `\|\| true`, `\|\| exit 0`, `set +e`, or `exit 0`; required commands and the policy step are present; no-test runs fail; checkout uses full history; PR edits rerun validation |
| Documentation | Relative links and heading fragments resolve, Git-ignored and local absolute targets are rejected, table columns and fenced-code closure are checked, and public-content rules are applied |
| Public content | Concrete local-only artifact references, local absolute paths, and obvious secrets are rejected; bare `.scratch/` convention mentions are allowed; failure output is limited to a rule identifier, safe file label, and line number |

The null-forgiving policy test matches the Roslyn `SuppressNullableWarningExpression` syntax node. A self-written justification comment has no effect. Fix the invariant with explicit null checks, sound type modeling, or another non-suppressing implementation; a genuine exception is a maintainer-approved policy change, not an agent-authored annotation.

## Documentation validation

[`scripts/check-documentation.sh`](../../scripts/check-documentation.sh) is the single local and CI implementation of the documentation checks. The repository-policy test invokes that script rather than maintaining a second link checker. `scripts/test-check-documentation.sh` supplies synthetic invalid and valid documents.

The checker validates:

- Relative links resolve to a tracked or untracked repository file or directory.
- Heading fragments resolve to a generated GitHub-style heading slug.
- Links do not target Git-ignored paths or leave the repository.
- Links do not use local absolute paths or file URLs.
- Table rows have the same column count as their header.
- Fenced code blocks are closed.
- Documentation files satisfy the public-content policy, using the existing checker rather than a second pattern set.

The [documentation workflow](../../.github/workflows/docs.yml) runs the checker, its synthetic tests, the public-content tests, ShellCheck over the scoped workflow scripts, and the workflow-script tests on every pull request and push to `main`. It installs the pinned ShellCheck 0.11.0 release and requires `jq`; a missing dependency fails the job explicitly. It has no `paths` or `paths-ignore` filter, so it cannot be skipped into a permanently pending state. The existing `build` workflow remains the only branch-protection required check; the merge procedure requires the documentation result on the final head. Adding the documentation job to branch protection, or removing the required `build` coverage, needs explicit maintainer authorization.

A documentation-only commit after review does not change CI scope. It still triggers the full required `build` check and the documentation workflow. The narrow review exception in [Code review](code-review.md#7-documentation-only-follow-up-after-approval) changes review effort, not the validation that must pass on the final head.

External links are not checked. Rate limits, authentication requirements, temporary failures, and site restrictions make them unreliable merge blockers. Markdown rendering style is not broadly linted, and Mermaid source is not rendered; the checker verifies fence closure and repository structure instead of imposing a formatting rule set.

`markdownlint-cli2` and Mermaid rendering tools were evaluated. They were not adopted for this path because the repository has no Node.js runtime requirement, the default rule set would add broad formatting policy, and Mermaid rendering needs a browser-scale dependency. Reconsider a dedicated linter only when a concrete documentation defect class justifies the added dependency and maintenance.

## Public-content coverage and limits

The checker is a pattern-based pre-publication control, not a complete data-loss-prevention system.

- It rejects concrete local-only artifact paths, common local absolute paths (including mounted Windows user paths and WSL UNC paths), file URLs, and obvious credential and private-key formats.
- A bare `.scratch/` convention mention is allowed because contributors need to document the local workspace. A reference to a particular artifact below it is rejected.
- Failure output is deliberately redacted: rule identifier, safe file label, and line number only. The matching text is never printed, so a raw credential cannot leak while the checker reports it.
- The local script is the practical pre-publication control for issue, PR, comment, and review text. Run it on the exact text before posting.
- CI rechecks the PR title and body, PR commit messages, and all tracked text files. The `pull_request` trigger includes `edited`, so a title or body change is revalidated. Keep the workflow on `pull_request` with read-only permissions; do not switch to `pull_request_target` to inspect untrusted PR text.
- CI runs after the content is visible. It is post-publication detection, not prevention of initial disclosure. Editing or deleting content does not remove every copy or cache.

## Enforcement layers and trust boundary

| Layer | Scope | What it guarantees |
| --- | --- | --- |
| Local `commit-msg` hook | Clones that configured `core.hooksPath` | Commit format, subject length, and public-content check |
| Agent instructions | Agents working in the repository | Guidance and review expectations; not enforcement |
| CI `build` | Every push to `main`, every PR (including title/body edits), manual runs | Restore audit, formatting, build, tests, policy tests, public-content checks |
| CI `documentation` | Every push to `main`, every PR, manual runs | Documentation links, fragments, local-only targets, table shape, fence closure, and public-content checks |
| Branch protection | Server-side on `main` | PR required, `build` required, up-to-date branch, resolved conversations, no force push or deletion, admins included |
| CodeQL / dependency review | CI checks | Advisory security and dependency signals; not required |
| Secret scanning / push protection | Server-side | Known secret formats in commits and pushes |

A repository-controlled guard is **not tamper-proof**. An agent with permission to modify both the implementation and the guard can weaken both. Branch protection, maintainer review, and the separation between implementation and approval are the trust boundary. Do not claim the guard is impossible to bypass.

## Required approvals

| Change | Approval and trust boundary |
| --- | --- |
| Narrow suppression for a genuine false positive | Maintainer only, after reproducible evidence |
| Project-wide analyzer or quality-gate change | Maintainer; separate PR |
| Weakening a quality gate | Maintainer; separate PR and ADR |
| Documentation validation policy or required-check change | Maintainer only; do not self-authorize |
| Merge strategy, visibility, license, approval requirements | Maintainer only |
| Public-content policy exception | Maintainer only; do not self-authorize |

## Known limitations

- CI checks a PR after its title, body, and commits are visible. It cannot prevent initial disclosure in a PR. Issue and comment publication has no server-side pre-publication guard.
- Adding `edited` to the PR trigger revalidates a changed title or body, but it does not validate the text before the edit becomes visible.
- The public-content checker is pattern-based. It can miss unusual references and can reject benign text. Sanitized summaries are allowed. Because output is redacted, use the reported rule and line to locate a match locally.
- The checker scans text. `--tracked` skips binary files, and `--files` fails closed when grep cannot report a line number. Review binary additions manually.
- Secret scanning and push protection cover known secret formats, not local paths or private context.
- CodeQL and dependency review are advisory; only `build` is required by branch protection.
- The `documentation` workflow is not a branch-protection required check. The merge procedure requires its result, but a repository setting change would be needed to enforce it server-side.
- The documentation checker does not validate external link reachability, Mermaid rendering, or general Markdown formatting style. It validates repository structure and the checks listed above.
- The checker resolves inline links and images. Reference-style link definitions are not currently resolved; prefer inline links or verify them manually.
- The table, link, and anchor checks skip four-space-indented code blocks as a heuristic. A malformed table, broken link, or anchor nested four spaces under a list item may be skipped; verify that case manually.
- Tab-indented code blocks are not covered by the four-space heuristic. A fake link or malformed table inside a tab-indented block can be reported; normalize tabs or verify that case manually.
- Prose local-path detection relies on the public-content checker's supported patterns. Link targets are rejected separately.
- The local commit hook is bypassable and does not apply to contributors who did not run setup.
- Architecture dependency tests and provider-boundary tests are deferred until separate assemblies or namespaces exist. See [ADR-0002](../adr/0002-static-analysis-and-architecture-enforcement.md).
- The null-forgiving check rejects the operator; it does not prove that every other nullable annotation or nullability contract is honest.
- An agent that can edit both code and validation can weaken a repository-controlled check. Maintainer review is required for any change to `.editorconfig`, `Directory.Build.props`, `BannedSymbols.txt`, `CodeMetricsConfig.txt`, the policy tests, `scripts/check-public-content.sh`, `scripts/check-documentation.sh`, or the workflows under `.github/workflows/`.
- The workflow scripts are mechanical aids. They do not decide whether an architecture change is acceptable, whether a review finding is valid, or whether a documentation-only delta is substantive.
- ShellCheck covers `scripts/workflow/*.sh` and `scripts/test-workflow.sh` only. It does not lint the documentation, public-content, setup, or other repository scripts.
- Workflow Paseo parsing requires `jq`, and workflow linting requires ShellCheck. Missing dependencies fail explicitly; they are not silently skipped.
- `merge.sh` reads the PR head and check results at the moment it runs. A head change after inspection blocks the merge, but the script cannot prevent a concurrent GitHub-side change after it passes the verified SHA.
- `cleanup.sh` relies on the installed Paseo archive behavior. Verify `paseo --version` and the archive result when the version changes.
