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

```bash
gh pr view <number> --json number,title,state,headRefOid,baseRefName,mergeable,reviewDecision,statusCheckRollup,headRepositoryOwner,headRepository
git rev-parse HEAD
git diff --name-status <approved-sha>..<final-head-sha>
git log --oneline <approved-sha>..<final-head-sha>
```

Record the approved implementation SHA and the final head SHA separately. If the head differs from the approved SHA, inspect the complete delta, not only the latest commit. A difference that is not a documentation-only delta returns to [Code review](code-review.md) for the affected work.

A documentation-only delta must:

- Change only documentation artifacts.
- Not change production code, executable configuration, dependencies, tests, CI workflows, scripts, build settings, analyzer settings, or quality-gate policy.
- Not change substantive engineering requirements, security policy, architecture contracts, acceptance criteria, or mandatory agent instructions.
- Accurately describe the implementation that was reviewed.
- Pass the documentation validation checks.

Record the approved SHA, final head SHA, changed documentation files, validation result, and the reason independent code re-review was not required. Do not fabricate a review approval for the documentation commit.

### 2. Inspect checks and security signals

- Confirm the required `build` check succeeded on the final head. A documentation-only commit does not make the pull request documentation-only for CI purposes; the full build still runs.
- Confirm the `documentation` workflow result for the final head. It is a separate validation path, not a branch-protection required check by default. If it did not run, record a local result and the reason. Do not add path filters to make it disappear, and do not treat an earlier run on another commit as evidence for the final head.
- Inspect CodeQL and dependency-review results when relevant. They are advisory unless the maintainer says otherwise, but a new security finding needs a decision before merge.
- Confirm no unresolved conversation or requested-change review remains.
- Confirm the branch is mergeable. If it is behind the base, update it, rerun affected checks, re-review a change that is not documentation-only, and repeat this procedure.

### 3. Perform the documentation freshness review

Use the actual diff, the issue specification, and the affected code areas to decide which documents may be stale. Do not read or rewrite every document merely to demonstrate a review.

Start from the changed files and search for documents that describe them:

```bash
git diff --name-status <base-sha>...<final-head-sha>
git diff --stat <base-sha>...<final-head-sha>
```

Relevant candidates include:

- `README.md`, `AGENTS.md`, `CONTRIBUTING.md`, and `CODING_STANDARDS.md`.
- `docs/product-scope.md`, `docs/architecture.md`, and `docs/development.md`.
- `docs/agents/`, the documentation indexes, and relevant ADRs.
- Domain documentation added in the future.

Check for:

- Outdated descriptions of implemented features.
- Incorrect architectural boundaries or module responsibilities.
- Obsolete commands, file paths, or development instructions.
- Inconsistent workflow or repository policies.
- Broken links and outdated routing instructions.
- Documentation that describes behavior which no longer matches the implementation.

Update affected documents before merging. Do not make unrelated documentation edits merely to record that a review happened. Historical ADRs are records, not living documents: do not silently rewrite one. If a decision was superseded, preserve its history and add or update the replacement record with a reference to the superseded decision.

Record the outcome in the PR body or a merge comment in this format:

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

Before merging, confirm that the final head has not changed since verification. `--match-head-commit` makes the merge fail if the PR head no longer matches the verified SHA:

```bash
FINAL_HEAD="$(gh pr view <number> --json headRefOid --jq .headRefOid)"
gh pr merge <number> --merge --delete-branch --match-head-commit "$FINAL_HEAD"
```

Do not bypass branch protection, force-push, or merge an unreviewed implementation commit. Do not omit `--match-head-commit` when the repository's strategy permits it; if the option is unavailable or a merge queue requires different handling, stop and record why.

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

### 6. Verify remote branch cleanup

Check whether the remote branch was actually deleted. `--delete-branch` requested deletion; it is not proof that the branch is gone, and it does not cover a fork's branch.

```bash
git ls-remote --heads origin <branch>
```

If the branch still exists:

- Delete it only when the PR came from this repository, not from an external contributor's fork.
- Confirm the branch tip is included in the merged history before deleting:

  ```bash
  git fetch origin --prune
  git merge-base --is-ancestor origin/<branch> origin/main
  git push origin --delete <branch>
  git fetch origin --prune
  ```

- Do not delete an unrelated branch, a branch containing work that was not merged, or a contributor's fork branch.
- If deletion is unsafe or unavailable, retain the branch and record why.

After deletion, refresh remote-tracking references and verify that the branch no longer appears.

### 7. Synchronize local main

Fetching updates remote-tracking references; it does not update a checked-out local branch. Locate the worktree that contains `main`:

```bash
git worktree list --porcelain
git branch --show-current
```

In the worktree whose `branch` entry is `refs/heads/main`:

```bash
git -C "<main-worktree>" status --porcelain
git -C "<main-worktree>" fetch origin
git -C "<main-worktree>" merge --ff-only origin/main
git -C "<main-worktree>" rev-parse HEAD
git rev-parse origin/main
```

The two revision values must match. If local `main` has uncommitted changes or has diverged from `origin/main`, stop and report the situation. Do not reset, discard, stash without permission, or overwrite local work. Do not report that local `main` was updated merely because `git fetch origin` ran.

### 8. Clean up the Paseo workspace and Git worktree

Identify the workspace and worktree associated with the completed issue:

```bash
paseo workspace ls --json
git worktree list --porcelain
```

Inspect the worktree before removing or archiving it:

