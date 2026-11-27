# Documentation map

Each document has one authoritative responsibility.

| Document | Responsible for |
| --- | --- |
| [README](../README.md) | User-facing overview, requirements, and build entry point |
| [CONTRIBUTING](../CONTRIBUTING.md) | External contributor path, requirements, and review expectations |
| [AGENTS](../AGENTS.md) | Agent entry point: invariants and task routing |
| [Product scope](product-scope.md) | Intended capabilities, constraints, and non-goals |
| [Architecture](architecture.md) | Current shape, boundaries, and open decisions |
| [Development](development.md) | Setup, build/run, test execution, documentation validation commands, and troubleshooting |
| [Coding standards](../CODING_STANDARDS.md) | Acceptable code, architectural constraints, and prohibited practices |
| [Agent operations](agents/README.md) | Map of agent operating procedures |
| [Development workflow](agents/development-workflow.md) | Overall workflow sequence, stage transitions, and escalation |
| [Issue tracker](agents/issue-tracker.md) | Issue creation, triage, readiness, and closure |
| [Triage labels](agents/triage-labels.md) | Label meanings, category cardinality, and label synchronization |
| [Workspace](agents/workspace.md) | Isolated worktree, branch, and base preparation |
| [Implementation](agents/implementation.md) | Slice-based implementation and handoff to review |
| [Code review](agents/code-review.md) | Independent review criteria, findings, and approval SHA |
| [Review remediation](agents/review-remediation.md) | Finding correction and re-review |
| [Pull request](agents/pull-request.md) | PR template, Summary, Merge Danger, evidence, publication checks, and CI |
| [PR merge](agents/pr-merge.md) | Merge preconditions, documentation freshness, post-merge verification, and cleanup |
| [GitHub operations](agents/github-operations.md) | Publication, local-only artifacts, and repository settings |
| [Quality gates](agents/quality-gates.md) | Verification, documentation validation, analyzer enforcement, suppressions, and limitations |
| [ADRs](adr/) | Accepted decisions and their rationale |
| [Security](../SECURITY.md) | Vulnerability reporting and secret handling |

## Reading rule

Start at [AGENTS.md](../AGENTS.md) and read only the routed document for the current task. `docs/agents/` holds operating procedures; `CODING_STANDARDS.md` defines acceptable code; `docs/development.md` defines environment and commands; `docs/architecture.md` and the ADRs explain boundaries and decisions. External contributors start at [CONTRIBUTING.md](../CONTRIBUTING.md). Do not duplicate a rule across documents.
