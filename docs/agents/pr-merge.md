# Pull request merge and cleanup

Authoritative for the final merge, the pre-merge documentation freshness review, post-merge verification, and workspace cleanup. PR preparation lives in [Pull request](pull-request.md); the documentation-only review exception lives in [Code review](code-review.md); merge strategy and branch protection remain in [GitHub operations](github-operations.md).

## Purpose

Merge only a reviewed, verified, mergeable change, confirm that the documentation still matches the result, then leave `main`, the remote branches, the local branches, and the associated workspace in a clean and verified state.

## Required inputs

- An open PR linked to the issue.
- The exact approved implementation SHA and review decision.
- The final PR head SHA and, when it differs, the complete delta from the approved implementation.
- The required CI result for the final head and the documentation validation result.
- The issue acceptance criteria, recorded limitations, and the documentation review record.
- Access to merge the PR, delete the branch when appropriate, update the local `main` worktree, and remove or archive the workspace.

## Entry criteria

All of the following are true:

- The issue's acceptance criteria are satisfied or explicitly deferred by maintainer decision.
- Every blocking review finding is resolved.
- Required `build` checks pass on the final head.
- The documentation validation workflow passes on the final head, or its unavailability is recorded together with a local documentation validation result.
- Relevant advisory security checks have been inspected.
- All required review conversations are resolved.
- The branch is mergeable and up to date as required by branch protection.
- The approved implementation SHA matches the current head, or the difference is a recorded documentation-only delta accepted under [Code review](code-review.md#7-documentation-only-follow-up-after-approval).
- The pre-merge documentation freshness review is recorded below.
- The change is classified as a two-way or one-way door, and a one-way door has the maintainer decision required by the PR's Merge Danger assessment.

## Procedure

### 1. Reconfirm the reviewed state

Start with the explicit verified SHA from the review record. Do not fetch a new head and treat it as verified.

```bash
scripts/workflow/validate.sh range --base <base-sha> --head <final-head-sha>
scripts/workflow/merge.sh inspect \
  --pr <number> \
  --verified-sha <final-head-sha>
```

`validate.sh range` refreshes `origin`, verifies both commits and their ancestry, and prints the commit count and diffstat. `merge.sh inspect` is read-only: it checks the PR state, base, draft state, current head, mergeability, and the required checks against the supplied SHA. It never replaces the supplied SHA with a freshly fetched value.

Record the approved implementation SHA and the final head SHA separately. If the head differs from the approved SHA, inspect the complete delta, not only the latest commit:

```bash
git diff --name-status <approved-sha>..<final-head-sha>
git log --oneline <approved-sha>..<final-head-sha>
git diff <approved-sha>..<final-head-sha>
```

A difference that is not a documentation-only delta returns to [Code review](code-review.md) for the affected work.

A documentation-only delta must:

- Change only documentation artifacts.
- Not change production code, executable configuration, dependencies, tests, CI workflows, scripts, build settings, analyzer settings, or quality-gate policy.
- Not change substantive engineering requirements, security policy, architecture contracts, acceptance criteria, or mandatory agent instructions.
- Accurately describe the implementation that was reviewed.
- Pass the documentation validation checks.

Record the approved SHA, final head SHA, changed documentation files, validation result, and the reason independent code re-review was not required. Do not fabricate a review approval for the documentation commit.

If `merge.sh inspect` reports a head mismatch, stop. The current PR head is not the commit that was reviewed and verified. Return to review and verification; do not merge the new head by adopting it as the expected SHA.

### 2. Inspect checks and security signals

- `merge.sh inspect` confirms the required checks. The default set is `build` and `documentation`; add `--require-check <name>` only when another check is required. The branch-protection required check is `build`, and the merge procedure also requires the `documentation` workflow result.
- A documentation-only commit does not make the pull request documentation-only for CI purposes; the full build still runs.
- If the `documentation` workflow did not run, record a local `scripts/workflow/validate.sh docs` result and the reason. When the workflow cannot run, pass `--allow-missing-check documentation` explicitly and record why; a missing check that actually ran and failed is never allowed, and the mandatory `build` check cannot be waived. Do not add path filters to make it disappear, and do not treat an earlier run on another commit as evidence for the final head.
- Inspect CodeQL and dependency-review results when relevant. They are advisory unless the maintainer says otherwise, but a new security finding needs a decision before merge.
- Confirm no unresolved conversation or requested-change review remains. The script does not replace this human check.
- Confirm the branch is mergeable and targets `main`. If it is behind the base, update it, rerun affected checks, re-review a change that is not documentation-only, and repeat this procedure.

### 3. Perform the documentation freshness review

Use the actual diff, the issue specification, and the affected code areas to decide which documents may be stale. Do not read or rewrite every document merely to demonstrate a review.

Start from the changed files and search for documents that describe them:

```bash
git diff --name-status <base-sha>...<final-head-sha>
git diff --stat <base-sha>...<final-head-sha>
```

Relevant candidates include:

- `README.md`, `AGENTS.md`, `CONTRIBUTING.md`, `CODING_STANDARDS.md`, and `GLOSSARY.md`.
- `docs/product-scope.md`, `docs/architecture.md`, and `docs/development.md`.
- `docs/agents/`, including [Domain guidance](domain.md) and `docs/agents/templates/`, and the documentation indexes.
- Relevant ADRs.

Check for:

- Outdated descriptions of implemented features.
- Incorrect architectural boundaries or module responsibilities.
- Domain terms or relationships that no longer match [GLOSSARY.md](../../GLOSSARY.md).
- Obsolete commands, file paths, or development instructions, including workflow-script usage.
- Inconsistent workflow or repository policies.
- Broken links and outdated routing instructions.
- Documentation that describes behavior which no longer matches the implementation.

Update affected documents before merging. Do not make unrelated documentation edits merely to record that a review happened. Historical ADRs are records, not living documents: do not silently rewrite one. If a decision was superseded, preserve its history and add or update the replacement record with a reference to the superseded decision.

Record the outcome in the PR body or a merge comment in this format. Do not create a separate documentation-review report file.

```text
Documentation review
- Inspected: <documents>
- Updated: <documents and the reason>
- No changes needed: <documents and the reason>
- Remaining concerns: <none or the concern and its disposition>
```

Keep the detailed procedure in this document. Other documents link here instead of restating it.

### 4. Merge with the repository strategy

Use the merge strategy and branch-protection settings owned by [GitHub operations](github-operations.md). Preserve them unless the maintainer explicitly authorizes a change.

The verified SHA must come from the review and verification record, not from a value fetched immediately before merging. `merge.sh execute` receives that SHA, compares it with the current PR head, stops on a mismatch, verifies the required checks, and passes the original SHA to `--match-head-commit`:

```bash
scripts/workflow/merge.sh inspect \
  --pr <number> \
  --verified-sha <verified-final-sha>

scripts/workflow/merge.sh execute \
  --pr <number> \
  --verified-sha <verified-final-sha>
```

Do not replace the expected SHA with a newly fetched value when the inspection reports a mismatch. A merge command that fetches the head immediately before merging can adopt a commit that the existing review never covered; that is the gap this procedure closes. If the head changed, return to [Code review](code-review.md) and the verification in this document before attempting another merge.

The script uses a merge commit, does not use `--admin`, and does not request branch deletion by default. Let [cleanup](#6-run-post-merge-cleanup) delete the branch only after it verifies the merged history. Do not bypass branch protection, force-push, or merge an unreviewed implementation commit. If `--match-head-commit` is unavailable or a merge queue requires different handling, stop and record why.

### 5. Verify the merge result

```bash
gh pr view <number> --json state,mergedAt,mergeCommit,headRefName,headRepositoryOwner,headRepository
git fetch origin --prune
git log --oneline -5 origin/main
git merge-base --is-ancestor <final-head-sha> origin/main
```

Confirm:

- The PR is merged with the expected merge commit.
- The expected merge commit exists on `origin/main`.
- The reviewed and verified changes are present on the default branch. A successful merge reference alone is not proof of content; inspect the merge commit or the paths that matter.
- The required CI result on `main` is green or explainable.
- The linked issue was closed by the merge. If GitHub did not close it, comment with the merge reference and close it manually.
- The issue state reflects the actual outcome, including any deferred acceptance criterion.

### 6. Run post-merge cleanup

Run cleanup from a worktree that will remain after the issue worktree is removed, normally the main checkout. Do not run it from inside the worktree that will be archived; archiving stops that workspace's agents and terminals.

Inspect first:

```bash
scripts/workflow/cleanup.sh inspect \
  --pr <number> \
  --verified-sha <final-head-sha> \
  --branch <branch> \
  --workspace-id <workspace-id> \
  --worktree <worktree-path> \
  --main-worktree <main-worktree-path>
```

Then execute the same inputs without `inspect` when the reported state is safe. Omit the optional identifiers when they can be discovered; the script accepts them to make the intended resources explicit. If the only ignored content is reproducible build output, add `--remove-build-output` explicitly; it removes the whole `bin`, `obj`, and `TestResults` directories, so do not use it when they contain notes, logs, or other meaningful local artifacts.

The script verifies and performs these steps:

1. The PR is merged, its merge commit is on `origin/main`, and the supplied verified head, when provided, is included in merged history. A successful PR state alone is not proof of content.
2. The remote branch exists only for this repository, its fetched tip is contained in `origin/main`, and no concurrent update has replaced it. It deletes with a lease on the inspected tip. It never deletes a fork branch, an unrelated branch, or a branch with unmerged commits.
3. Local `main` is clean and is an ancestor of `origin/main`, then fast-forwards with `--ff-only`. It never resets, stashes, or overwrites local work.
4. The issue worktree is on the PR head branch, has no tracked or untracked content that would be lost, and is not a subdirectory of another worktree. Any ignored content retains the worktree unless `--remove-build-output` explicitly requests removal of known reproducible output (`bin`, `obj`, `TestResults`, and `.binlog` files). It refuses a mismatched branch or another worktree, and the script is not running inside the target. It archives the Paseo workspace through Paseo after verifying its working directory, verifies the archive, removes requested build output, removes the Git worktree when it is still registered, prunes stale registrations, and verifies the directory state.
5. The merged local branch is not checked out elsewhere and is contained in `origin/main`. It deletes with `git branch -d`, never `-D`. The branch must equal the PR head branch; `main`, the PR base, and any unrelated branch are rejected before any destructive step.

The installed Paseo version inspected for this procedure is `0.17.3`. In that version, archiving a Paseo-owned worktree workspace stops and archives its owned agents and terminals, removes the Paseo-owned worktree directory when no other active workspace references it, and does not delete the Git branch. Verify `paseo --version` and the archive behavior for a different installed version before relying on it.

Cleanup is safe and idempotent. An already deleted branch or removed worktree is reported as absent, not as a misleading failure. Repeating an already completed step must not delete different work. If a step cannot proceed safely, the script reports the exact blocked step and retains the affected resource. Do not force-remove a dirty worktree, force-delete an unmerged branch, or use a destructive Git command to make cleanup succeed.

### 7. Record completion

Update the issue with the merge commit and any follow-up issues for non-blocking findings or deferred work. Record the final state explicitly:

```text
Completion
- PR: #<number>
- Merge commit: <sha>
- Linked issue: #<number>, <closed/open and reason>
- Remote branch: <deleted / retained and why>
- Local main: <synchronized to origin/main at sha / not updated and why>
- Paseo workspace: <archived / retained and why>
- Git worktree: <removed / retained and why>
- Local branch: <deleted / retained and why>
- Retained artifacts: <none or item and reason>
```

The completion record belongs in the issue or PR; do not create a separate development report. Do not leave an issue open merely because a follow-up exists; link the follow-up explicitly.

## Required outputs

- Merged PR with the expected merge commit.
- A recorded documentation freshness review, including glossary updates when a domain concept changed.
- Verified `origin/main` state and linked issue state.
- Verified remote branch deletion or a recorded reason for retention.
- Local `main` synchronized with `origin/main`, or a recorded blocked reason.
- Removed or archived workspace and worktree when safe, or a recorded reason for retention.
- Deleted merged local branch when safe, or a recorded reason for retention.
- Follow-up issues for deferred non-blocking work.
- A completion record in the issue or PR, not a separate development report.

## Exit criteria

- The merge result is verified on the default branch.
- The reviewed implementation and any documentation-only delta are recorded accurately.
- The documentation freshness review is recorded, and affected documentation and glossary entries are updated.
- Documentation validation and the required CI result apply to the final head.
- The issue state matches the actual outcome.
- Remote and local branches are cleaned up when safe, or explicitly retained with a reason.
- Local `main` is synchronized with `origin/main`, or the blocked condition is reported.
- The workspace and worktree are cleaned up when safe, or explicitly retained with a reason.
- No unreviewed change or dirty worktree remains.
- The final completion report records the state required by this document.
- No temporary report is required to understand the result.

## Prohibited actions

- Merging before required checks pass on the final head.
- Merging a head that differs from the verified head, or replacing the verified SHA with a value fetched immediately before the merge.
- Omitting `--match-head-commit` without a recorded reason.
- Treating a documentation-only commit as a documentation-only pull request for CI purposes.
- Recording a documentation-only delta without inspecting the complete approved-to-final diff.
- Reclassifying a substantive policy, contract, security, or quality-gate change as harmless because its file extension is `.md`.
- Skipping required code review after production code, executable configuration, dependencies, tests, scripts, or quality-gate policy changed.
- A merge strategy that differs from [GitHub operations](github-operations.md), force pushes, or branch-protection bypasses.
- Deleting a worktree with uncommitted changes or meaningful local artifacts.
- Force-removing a dirty worktree or force-deleting an unmerged local branch.
- Deleting an unmerged local branch, an unrelated branch, or an external contributor's branch.
- Reporting `git fetch origin` as synchronization of local `main`.
- Using `git reset --hard`, `git clean`, or another destructive command to make cleanup succeed.
- Closing an issue without recording how the work was resolved.
- Claiming the merge, post-merge CI, or cleanup passed without verifying it.
- Changing merge strategy, branch protection, repository visibility, licensing, or approval requirements without explicit maintainer authorization.
- Creating a separate development or cleanup report instead of recording the result in the issue or PR.

## References

- [Development workflow](development-workflow.md) for the overall sequence.
- [Pull request](pull-request.md) for PR preparation and final-head evidence.
- [Code review](code-review.md) and [review remediation](review-remediation.md) for review evidence and the documentation-only exception.
- [GLOSSARY.md](../../GLOSSARY.md) and [domain guidance](domain.md) for terminology updates.
- [GitHub operations](github-operations.md) for merge strategy, branch protection, repository settings, and artifact ownership.
- [Issue tracker](issue-tracker.md) for issue closure.
- [Workspace](workspace.md) for worktree creation and ownership.
- [Development](../development.md#workflow-scripts) for workflow-script usage and tests.
- GitHub CLI: [`gh pr merge`](https://cli.github.com/manual/gh_pr_merge) and [`gh pr checks`](https://cli.github.com/manual/gh_pr_checks).
- GitHub: [troubleshooting required status checks](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks).
- Git: [worktree](https://git-scm.com/docs/git-worktree), [merge](https://git-scm.com/docs/git-merge), [merge-base](https://git-scm.com/docs/git-merge-base), and [branch](https://git-scm.com/docs/git-branch).
- Paseo: workspace management commands verified against the installed version.
