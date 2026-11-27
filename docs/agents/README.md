# Agent operations

This directory holds operating procedures that agents load on demand. [AGENTS.md](../../AGENTS.md) is the entry point and routes here. Start with [Development workflow](development-workflow.md) for the overall sequence; load only the stage document for the current task.

## Workflow

| Document | Owns | Does not own |
| --- | --- | --- |
| [Development workflow](development-workflow.md) | Overall stage sequence, transition rules, review-loop limits, and escalation | Detailed stage procedure, code rules, commands |
| [Domain guidance](domain.md) | Discovering, using, and maintaining product terminology; conflict and escalation rules | The vocabulary itself, product scope, architecture decisions |
| [Issue tracker](issue-tracker.md) | Issue creation, triage operations, readiness, and closure | Label definitions, publication policy |
| [Triage labels](triage-labels.md) | Label meanings, category cardinality, and label synchronization | Readiness gate, issue procedure, publication policy |
| [Workspace](workspace.md) | Worktree, branch, base, and workspace verification | Build commands, issue readiness, merge cleanup |
| [Implementation](implementation.md) | Slice-based implementation, optional sequential delegation, and handoff to review | Coding rules, test rules, verification policy, commands |
| [Code review](code-review.md) | Independent review scope, finding format, and approval SHA | Remediation procedure, coding rules, output template details |
| [Review report template](templates/review-report.md) | Review output format and stable finding identifiers | Review criteria, approval policy |
| [Review remediation](review-remediation.md) | Finding disposition, correction, and re-review | Review criteria, escalation limits, gate policy |
| [Pull request](pull-request.md) | PR template use, Summary and Merge Danger, evidence, publication checks, and CI verification | Merge procedure, publication policy details |
| [PR merge](pr-merge.md) | Merge preconditions, documentation freshness, post-merge verification, and workspace cleanup | Branch protection settings, PR preparation |

## Policy and reference

| Document | Owns | Does not own |
| --- | --- | --- |
| [GitHub operations](github-operations.md) | Issue, PR, comment, review, commit, publication, and local-only artifact rules; repository settings and merge policy | Code quality, analyzer operation, issue triage stages |
| [Quality gates](quality-gates.md) | Required verification, documentation validation, static-analysis enforcement, suppression approval, gate integrity, CI enforcement, and limitations | Coding rules, GitHub workflow |
| [Coding standards](../../CODING_STANDARDS.md) | Acceptable code, architectural constraints, and prohibited implementation practices | Commands, suppression procedure |
| [GLOSSARY](../../GLOSSARY.md) | Authoritative product-domain vocabulary | Architecture, implementation, behavior |
| [Development](../development.md) | Environment setup, build/run commands, test execution, workflow scripts, and troubleshooting | GitHub policy, gate policy |
| [Architecture](../architecture.md), [ADRs](../adr/) | Boundaries, decisions, and rationale | Operating procedures |
| [Contributing](../../CONTRIBUTING.md) | External contributor entry point and requirements | Internal agent orchestration |

## Reading rule

Read [Development workflow](development-workflow.md) for the sequence, then the one stage document for the task. Load [Domain guidance](domain.md) when terminology affects the work, and use [GLOSSARY.md](../../GLOSSARY.md) as the vocabulary. Do not duplicate a rule across documents: link to the authoritative source above. External contributors do not need this directory; send them to [CONTRIBUTING.md](../../CONTRIBUTING.md).
