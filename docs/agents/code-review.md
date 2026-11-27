# Code review

Authoritative for independent review of an implemented change. Remediation lives in [Review remediation](review-remediation.md); loop limits and escalation live in [Development workflow](development-workflow.md); coding rules live in [Coding standards](../../CODING_STANDARDS.md); verification policy lives in [Quality gates](quality-gates.md).

## Purpose

Evaluate the actual change against the issue specification and the repository's engineering rules. Review both correctness against the contract and the quality of the implementation. A review is not a summary of what the implementer says they did.

## Required inputs

- The issue and its acceptance criteria.
- The base commit SHA and the exact head commit SHA under review.
- The diff for that range and the relevant surrounding code.
- The implementer's verification evidence and known limitations.
- [Coding standards](../../CODING_STANDARDS.md), [architecture](../architecture.md), relevant [ADRs](../adr/), and [quality gates](quality-gates.md).

## Entry criteria

- Implementation is complete for the issue's scope.
- The working tree is clean enough that the diff is reproducible.
- The required checks have run on the head commit, or the absence of a check is explained.
- The review is performed in a fresh context, not by continuing the implementation reasoning.

## Procedure

### 1. Fix the review range

```bash
git fetch origin
git diff --stat <base-sha>...<head-sha>
git log --oneline <base-sha>..<head-sha>
git diff <base-sha>...<head-sha>
```

Review the committed range, not an uncommitted working tree. If the head changes during review, restart or explicitly review the new range.

### 2. Check specification conformance

For each acceptance criterion, determine whether the change satisfies it and whether the evidence proves it. Look for:

- Missing requirements or partially implemented behavior.
- Behavior that exceeds the issue's scope.
- Acceptance criteria changed to match the implementation instead of the contract.
- Edge cases and failure behavior not handled.
- Documentation or templates that no longer match the behavior.

### 3. Check engineering quality

- Architectural boundaries and dependency direction.
- Nullability and type modeling, including any null-forgiving operator.
- Resource ownership, disposal, cancellation, and concurrency.
- Error handling at the correct boundary and secret-safe messages.
- Security and privacy, including credentials, logs, and local-only artifacts.
- Tests: do they exercise the behavior, the failure path, and the regression?
- Duplication, unnecessary abstraction, and unrelated refactoring.
- Quality-gate integrity: no unauthorized suppression, analyzer change, or CI weakening.

### 4. Write actionable findings

Every actionable finding includes:

- **Severity**: blocking or non-blocking.
- **Location**: file and line or a precise symbol.
- **Evidence**: the code or behavior that demonstrates the problem.
- **Rule or requirement**: the acceptance criterion, coding standard, architecture rule, or gate policy affected.
- **Expected correction or verification**: what would resolve it.

A blocking finding is a correctness defect, a missed acceptance criterion, a security or privacy problem, an architectural violation, an unauthorized gate change, or a test gap that could hide a real failure. A style preference or optional improvement is non-blocking.

Do not use "nit" as a substitute for a clear severity. Do not require unrelated cleanup as a condition of approval.

### 5. Verify claims independently

Run the commands needed to confirm the important claims. At minimum, inspect that the reported checks correspond to the head commit. Do not accept a build result as evidence of Windows runtime behavior.

### 6. Record the decision

The review output states:

- **Decision**: approve, or request changes.
- **Reviewed commit**: the exact full SHA.
- **Blocking findings**: count and summary.
- **Non-blocking findings**: optional improvements.
- **Evidence inspected**: commands, test results, or CI runs actually checked.
- **Unverified areas**: behavior that could not be verified in this environment.

Approval applies only to the named commit. It does not approve a later commit, a rebased branch, or an unrecorded edit, except for the narrow documentation-only delta described below.

### 7. Documentation-only follow-up after approval

A change may be approved and then receive ordinary documentation updates during the pre-merge documentation freshness review. Repeating the complete implementation review solely because the README or an architecture description was corrected adds review overhead without adding assurance about the reviewed implementation.

#### Ordinary documentation updates

The following are ordinary documentation updates when they accurately describe the already-reviewed implementation:

- Updating `README.md` to describe reviewed behavior.
- Updating architecture or product descriptions to reflect the reviewed implementation.
- Correcting outdated descriptions, Markdown formatting, links, or typographical errors.
- Updating documentation indexes and routing references without changing the underlying policy.

For a purely ordinary documentation delta:

- Do not request another independent code review.
- Run the applicable documentation validation checks.
- Verify that the documentation accurately describes the reviewed implementation.
- Confirm that no production code, executable configuration, dependency, test, or quality-gate change was introduced.
- Keep the previous review valid for the previous implementation.

Do not fabricate a new review approval for the documentation commit. Record:

- The previously approved implementation SHA.
- The final PR head SHA.
- The documentation-only delta between them.
- The documentation validation result.
- The reason independent code re-review was not required.

Verify the complete delta between the approved implementation and the final head:

```bash
git diff --name-status <approved-sha>..<final-head-sha>
git log --oneline <approved-sha>..<final-head-sha>
git diff <approved-sha>..<final-head-sha>
```

Examining only the latest commit is insufficient. If the delta contains anything outside documentation, or if it changes substantive requirements, return to the normal review procedure for the affected work.

#### Substantive documentation changes

File extension alone does not make a change harmless. A change that modifies any of the following is substantive and needs the appropriate independent review or maintainer decision:

- Engineering requirements or coding rules.
- Security or privacy policy.
- Architecture contracts or accepted decisions.
- Quality-gate, CI, analyzer, or repository policy.
- Issue acceptance criteria or scope.
- Mandatory agent instructions or workflow obligations.

A typo or link correction in a policy document may still be ordinary if it does not change meaning. A substantive edit to the same document is not.

If production code, executable configuration, dependencies, tests, scripts, or quality-gate behavior changes after approval, return to the existing code review procedure. The documentation-only exception must not weaken implementation review requirements.

## Required outputs

- A review report with the reviewed SHA and decision.
- Blocking and non-blocking findings in the required format.
- Evidence inspected and unverified areas.
- A clear handoff to remediation when changes are requested.
- For a documentation-only follow-up, the approved implementation SHA, final head, delta, validation result, and reason no re-review was required.

## Exit criteria

- The review approves the exact head commit and has no blocking findings, **or**
- Blocking findings are recorded and handed to [Review remediation](review-remediation.md), **or**
- The implementation is approved, a later delta is proven documentation-only under the exception above, and the required record and validation are complete.

## Prohibited actions

- Reviewing a stale commit, an uncommitted diff, or a summary instead of the actual change.
- Approving a change without checking the acceptance criteria.
- Approving one's own implementation without a fresh independent context.
- Treating a passing build as proof of runtime behavior.
- Hiding a gate change, suppression, or test gap as a style comment.
- Turning a non-blocking preference into a blocking demand without a rule or requirement.
- Treating a `.md` change as documentation-only without inspecting its content and the complete approved-to-final delta.
- Using the documentation-only exception to avoid review of a substantive policy, contract, security, quality-gate, or agent-instruction change.
- Publishing credentials, private data, local absolute paths, or local-only artifact references in the review.

## References

- [Development workflow](development-workflow.md) for the overall sequence.
- [Implementation](implementation.md) for the preceding stage.
- [Review remediation](review-remediation.md) for the following stage.
- [Coding standards](../../CODING_STANDARDS.md), [architecture](../architecture.md), [ADRs](../adr/), and [quality gates](quality-gates.md) for review criteria.
- [Development](../development.md#documentation-validation) for the documentation validation commands.
- [GitHub operations](github-operations.md) for review publication and local-only artifact policy.
