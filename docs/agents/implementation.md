# Implementation

Authoritative for slice-based implementation once an issue is ready and a workspace exists. Coding rules live in [Coding standards](../../CODING_STANDARDS.md); verification and suppression policy live in [Quality gates](quality-gates.md); commands live in [Development](../development.md).

## Purpose

Turn an issue specification into the smallest reviewable set of changes that satisfies its acceptance criteria, with tests and evidence that another person can verify.

## Required inputs

- A ready issue with acceptance criteria, scope, and verification requirements.
- A verified worktree and branch based on current `origin/main`.
- Relevant architecture documents and ADRs.
- The coding standards and quality-gate policy.

## Entry criteria

- The workspace matches the issue.
- The specification is unambiguous. If an acceptance criterion or known limitation would require behavior not approved in the issue, stop and ask before implementing it.
- Required dependencies and permissions are available.

## Procedure

### 1. Define implementation slices

Split the issue into small, coherent slices. Each slice states:

- Its purpose and observable outcome.
- The files or boundaries it may touch.
- The tests or checks that prove it.
- Its dependencies on earlier slices.

Keep the slices in the issue or a working note. Do not create an elaborate plan document when the issue can carry the contract.

### 2. Read the relevant sources of truth

Read only the documents routed by [AGENTS.md](../../AGENTS.md). For code changes, that normally includes [Coding standards](../../CODING_STANDARDS.md), [Architecture](../architecture.md), and the relevant ADRs. For verification, read [Quality gates](quality-gates.md).

### 3. Implement the smallest correct change

- Follow the existing structure, naming, and patterns.
- Prefer explicit null checks and sound type modeling over suppression.
- Keep provider-specific behavior behind an adapter and represent unsupported capabilities explicitly.
- Put Windows interop in a small boundary with a managed interface.
- Dispose resources, cancel asynchronous work, and release native handles.
- Do not add speculative abstractions or unrelated refactors.
- Do not add product features the issue does not request.

Test-driven development is optional. Apply the testability and regression-test rules in [Coding standards](../../CODING_STANDARDS.md) and run the commands in [Development](../development.md#tests).

### 4. Verify each slice

Run the targeted checks for the area you changed. Use the commands in [Development](../development.md#quality-gates). For repository-policy or configuration changes, run the policy subset explicitly.

If a check fails, fix the cause. Do not add a suppression, weaken a severity, exclude a file, or change a gate independently. Stop and request maintainer approval with reproducible evidence, following [Quality gates](quality-gates.md).

### 5. Commit coherent units

Use the commit convention in [GitHub operations](github-operations.md). Keep formatting-only changes separate from behavior changes when practical. Do not commit build output, credentials, private logs, or local-only artifacts.

Run the publication checker on the commit message if the local hook is not configured.

### 6. Complete the full required suite before review

Run the complete required validation from [Quality gates](quality-gates.md) on the final commit. Record the exact commands and results. Distinguish:

- A successful build from verified Windows runtime behavior.
- A test that ran from a test that could not run on this platform.
- A check that is not applicable from a check that was skipped or failed.

### 7. Hand off to review

Provide the reviewer with:

- The issue number and acceptance criteria.
- The base and head commit SHAs.
- The diff or a command to reproduce it.
- The verification evidence and any unverified behavior.
- Known limitations and risks.

## Required outputs

- Commits on the issue branch.
- Tests covering the changed behavior.
- Verification evidence for each acceptance criterion.
- A list of unverified behavior, if any.
- A clean or explicitly explained working tree.

## Exit criteria

- Every acceptance criterion is implemented or explicitly reported as blocked.
- The required checks pass on the final commit.
- No unauthorized suppression or gate change is present.
- The change contains no unrelated scope.
- The implementation is ready for independent review.

## Prohibited actions

- Implementing behavior that the issue does not request.
- Treating the absence of mandatory test-driven development as permission to omit tests.
- Suppressing a diagnostic, weakening a gate, or changing analyzer configuration independently.
- Using a null-forgiving operator or a self-written comment to silence nullability analysis.
- Adding a package, service, UI framework, or abstraction without the justification required by the coding standards.
- Publishing credentials, private data, local absolute paths, or local-only artifact references.
- Claiming a command, test, CI run, or Windows behavior passed without verifying it.
- Rewriting or discarding someone else's work in the same worktree.

## References

- [Development workflow](development-workflow.md) for stage transitions.
- [Workspace](workspace.md) for branch and worktree rules.
- [Coding standards](../../CODING_STANDARDS.md) for code rules.
- [Quality gates](quality-gates.md) for required verification and suppression approval.
- [Development](../development.md) for commands and environment.
- [Architecture](../architecture.md) and [ADRs](../adr/) for boundaries and decisions.
- [Code review](code-review.md) for the next stage.
