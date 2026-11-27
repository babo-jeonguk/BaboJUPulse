# Agent operations

This directory holds operating procedures that agents load on demand. [AGENTS.md](../../AGENTS.md) is the entry point and routes here.

| Document | Owns | Does not own |
| --- | --- | --- |
| [GitHub operations](github-operations.md) | Issue, PR, comment, review, commit, publication, and local-only artifact rules; repository settings and merge policy | Code quality, analyzer operation |
| [Quality gates](quality-gates.md) | Required verification, static-analysis enforcement, suppression approval, gate integrity, CI enforcement, and limitations | Coding rules, GitHub workflow |
| [Coding standards](../../CODING_STANDARDS.md) | Acceptable code, architectural constraints, and prohibited implementation practices | Commands, suppression procedure |
| [Development](../development.md) | Environment setup, build/run commands, test execution, and troubleshooting | GitHub policy, gate policy |
| [Architecture](../architecture.md), [ADRs](../adr/) | Boundaries, decisions, and rationale | Operating procedures |

## Not defined yet

Planning, implementation, review, remediation, orchestration, and handoff procedures are not defined. Verification policy is in [quality-gates](quality-gates.md); task-specific verification steps will be added when that workflow is decided. Add a document only after its procedure is decided; do not create placeholders.
