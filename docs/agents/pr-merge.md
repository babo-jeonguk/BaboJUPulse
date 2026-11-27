# Pull request merge and cleanup

Authoritative for the final merge, post-merge verification, and workspace cleanup. PR preparation lives in [Pull request](pull-request.md); merge strategy and branch protection remain in [GitHub operations](github-operations.md).

## Purpose

Merge only a reviewed, verified, mergeable change, then confirm the result on `main` and clean up safely.

## Required inputs

- An open PR linked to the issue.
- The exact reviewed commit SHA and review decision.
- The required CI result for the current head.
- The issue acceptance criteria and any recorded limitations.
- Access to merge and delete the branch.

## Entry criteria

All of the following are true:

- The issue's acceptance criteria are satisfied or explicitly deferred by maintainer decision.
- Every blocking review finding is resolved.
- Required `build` checks pass on the current head.
- Relevant advisory security checks have been inspected.
- All required review conversations are resolved.
- The branch is mergeable and up to date as required by branch protection.
- The reviewed SHA matches the current head, or a later review covers the difference.

## Procedure

### 1. Reconfirm the reviewed state

```bash
gh pr view <number> --json number,title,state,headRefOid,baseRefName,mergeable,reviewDecision,statusCheckRollup
git rev-parse HEAD
```

If the head SHA differs from the reviewed SHA, do not merge. Return to [Code review](code-review.md) for the new head and rerun affected verification.

### 2. Inspect checks and security signals

- Confirm the required `build` check succeeded on the current head.
- Inspect CodeQL and dependency-review results when relevant. They are advisory unless the maintainer says otherwise, but a new security finding needs a decision before merge.
- Confirm no unresolved conversation or requested-change review remains.
- Confirm the branch is mergeable. If it is behind the base, update it, rerun affected checks, and re-review the new head.

### 3. Merge with the repository strategy

The repository uses merge commits. Squash and rebase merges are disabled. Preserve the existing strategy unless the maintainer explicitly authorizes a change.

```bash
gh pr merge <number> --merge --delete-branch
```

Do not bypass branch protection, force-push, or merge an unreviewed commit.

### 4. Verify the merge result

```bash
gh pr view <number> --json state,mergedAt,mergeCommit
git fetch origin
git log --oneline -5 origin/main
```

Confirm:

- The PR is merged with the expected merge commit.
- The changes are present on `origin/main`.
- The required CI result on `main` is green or explainable.
- The linked issue is closed. If GitHub did not close it, comment with the merge reference and close it manually.

### 5. Clean up the workspace

Inspect before deleting:

```bash
git status --porcelain
git worktree list
paseo workspace ls
```

Clean up only when the worktree has no uncommitted changes and no local artifacts that still need preservation. Prefer the workspace manager used to create it:

```bash
paseo workspace archive <workspace-id>
```

For a manually created worktree:

```bash
git worktree remove <path>
```

Never delete a worktree with uncommitted changes, untracked artifacts of value, or a branch that has not been merged.

### 6. Record completion

Update the issue with the merge commit and any follow-up issues for non-blocking findings or deferred work. Do not leave an issue open merely because a follow-up exists; link the follow-up explicitly.

## Required outputs

- Merged PR with the expected merge commit.
- Verified `origin/main` state.
- Closed linked issue, or a recorded reason it remains open.
- Removed or archived workspace when safe.
- Follow-up issues for deferred non-blocking work.

## Exit criteria

- The merge result is verified on the default branch.
- The issue state matches the actual outcome.
- The branch and worktree are cleaned up when safe, or explicitly retained with a reason.
- No unreviewed change remains on `main`.

## Prohibited actions

- Merging before required checks pass on the current head.
- Merging a head that differs from the reviewed commit.
- Squash or rebase merges, force pushes, or branch-protection bypasses.
- Deleting a worktree with uncommitted changes or meaningful local artifacts.
- Closing an issue without recording how the work was resolved.
- Claiming the merge or post-merge CI passed without verifying it.
- Changing merge strategy, branch protection, repository visibility, licensing, or approval requirements without explicit maintainer authorization.

## References

- [Development workflow](development-workflow.md) for the overall sequence.
- [Pull request](pull-request.md) for PR preparation.
- [Code review](code-review.md) and [review remediation](review-remediation.md) for review evidence.
- [GitHub operations](github-operations.md) for merge strategy, branch protection, and repository settings.
- [Issue tracker](issue-tracker.md) for issue closure.
- [Workspace](workspace.md) for worktree creation and ownership.
