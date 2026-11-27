# Implementation

Authoritative for slice-based implementation once an issue is ready and a workspace exists. Coding rules live in [Coding standards](../../CODING_STANDARDS.md); verification and suppression policy live in [Quality gates](quality-gates.md); commands live in [Development](../development.md).

## Purpose

Turn an issue specification into the smallest reviewable set of changes that satisfies its acceptance criteria, with tests and evidence that another person can verify.

## Required inputs

- A ready issue with acceptance criteria, scope, verification requirements, and relevant domain terms.
- A verified worktree and branch based on current `origin/main`.
- [GLOSSARY.md](../../GLOSSARY.md) and [domain guidance](domain.md) for canonical terminology.
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
- The domain terms it uses and any ambiguity that must be resolved first.

Keep the slices in the issue or a working note. Do not create an elaborate plan document when the issue can carry the contract.

### 2. Read the relevant sources of truth

Read only the documents routed by [AGENTS.md](../../AGENTS.md). For code changes, that normally includes [Coding standards](../../CODING_STANDARDS.md), [Architecture](../architecture.md), the relevant ADRs, and [GLOSSARY.md](../../GLOSSARY.md). For verification, read [Quality gates](quality-gates.md). If the issue and the glossary disagree on a term or relationship, follow [Domain guidance](domain.md#conflicts) instead of silently choosing one.

### 3. Implement the smallest correct change

- Follow the existing structure, naming, and patterns.
- Use the canonical domain term from [GLOSSARY.md](../../GLOSSARY.md) in code, tests, and messages.
- Prefer explicit null checks and sound type modeling over suppression.
- Keep provider-specific behavior behind an adapter and represent unsupported capabilities explicitly.
- Put Windows interop in a small boundary with a managed interface.
- Dispose resources, cancel asynchronous work, and release native handles.
- Do not add speculative abstractions or unrelated refactors.
- Do not add product features the issue does not request.

Test-driven development is optional. Apply the testability and regression-test rules in [Coding standards](../../CODING_STANDARDS.md) and run the commands in [Development](../development.md#tests).

### 4. Verify each slice

Run the targeted checks for the area you changed:

```bash
scripts/workflow/validate.sh targeted --format --build --test
```

Use the specific checks that apply, such as `--docs`, `--policy`, or `--workflow`. The script reports the repository, commit, dirty state, checks executed, and results, and fails when a required check fails. The individual commands remain authoritative in [Development](../development.md#quality-gates) and [Development tests](../development.md#tests).

If a check fails, fix the cause. Do not add a suppression, weaken a severity, exclude a file, or change a gate independently. Stop and request maintainer approval with reproducible evidence, following [Quality gates](quality-gates.md).

### 5. Commit coherent units

Use the commit convention in [GitHub operations](github-operations.md). Keep formatting-only changes separate from behavior changes when practical. Do not commit build output, credentials, private logs, or local-only artifacts.

Run the publication checker on the commit message if the local hook is not configured.

### 6. Complete the full required suite before review

Run the complete required validation on the final commit:

```bash
scripts/workflow/validate.sh full
```

Record the exact command and result. Distinguish:

- A successful build from verified Windows runtime behavior.
- A test that ran from a test that could not run on this platform.
- A check that is not applicable from a check that was skipped or failed.

The script fails closed if HEAD or the working tree changes while the checks run, because the evidence may no longer describe the inspected commit.

### 7. Hand off to review

Provide the reviewer with:

- The issue number, acceptance criteria, and relevant domain terms.
- The base and head commit SHAs.
- The diff or a command to reproduce it.
- The verification evidence and any unverified behavior.
- Known limitations and risks.

Use the agent session output for the handoff. Do not create a separate implementation report or a fixed set of per-stage files. Keep any genuinely necessary handoff artifact minimal and local, and move durable conclusions into the issue, PR, commit, test, glossary, or ADR before cleanup. See [GitHub operations](github-operations.md#artifact-ownership).

## Optional slice delegation

The implementation agent may implement the slices directly or delegate selected slices sequentially to fresh-context subagents. Delegation is optional; direct implementation is the default for small, straightforward changes.

Choose delegation when the issue has several substantial slices, a slice needs focused investigation, earlier slices have made the context unnecessarily large, the slice has a clear contract and bounded scope, or a fresh context would help resolve a repeatedly failing slice. Prefer direct implementation for a small change, a tightly coupled set of edits, or a slice that cannot be described without the whole context.

Do not make parallel implementation the default. Only one implementation agent may modify the issue worktree at a time during sequential delegation. Do not create a separate issue, branch, pull request, or worktree for each slice.

### Invoking a delegated worker

Use the Paseo MCP agent tools exposed by the installed Paseo daemon. Verify the available tool names and arguments for the installed version rather than guessing. If the session exposes only the Paseo CLI, the verified equivalents are `paseo run` to create a worker, `paseo send` to continue it, `paseo wait` to wait for it to become idle, and `paseo inspect` to read its state. Run the worker in the existing issue workspace and tell it to use the existing branch.

Do not delegate merge, approval, quality-gate changes, or scope expansion. The implementation lead keeps responsibility for the complete issue.

### Slice handoff contract

Give the worker:

- The GitHub issue and its authoritative specification.
- The specific slice objective and observable outcome.
- The relevant acceptance criteria and domain terms.
- The current starting commit SHA.
- The files or boundaries it may touch and its dependencies.
- Applicable architecture decisions, coding standards, and quality-gate requirements.
- The required verification.
- Explicit scope restrictions and prohibited actions.

Ask the worker to return a concise result containing:

- The implemented behavior.
- The changed files or components.
- The commit SHA or clearly identified uncommitted changes.
- The verification performed and the actual results.
- Remaining limitations or blockers.

Use the session output as the default handoff. Do not require an artifact file for each worker or slice.

### Lead responsibilities

After a delegated slice:

- Inspect the actual changes rather than accepting the completion claim.
- Confirm the slice satisfies its contract.
- Confirm unrelated files and requirements were not changed.
- Confirm the applicable validation results and the commit they apply to.
- Resolve integration issues before starting a dependent slice.

After all slices, the lead remains responsible for integration correctness, complete acceptance-criteria coverage, domain and architecture consistency, the full required validation, and the handoff to independent review. Delegated implementation does not replace the fresh-context review stage.

## Required outputs

- Commits on the issue branch.
- Tests covering the changed behavior.
- Verification evidence for each acceptance criterion and the commit it applies to.
- A list of unverified behavior, if any.
- A clean or explicitly explained working tree.
- Canonical domain terminology in code, tests, and handoff.
- A session handoff with no unnecessary duplicate report.

## Exit criteria

- Every acceptance criterion is implemented or explicitly reported as blocked.
- The required checks pass on the final commit.
- No unauthorized suppression or gate change is present.
- The change contains no unrelated scope.
- Domain terminology and relationships match the issue and glossary, or the conflict is recorded.
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
- Requiring subagent delegation for every issue or slice.
- Allowing two implementation agents to modify the same worktree at once.
- Delegating merge, self-approval, a quality-gate change, or a scope expansion to a worker.

## References

- [Development workflow](development-workflow.md) for stage transitions.
- [Workspace](workspace.md) for branch and worktree rules.
- [Domain guidance](domain.md) and [GLOSSARY.md](../../GLOSSARY.md) for canonical terminology.
- [Coding standards](../../CODING_STANDARDS.md) for code rules.
- [Quality gates](quality-gates.md) for required verification and suppression approval.
- [Development](../development.md) for commands, environment, and workflow scripts.
- [Architecture](../architecture.md) and [ADRs](../adr/) for boundaries and decisions.
- [Code review](code-review.md) for the next stage.
