# Workspace

Authoritative for preparing an isolated worktree and branch for one issue. It does not own build commands ([Development](../development.md)), issue readiness ([Issue tracker](issue-tracker.md)), or merge cleanup ([PR merge](pr-merge.md)).

## Purpose

Keep each issue's changes isolated, reproducible, and easy to review. The default relationship is **one issue → one worktree → one branch → one pull request**.

## Required inputs

- A ready issue with a number, title, and acceptance criteria.
- The repository owner and name, confirmed with `gh repo view --json nameWithOwner`.
- A fetched, current `origin/main`.
- A short branch description and worktree slug.

## Entry criteria

- The issue is `ready-for-agent` or `ready-for-human`, or a maintainer authorized an exception and recorded it in the issue.
- The working tree is not being reused for unrelated unfinished work.
- The contributor has permission to push a branch to the appropriate repository or fork.

## Procedure

### 1. Verify the repository and base

```bash
git remote -v
gh repo view --json nameWithOwner
git fetch origin
git rev-parse origin/main
```

Do not create the branch from a stale local `main`. Use `origin/main` explicitly.

### 2. Reuse a matching workspace when possible

Before creating a new one, inspect the existing workspaces, worktrees, and branches:

```bash
paseo workspace ls
git worktree list
git branch --all
```

Reuse a workspace only when its repository, branch, base, and issue match. Do not attach a second issue to an in-progress branch merely because it is open.

### 3. Create the worktree and branch

The installed Paseo CLI version inspected for this procedure is `0.17.3`. Re-check `paseo --version` and the official [worktree documentation](https://paseo.sh/docs/worktrees) before relying on a command from a different version.

From the source checkout:

```bash
paseo workspace create \
  --isolation worktree \
  --mode branch-off \
  --new-branch <type>/<short-name> \
  --worktree-slug <short-name> \
  --base origin/main
```

Use `--path <source-checkout>` when the command is not run from the checkout. Prefer `origin/main`, not local `main`; Paseo fetches remote refs in the background and the remote-tracking ref names the intended base.

A plain Git worktree is equivalent when Paseo is unavailable or the contributor prefers another tool:

```bash
git worktree add ../BaboJUPulse-<short-name> -b <type>/<short-name> origin/main
```

Paseo is an internal convenience. External contributors are not required to use it.

### 4. Verify the workspace

```bash
git rev-parse --show-toplevel
git branch --show-current
git merge-base --is-ancestor origin/main HEAD
git status --short
```

Record the issue number, branch name, and base commit in the issue. These are shareable and self-contained. Keep the actual local worktree path, Paseo workspace identifier, session information, and other machine-specific details in private local working notes, not in published issue text. A bare `.scratch/` convention mention is allowed; a concrete artifact below it is not.

Run the environment setup appropriate to the platform from [Development](../development.md#first-setup) before editing.

### 5. Keep the branch current

Update the branch by merging `origin/main` when required by branch protection or when the base has changed materially:

```bash
git fetch origin
git merge origin/main
```

Do not rewrite reviewed history with a force push. If a merge changes behavior or creates conflicts, resolve them and repeat the affected verification and review.

## Required outputs

- An isolated worktree directory.
- A branch based on `origin/main`.
- The issue number, branch name, and base commit recorded in the issue with only shareable identifiers.
- Local worktree paths and workspace or session identifiers kept in private local notes.
- A clean starting status, or an explicit note about pre-existing changes.

## Exit criteria

- The branch and worktree correspond to the correct repository and issue.
- The branch is based on current `origin/main`.
- The workspace is clean enough to distinguish this issue's changes.
- Setup and restore are complete for the platform.

## Prohibited actions

- Editing or committing on `main`.
- Branching from a stale local `main` or an unrelated feature branch.
- Creating a duplicate workspace for an issue that already has a matching one.
- Mixing unrelated issues in one branch without maintainer agreement.
- Copying credentials, private logs, or local-only artifacts into the worktree.
- Publishing a local worktree path, workspace identifier, or session detail in an issue.
- Deleting a worktree that contains uncommitted changes or artifacts that still need to be preserved.
- Requiring Paseo or internal agent orchestration for an external contribution.

## References

- [Development workflow](development-workflow.md) for the overall sequence.
- [Issue tracker](issue-tracker.md) and [triage labels](triage-labels.md) for readiness.
- [Implementation](implementation.md) for the next stage.
- [PR merge](pr-merge.md) for cleanup rules.
- [Development](../development.md) for setup, build, and test commands.
- Paseo documentation: [Git worktrees](https://paseo.sh/docs/worktrees) and [parallel development](https://paseo.sh/docs/parallel-development).