```bash
git -C "<worktree>" status --porcelain --untracked-files=all
git -C "<worktree>" status --ignored --short
```

Before cleanup, verify all of the following:

- The intended changes were merged.
- No uncommitted changes remain.
- No meaningful untracked or ignored local artifact would be lost.
- No unrelated active agent session depends on the workspace.

Prefer the workspace manager used to create the workspace:

```bash
paseo workspace archive <workspace-id>
```

The installed Paseo version inspected for this procedure is `0.17.3`. In that version, archiving a Paseo-owned worktree workspace stops and archives its owned agents and terminals, removes the Paseo-owned worktree directory when no other active workspace references it, and does not delete the Git branch. Verify `paseo --version` and the archive behavior for a different installed version before relying on it. Do not assume that archiving alone removed the worktree or the branch.

For a manually created worktree, or when archiving did not remove the directory:

```bash
git worktree remove <path>
git worktree prune
```

After the operation, verify the actual result:

```bash
paseo workspace ls --json
git worktree list --porcelain
if [ -d "<worktree>" ]; then
    echo "worktree still present; inspect it or remove it manually"
fi
```

If the directory is still present after archiving, inspect it before deciding whether to remove it manually. A retained directory is not automatically a failure; uncommitted or local-only content is a reason to retain it.

If cleanup cannot be completed safely, retain the workspace and the worktree and report the reason. Do not delete a worktree with uncommitted changes or meaningful local artifacts.

### 9. Delete the merged local branch

After the worktree has been removed or detached, check the local branch:

```bash
git branch --list <branch>
git branch --contains <branch>
```

Confirm that the branch's intended commits are included in the merged history:

```bash
git fetch origin --prune
git merge-base --is-ancestor <branch> origin/main
```

Delete it with the safe form:

```bash
git branch -d <branch>
```

`git branch -d` refuses to delete a branch whose commits are not merged. Do not use `-D` or otherwise force-delete a branch that has not been merged. Do not assume that the GitHub CLI merge command deleted every local branch in a multi-worktree environment; the branch may still exist precisely because another worktree had it checked out.

### 10. Record completion

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

Cleanup must be safe and idempotent. Repeating an already completed step must not delete different work or report a misleading failure. Do not leave an issue open merely because a follow-up exists; link the follow-up explicitly.

## Required outputs

- Merged PR with the expected merge commit.
- A recorded documentation freshness review.
- Verified `origin/main` state and linked issue state.
- Verified remote branch deletion or a recorded reason for retention.
- Local `main` synchronized with `origin/main`, or a recorded blocked reason.
- Removed or archived workspace and worktree when safe, or a recorded reason for retention.
- Deleted merged local branch when safe, or a recorded reason for retention.
- Follow-up issues for deferred non-blocking work.

## Exit criteria

- The merge result is verified on the default branch.
- The reviewed implementation and any documentation-only delta are recorded accurately.
- The documentation freshness review is recorded, and affected documentation is updated.
- Documentation validation and the required CI result apply to the final head.
- The issue state matches the actual outcome.
- Remote and local branches are cleaned up when safe, or explicitly retained with a reason.
- Local `main` is synchronized with `origin/main`, or the blocked condition is reported.
- The workspace and worktree are cleaned up when safe, or explicitly retained with a reason.
- No unreviewed change or dirty worktree remains.
- The final completion report records the state required by this document.

## Prohibited actions

- Merging before required checks pass on the final head.
- Merging a head that differs from the verified head, or omitting `--match-head-commit` without a recorded reason.
- Treating a documentation-only commit as a documentation-only pull request for CI purposes.
- Recording a documentation-only delta without inspecting the complete approved-to-final diff.
- Reclassifying a substantive policy, contract, security, or quality-gate change as harmless because its file extension is `.md`.
- Skipping required code review after production code, executable configuration, dependencies, tests, or quality-gate policy changed.
- A merge strategy that differs from [GitHub operations](github-operations.md), force pushes, or branch-protection bypasses.
- Deleting a worktree with uncommitted changes or meaningful local artifacts.
- Deleting an unmerged local branch, an unrelated branch, or an external contributor's branch.
- Reporting `git fetch origin` as synchronization of local `main`.
- Using `git reset --hard`, `git clean`, or another destructive command to make cleanup succeed.
- Closing an issue without recording how the work was resolved.
- Claiming the merge, post-merge CI, or cleanup passed without verifying it.
- Changing merge strategy, branch protection, repository visibility, licensing, or approval requirements without explicit maintainer authorization.

## References

- [Development workflow](development-workflow.md) for the overall sequence.
- [Pull request](pull-request.md) for PR preparation and final-head evidence.
- [Code review](code-review.md) and [review remediation](review-remediation.md) for review evidence and the documentation-only exception.
- [GitHub operations](github-operations.md) for merge strategy, branch protection, and repository settings.
- [Issue tracker](issue-tracker.md) for issue closure.
- [Workspace](workspace.md) for worktree creation and ownership.
- GitHub CLI: [`gh pr merge`](https://cli.github.com/manual/gh_pr_merge).
- GitHub: [troubleshooting required status checks](https://docs.github.com/en/pull-requests/how-tos/merge-and-close-pull-requests/troubleshooting-required-status-checks).
- Git: [worktree](https://git-scm.com/docs/git-worktree), [pull](https://git-scm.com/docs/git-pull), and [branch](https://git-scm.com/docs/git-branch).
