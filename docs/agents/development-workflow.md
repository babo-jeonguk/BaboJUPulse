# Development workflow

Authoritative for the overall sequence and stage transitions. Detailed stage procedures live in the linked documents. This document does not own coding rules, validation policy, environment commands, architecture decisions, or GitHub publication policy.

## Purpose

Give every change a predictable path from an agreed problem to a reviewed, verified merge. Keep the work small enough to review, keep the specification authoritative, and keep quality gates independent of the implementation agent.

## Applicability

This workflow is for maintainers and coding agents working in this repository. External contributors follow [CONTRIBUTING.md](../../CONTRIBUTING.md) and may use any IDE, editor, or local workflow. Paseo and the internal agent orchestration are conveniences, not contributor requirements.

## Required inputs

- A problem, defect, idea, or research question worth acting on.
- A maintainer decision when the change affects product scope, licensing, repository settings, or a quality gate.
- Access to the target repository and the ability to publish a branch or pull request.

## Stages

| Stage | Procedure | Entry | Required output |
| --- | --- | --- | --- |
| 1. Specification and issue | [Issue tracker](issue-tracker.md), [triage labels](triage-labels.md) | A problem or idea worth acting on | An issue with a clear specification and acceptance criteria, triaged to a ready state |
| 2. Workspace preparation | [Workspace](workspace.md) | A ready issue | One issue-specific worktree and branch based on current `origin/main` |
| 3. Slice-based implementation | [Implementation](implementation.md) | A verified workspace and an unambiguous issue | Commits, tests, and verification evidence for every acceptance criterion |
| 4. Independent review | [Code review](code-review.md) | Complete implementation and evidence | Review decision naming the exact reviewed commit |
| 4a. Remediation | [Review remediation](review-remediation.md) | Blocking review findings | Corrected commits, evidence, and re-review approval |
| 5. Pull request and CI | [Pull request](pull-request.md) | Review approval for the current head commit | A PR with the issue linked, evidence recorded, and required checks passing |
| 6. Merge and cleanup | [PR merge](pr-merge.md) | Satisfied acceptance criteria, resolved findings, green required checks, mergeable branch | Verified merge, closed issue, clean workspace |

## Required outputs

An issue with a specification and acceptance criteria, an isolated branch, reviewed commits, a pull request with evidence, a verified merge, and a cleaned-up workspace. Each stage document defines the specific output for its part of that record.

## Exit criteria

The linked issue is closed with a merge reference or a recorded disposition, the merge result is verified on `main`, required checks passed on the current head, and no unreviewed change or dirty worktree remains.

## Stage-transition rules

1. **Do not implement before the issue is ready.** A bug or feature report is input, not an implementation contract. The issue needs testable acceptance criteria and triage before implementation starts. A maintainer may authorize an urgent exception; record the exception in the issue.
2. **One issue maps to one worktree, one branch, and one pull request by default.** Use one branch per coherent issue. If a change genuinely spans issues, link them and explain the grouping in the issue; do not merge unrelated work to reduce overhead.
3. **Base new work on current `origin/main`.** Verify the repository, branch, and base before editing. Reuse a matching existing workspace rather than creating a duplicate.
4. **Implement in slices, not one unreviewable dump.** Each slice needs a purpose, scope, and verification. Tests are mandatory for behavior changes even though test-driven development is optional.
5. **Run targeted checks after each slice and the full required suite before review.** The commands are in [Development](../development.md#quality-gates). Gate policy is in [Quality gates](quality-gates.md).
6. **Review the actual diff against the issue, in a fresh context, before opening the PR.** A review approval names the exact commit. Changes after that commit require a new review of the affected work.
7. **Do not open a PR with unresolved blocking findings.** Non-blocking recommendations may be recorded as follow-up issues or left for maintainer judgment.
8. **A PR is not approved because an earlier commit passed.** If the head commit changes, the review and the affected verification must be repeated.
9. **Merge only when the current head satisfies the acceptance criteria, blocking findings are resolved, required CI checks pass, conversations are resolved, and the branch is mergeable.** Preserve the repository's merge strategy and branch protection.
10. **Do not treat agent instructions or local hooks as server-side enforcement.** Branch protection, CI, and maintainer review are the trust boundary.

## Review and remediation loop

- The implementation agent requests review with the issue, base and head SHAs, diff, and verification evidence.
- The reviewer records every actionable finding with severity, location, evidence, the affected requirement or rule, and the expected correction or verification.
- The implementation agent addresses valid blocking findings, adds regression coverage where appropriate, reruns affected checks, and requests re-review of the new commit.
- Repeat until blocking findings are resolved. Then record the approved SHA.

Escalation is required rather than an open-ended loop:

- The same blocking finding remains after two remediation rounds.
- Three review rounds have completed without convergence.
- Reviewer and implementer disagree about a requirement, a gate, or a security concern.
- The issue needs a scope or acceptance-criteria change.
- Required CI or tooling is unavailable and cannot be distinguished from a product failure.

At an escalation point, stop, summarize the disputed finding and evidence, and ask the maintainer for a decision. Do not silently weaken a gate, rewrite acceptance criteria to match the implementation, or merge around the disagreement.

## Prohibited actions

- Implementing without an agreed issue or maintainer-authorized exception.
- Working directly on `main` or creating a PR from an unrelated branch.
- Self-approving a review, marking one's own blocking finding resolved without a fix, or claiming a review covered a later commit.
- Changing acceptance criteria to match incomplete implementation without maintainer approval.
- Suppressing diagnostics, weakening a quality gate, or changing analyzer configuration independently.
- Publishing credentials, private data, local absolute paths, or references to local-only artifacts.
- Claiming a command, test, CI run, or Windows behavior passed without verifying it.
- Requiring external contributors to use Paseo or internal agent tooling.

## References

- [Issue tracker](issue-tracker.md) and [triage labels](triage-labels.md) for stage 1.
- [Workspace](workspace.md) for stage 2.
- [Implementation](implementation.md) for stage 3.
- [Code review](code-review.md) and [review remediation](review-remediation.md) for stage 4.
- [Pull request](pull-request.md) for stage 5.
- [PR merge](pr-merge.md) for stage 6.
- [Coding standards](../../CODING_STANDARDS.md), [quality gates](quality-gates.md), [development](../development.md), [architecture](../architecture.md), and [ADRs](../adr/) remain the single sources of truth for their subjects.
- [GitHub operations](github-operations.md) owns publication and local-only artifact policy.
