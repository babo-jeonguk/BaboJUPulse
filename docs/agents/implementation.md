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
- The tests or checks that prove it, including the `validate.sh slice` profiles selected under the [gate-selection matrix](quality-gates.md#slice-completion-validation).
- Its dependencies on earlier slices and the clean checkpoint it starts from.
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

### 4. Verify each slice and confirm its checkpoint

A slice starts from the previous verified, clean checkpoint. Select gates by the change type and affected behavior; the authoritative [gate-selection matrix and snapshot contract](quality-gates.md#slice-completion-validation) define the profiles. In summary:

- C# production or test changes use `--csharp`.
- Dependency, build, or configuration changes use `--config`.
- Workflow shell changes use `--workflow`.
- Documentation changes use `--docs`.
- Mixed changes combine the applicable profiles.

Public-content checking is always included. Add another affected check when the profile is insufficient; the profiles are not a change-impact engine. Do not substitute an arbitrary minimal set for the gates the change needs.

Stage only the intended slice, inspect the actual diff, then run the slice completion gate:

```bash
git add <intended paths>
scripts/workflow/validate.sh slice --csharp --workflow
```

The script reuses the existing gates, runs them in a fixed order, deduplicates them, and requires a clean staged snapshot: the worktree must match the index and no non-ignored untracked files may remain. It records the starting HEAD and index tree and checks them again after the gates. It reports the selected checks and their results. It fails nonzero when a required check fails; dependent tests or policy checks are skipped when restore or build fails rather than run against stale binaries. Exit status 3 means the snapshot changed during validation, so the result is invalid even if the individual checks passed.

`validate.sh targeted` is still available for faster iteration and applies the same build prerequisites, but it is not completion evidence.

If a check fails or is unavailable, fix the cause and rerun. Do not add a suppression, weaken a severity, exclude a file, or change a gate independently. Stop and request maintainer approval with reproducible evidence, following [Quality gates](quality-gates.md).

Inspect the actual diff before committing. Keep ignored generated build output outside the checkpoint.

### 5. Commit the verified slice and confirm the checkpoint

Commit the verified snapshot as one or more coherent commits using the convention in [GitHub operations](github-operations.md). Keep formatting-only changes separate from behavior changes when practical. Do not commit build output, credentials, private logs, or local-only artifacts.

Confirm that the commit contains the validated snapshot:

```bash
scripts/workflow/validate.sh checkpoint \
  --head <validated-head> \
  --tree <validated-tree>
```

The checkpoint command requires a clean worktree, the current HEAD to be the checkpoint commit, the commit tree to equal the validated tree, and the validated starting HEAD to be an ancestor. Only a verified checkpoint completes the slice. If the tree, lineage, or state does not match, revalidate the intended change before starting another slice.

Do not accumulate completed slices into a later commit or start the next slice with unresolved changes. One or more coherent commits are acceptable. Run the publication checker on the commit message if the local hook is not configured.

### 6. Complete the full required suite on the final clean commit

After all slices are committed, run the complete required validation on the final commit:

```bash
scripts/workflow/validate.sh full
```

Full mode requires a clean committed worktree and the same HEAD before and after the run, and it runs every existing gate in that invocation. A dirty tree, changed HEAD, unavailable state query, or missing dependency fails; do not present pre-commit slice results as full validation of the final commit. Repeat full validation whenever the final implementation commit changes.

Record the exact command, checkpoint, and result. Distinguish:

- A successful build from verified Windows runtime behavior.
- A test that ran from a test that could not run on this platform.
- A check that is not applicable from a check that was skipped or failed.

The individual commands remain authoritative in [Development](../development.md#quality-gates) and [Development tests](../development.md#tests). The script fails closed with status 3 if HEAD or the working tree changes while the checks run, because the evidence may no longer describe the inspected commit.

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
- The current verified, clean checkpoint SHA.
- The files or boundaries it may touch and its dependencies.
- Applicable architecture decisions, coding standards, and quality-gate requirements.
- The `validate.sh slice` profiles selected for the slice and any additional affected checks.
- Explicit scope restrictions and prohibited actions.

Ask the worker to follow the same completion contract as direct implementation: stage only the intended slice, run its slice validation, inspect the diff, commit the verified snapshot, confirm the checkpoint, and return a concise result containing:

- The implemented behavior.
- The changed files or components.
- The validated starting HEAD and validated tree.
- The checkpoint commit SHA and confirmation that the worktree is clean.
- The actual gate results.
- Remaining limitations or blockers.

If the worker cannot commit, it must return clearly identified uncommitted changes. The lead then finishes validation and commits before any later slice starts. Use the session output as the default handoff. Do not require an artifact file for each worker or slice.

### Lead responsibilities

After a delegated slice:

- Inspect the actual changes rather than accepting the completion claim.
- Confirm the slice satisfies its contract.
- Confirm unrelated files and requirements were not changed.
- Confirm the applicable validation results apply to the returned snapshot.
- Verify the checkpoint commit tree, starting-HEAD ancestry, and clean worktree; if the work was returned uncommitted, complete the slice validation and commit it.
- Resolve integration issues before starting a dependent slice.

After all slices, the lead remains responsible for integration correctness, complete acceptance-criteria coverage, domain and architecture consistency, the full required validation on the final clean commit, and the handoff to independent review. Delegated implementation does not replace the fresh-context review stage.

## Required outputs

- Commits on the issue branch.
- Tests covering the changed behavior.
- A verified checkpoint SHA and validated tree for each slice.
- Verification evidence for each acceptance criterion and the commit it applies to.
- Full validation on the final clean commit.
- A list of unverified behavior, if any.
- A clean or explicitly explained working tree.
- Canonical domain terminology in code, tests, and handoff.
- A session handoff with no unnecessary duplicate report.

## Exit criteria

- Every acceptance criterion is implemented or explicitly reported as blocked.
- Each slice has a verified commit checkpoint and a clean worktree before the next slice starts.
- The required checks pass on the final clean commit, including full validation.
- No unauthorized suppression or gate change is present.
- The change contains no unrelated scope.
- Domain terminology and relationships match the issue and glossary, or the conflict is recorded.
- The implementation is ready for independent review.

## Prohibited actions

- Implementing behavior that the issue does not request.
- Treating the absence of mandatory test-driven development as permission to omit tests.
- Treating targeted checks or an uncommitted validation result as slice-completion evidence.
- Starting the next slice before the verified changes are committed at a confirmed checkpoint.
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
