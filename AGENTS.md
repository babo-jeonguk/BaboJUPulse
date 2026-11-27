# AGENTS.md

BaboJUPulse is a Windows tray utility for system metrics and AI coding subscription quotas. The taskbar and tray are the product UI.

## Invariants

- No standalone main window, dashboard, or cross-platform UI. Do not add one without an explicit product decision.
- Do not assume a provider, GPU, sensor, or quota field is supported. Missing capabilities stay explicit.
- Do not add product features unless the task asks for them. Product scope is intent, not implemented behavior.
- Never publish credentials, tokens, account data, local absolute paths, or references to Git-ignored working artifacts. Published content must stand on tracked files, issues/PRs, commits, CI, or public references.
- Do not suppress a static-analysis diagnostic, weaken a quality gate, or change analyzer configuration independently. Stop and request maintainer approval with reproducible evidence; follow [quality gates](docs/agents/quality-gates.md).
- Do not use the null-forgiving operator (`!`) or a self-written comment to silence nullability analysis. Fix the invariant with explicit null checks or sound type modeling; a genuine exception needs maintainer approval.
- Do not claim a command, test, CI run, or Windows behavior passed unless you actually verified it.

## Routing

Read the linked document before the matching action. Do not load every document.

| Task | Authoritative document |
| --- | --- |
| Overall sequence, stage transitions, escalation | [Development workflow](docs/agents/development-workflow.md) |
| Product intent, scope, provider limits | [Product scope](docs/product-scope.md) |
| Architecture boundaries and decisions | [Architecture](docs/architecture.md), [ADRs](docs/adr/) |
| Code rules and prohibited patterns | [Coding standards](CODING_STANDARDS.md) |
| Setup, build, run, tests, troubleshooting | [Development](docs/development.md) |
| Verification, suppressions, analyzer/CI changes | [Quality gates](docs/agents/quality-gates.md) |
| Issue creation, triage, readiness, closure | [Issue tracker](docs/agents/issue-tracker.md), [triage labels](docs/agents/triage-labels.md) |
| Worktree, branch, and base preparation | [Workspace](docs/agents/workspace.md) |
| Slice-based implementation and tests | [Implementation](docs/agents/implementation.md) |
| Independent review and finding records | [Code review](docs/agents/code-review.md) |
| Remediation and re-review | [Review remediation](docs/agents/review-remediation.md) |
| PR preparation, evidence, and CI | [Pull request](docs/agents/pull-request.md) |
| Merge, post-merge verification, cleanup | [PR merge](docs/agents/pr-merge.md) |
| Issues, PRs, comments, commits, publication | [GitHub operations](docs/agents/github-operations.md) |
| External contributor entry point | [Contributing](CONTRIBUTING.md) |
| Documentation map | [Docs](docs/README.md), [agent docs](docs/agents/README.md) |

Before claiming completion, run the verification required by the routed quality-gate document and report what you actually ran.

## Conduct

- Use the model the maintainer names; do not delegate to another model without approval.
- Prefer the smallest change that satisfies the request. Ask before a consequential choice not covered by the repository.
