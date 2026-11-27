# Quality gates

Authoritative for verification, static-analysis enforcement, suppression approval, and gate integrity. Code rules live in [CODING_STANDARDS.md](../../CODING_STANDARDS.md); environment and command definitions live in [Development](../development.md#quality-gates) and [Development tests](../development.md#tests).

## Required gates

The CI workflow is [`.github/workflows/ci.yml`](../../.github/workflows/ci.yml). It runs on `windows-latest` and is the required `build` check.

| Gate | Enforces |
| --- | --- |
| Restore | Pinned NuGet source and transitive audit |
| Format | `.editorconfig` formatting and style |
| Build | Compiler, nullable analysis, warnings-as-errors, .NET analyzers, BannedApiAnalyzers |
| Test | Behavior tests and repository-invariant tests |
| Repository policy | Syntax- and configuration-aware checks described below |
| Public content | Publication policy and local-reference checks |
| CodeQL | C# security analysis; advisory, not required |
| Dependency review | New dependency vulnerabilities and licenses; advisory, not required |

The exact quality-gate commands are in [Development](../development.md#quality-gates); the repository-policy and public-content commands are in [Development tests](../development.md#tests). Do not duplicate them in new documents.

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
| CI policy | Mandatory steps exist, are unconditional, are not `continue-on-error`, and do not contain `|| true`, `|| exit 0`, `set +e`, or `exit 0`; required commands and the policy step are present; no-test runs fail; checkout uses full history; PR edits rerun validation |
| Documentation links | Relative links resolve, do not target Git-ignored paths, and do not use local absolute paths |
| Public content | Concrete local-only artifact references, local absolute paths, and obvious secrets are rejected; bare `.scratch/` convention mentions are allowed; failure output is limited to a rule identifier, safe file label, and line number |

The null-forgiving policy test matches the Roslyn `SuppressNullableWarningExpression` syntax node. A self-written justification comment has no effect. Fix the invariant with explicit null checks, sound type modeling, or another non-suppressing implementation; a genuine exception is a maintainer-approved policy change, not an agent-authored annotation.

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
| Merge strategy, visibility, license, approval requirements | Maintainer only |
| Public-content policy exception | Maintainer only; do not self-authorize |

## Known limitations

- CI checks a PR after its title, body, and commits are visible. It cannot prevent initial disclosure in a PR. Issue and comment publication has no server-side pre-publication guard.
- Adding `edited` to the PR trigger revalidates a changed title or body, but it does not validate the text before the edit becomes visible.
- The public-content checker is pattern-based. It can miss unusual references and can reject benign text. Sanitized summaries are allowed. Because output is redacted, use the reported rule and line to locate a match locally.
- The checker scans text. `--tracked` skips binary files, and `--files` fails closed when grep cannot report a line number. Review binary additions manually.
- Secret scanning and push protection cover known secret formats, not local paths or private context.
- CodeQL and dependency review are advisory; only `build` is required by branch protection.
- The local commit hook is bypassable and does not apply to contributors who did not run setup.
- Architecture dependency tests and provider-boundary tests are deferred until separate assemblies or namespaces exist. See [ADR-0002](../adr/0002-static-analysis-and-architecture-enforcement.md).
- The null-forgiving check rejects the operator; it does not prove that every other nullable annotation or nullability contract is honest.
- An agent that can edit both code and validation can weaken a repository-controlled check. Maintainer review is required for any change to `.editorconfig`, `Directory.Build.props`, `BannedSymbols.txt`, `CodeMetricsConfig.txt`, the policy tests, `scripts/check-public-content.sh`, or `.github/workflows/ci.yml`.
