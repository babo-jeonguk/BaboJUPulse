# Review remediation

Authoritative for resolving review findings and requesting re-review. Loop limits and escalation live in [Development workflow](development-workflow.md); review criteria live in [Code review](code-review.md); the finding format lives in the [review report template](templates/review-report.md); verification policy lives in [Quality gates](quality-gates.md).

## Purpose

Resolve valid blocking findings at their root cause, provide evidence, and return the change to review without an unbounded loop or a silent gate change.

## Required inputs

- The review report in the [review report template](templates/review-report.md), including the reviewed commit SHA and stable finding identifiers.
- The issue acceptance criteria and relevant domain terms.
- The implementation worktree and branch.
- Verification evidence for the reviewed commit.

## Entry criteria

- At least one blocking finding exists, or a reviewer requested changes for a requirement clarification.
- The reviewed SHA is known and the branch has not moved without explanation.

## Procedure

### 1. Triage every finding

For each finding, refer to its stable identifier and decide explicitly:

- **Valid and blocking**: fix it.
- **Valid but non-blocking**: record it for the current change or a follow-up issue, according to the reviewer's severity.
- **Duplicate**: link the finding it duplicates.
- **Incorrect or out of scope**: explain why with evidence, and ask the reviewer or maintainer to resolve the disagreement.

Do not ignore a finding silently. Do not mark it resolved because a comment was added, a test was weakened, or the acceptance criterion was rewritten.

### 2. Fix the root cause

- Change the implementation, not the gate.
- Add or update a regression test when the finding describes a behavior defect.
- Keep the fix within the issue's scope unless the maintainer approves a scope change.
- If a finding reveals that the requirement is wrong or ambiguous, stop and request a maintainer decision before coding around it.

### 3. Rerun affected verification

Run the checks affected by the change, then the full required suite before sending the new head to review. Record the actual commands and results.

### 4. Commit and report

Create a new commit or a coherent set of commits. Do not force-push over reviewed history unless the repository policy and reviewer explicitly allow it. For each finding, report:

- The stable finding identifier.
- The disposition.
- The commit or file that addresses it.
- The verification that proves the correction.

Use `scripts/workflow/validate.sh` for the affected checks and the full required suite before the new head goes to review. Report the exact reviewed SHA that the evidence applies to.

### 5. Request re-review

Request review of the new head SHA. Refer to each prior finding by its identifier and state whether it is resolved, retained, or disputed. The reviewer must confirm whether the previous blocking findings are resolved and whether the changes introduced new issues. Approval of the previous commit does not carry forward, except for the documentation-only follow-up defined in [Code review](code-review.md#7-documentation-only-follow-up-after-approval).

## Escalation

The loop limits and escalation triggers are owned by [Development workflow](development-workflow.md#review-and-remediation-loop). Do not continue an unlimited loop, merge around a disagreement, or weaken a gate to end it.

When escalation is required, provide the finding, the evidence, the attempted corrections, the disputed rule or requirement, and the decision needed. Stop implementation until the maintainer resolves it.

## Required outputs

- A disposition for every blocking finding, keyed by its stable identifier.
- Corrected commits and regression coverage where applicable.
- Verification evidence for the new head and the exact SHA it applies to.
- A re-review request naming the exact new SHA and the prior finding statuses.
- An escalation record when a loop limit is reached.

## Exit criteria

- Every valid blocking finding is resolved and verified.
- The reviewer approves the exact current head commit, or the only later delta is a recorded documentation-only follow-up under [Code review](code-review.md#7-documentation-only-follow-up-after-approval).
- No finding was silently dismissed or converted into an unapproved gate change.

## Prohibited actions

- Marking a finding resolved without changing the code or proving it is invalid.
- Weakening, disabling, or suppressing a check to obtain approval.
- Rewriting acceptance criteria to match incomplete work without maintainer approval.
- Force-pushing over a reviewed commit and presenting the result as reviewed.
- Continuing indefinite review rounds instead of escalating.
- Publishing raw private evidence while discussing a finding.

## References

- [Code review](code-review.md) for review criteria and the review decision.
- [Review report template](templates/review-report.md) for finding identifiers and the re-review record.
- [Implementation](implementation.md) for the implementation rules that still apply.
- [Quality gates](quality-gates.md) for suppressions, gate changes, and verification.
- [Development](development-workflow.md) for stage transitions and escalation.
- [Development](../development.md#workflow-scripts) for validation entry points.
- [Pull request](pull-request.md) for the next stage after convergence.
