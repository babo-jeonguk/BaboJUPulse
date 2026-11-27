# Agent operations

This directory holds operating procedures that agents load on demand. [AGENTS.md](../../AGENTS.md) is the entry point and routes here. Start with [Development workflow](development-workflow.md) for the overall sequence; load only the stage document for the current task.

## Workflow

| Document | Owns | Does not own |
| --- | --- | --- |
| [Development workflow](development-workflow.md) | Overall stage sequence, transition rules, review-loop limits, and escalation | Detailed stage procedure, code rules, commands |
| [Issue tracker](issue-tracker.md) | Issue creation, triage operations, readiness, and closure | Label definitions, publication policy |
| [Triage labels](triage-labels.md) | Label meanings, category cardinality, readiness labels, and label synchronization | Issue procedure, GitHub publication policy |
| [Workspace](workspace.md) | Worktree, branch, base, and workspace verification | Build commands, issue readiness, merge cleanup |
| [Implementation](implementation.md) | Slice-based implementation, test expectations, and handoff to review | Coding rules, verification policy, commands |
| [Code review](code-review.md) | Independent review scope, finding format, and approval SHA | Remediation procedure, coding rules |
| [Review remediation](review-remediation.md) | Finding disposition, correction, re-review, and loop escalation | Review criteria, gate policy |
| [Pull request](pull-request.md) | PR template use, evidence, publication checks, and CI verification | Merge procedure, publication policy details |
| [PR merge](pr-merge.md) | Merge preconditions, post-merge verification, and workspace cleanup | Branch protection settings, PR preparation |

## Policy and reference

| Document | Owns | Does not own |
| --- | --- | --- |
| [GitHub operations](github-operations.md) | Issue, PR, comment, review, commit, publication, and local-only artifact rules; repository settings and merge policy | Code quality, analyzer operation, issue triage stages |
| [Quality gates](quality-gates.md) | Required verification, static-analysis enforcement, suppression approval, gate integrity, CI enforcement, and limitations | Coding rules, GitHub workflow |
| [Coding standards](../../CODING_STANDARDS.md) | Acceptable code, architectural constraints, and prohibited implementation practices | Commands, suppression procedure |
| [Development](../development.md) | Environment setup, build/run commands, test execution, and troubleshooting | GitHub policy, gate policy |
| [Architecture](../architecture.md), [ADRs](../adr/) | Boundaries, decisions, and rationale | Operating procedures |
| [Contributing](../../CONTRIBUTING.md) | External contributor entry point and requirements | Internal agent orchestration |

## Reading rule

Read [Development workflow](development-workflow.md) for the sequence, then the one stage document for the task. Do not duplicate a rule across documents: link to the authoritative source above. External contributors do not need this directory; send them to [CONTRIBUTING.md](../../CONTRIBUTING.md).
