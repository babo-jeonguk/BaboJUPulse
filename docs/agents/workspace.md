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

### 1. Run the workspace preflight

From the source checkout:

```bash
scripts/workflow/workspace.sh prepare \
  --issue <number> \
  --branch <type>/<short-name> \
  --slug <short-name>
```

The script verifies the GitHub repository, reads the issue and its readiness label, refreshes `origin/main`, captures the base SHA, and detects an existing local branch, remote branch, or worktree. It is read-only and never creates a workspace. It prints:

- `base_sha`, `branch`, `slug`, and `mode`
- `action=create`, `action=reuse`, or `action=attach`
- any existing worktree and Paseo workspace
- whether the existing worktree is clean

Use `--repository <owner/name>` when the working copy's remote is not the target repository. If the script reports `action=reuse`, stop: use the existing workspace instead of creating a duplicate. If it reports a dirty worktree, inspect and preserve the content before continuing.

A shell script does not have direct access to an agent's Paseo MCP tools. The script performs the deterministic preflight and produces the parameters; the agent performs the workspace operation. The preflight requires `jq` for Paseo JSON parsing and fails explicitly when it is unavailable.

### 2. Create or reuse the Paseo workspace

Prefer the Paseo MCP workspace operation exposed by the installed Paseo daemon. Pass the repository, issue, `origin/main` base, branch, slug, and worktree isolation from the preflight output. Do not invent MCP tool names or arguments; inspect the available tools for the installed version.

When the session exposes only the Paseo CLI, the verified command is:

```bash
paseo workspace create \
  --isolation worktree \
  --mode branch-off \
  --new-branch <type>/<short-name> \
  --worktree-slug <short-name> \
  --base origin/main \
  --title "Issue #<number>: <title>" \
  --path <source-checkout>
```

Use `--mode checkout-branch --branch <name>` when the preflight reported `action=attach`. When it reported `requires_tracking_branch=yes`, create the local tracking branch before attaching the workspace.

The installed Paseo version inspected for this procedure is `0.17.3`. Re-check `paseo --version` and the official [worktree documentation](https://paseo.sh/docs/worktrees) before relying on a command from another version. A plain Git worktree is an acceptable fallback when Paseo is unavailable:

```bash
git worktree add ../BaboJUPulse-<short-name> -b <type>/<short-name> origin/main
```

Paseo is an internal convenience. External contributors are not required to use it.

### 3. Verify the workspace

From the new worktree:

```bash
scripts/workflow/workspace.sh verify \
  --issue <number> \
  --branch <type>/<short-name> \
  --base <base-sha>
```

The script verifies the worktree root, repository, branch, base ancestry, current `origin/main` ancestry, and a clean working tree. If it fails, fix the workspace state; do not begin implementation on a worktree that does not correspond to the issue.

Record the issue number, branch name, and base commit in the issue. These are shareable and self-contained. Keep the actual local worktree path, Paseo workspace identifier, session information, and other machine-specific details in private local working notes, not in published issue text. A bare `.scratch/` convention mention is allowed; a concrete artifact below it is not. Do not create a separate workspace report.

Run the environment setup appropriate to the platform from [Development](../development.md#first-setup) before editing.

### 4. Keep the branch current

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
- No separate workspace report.

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
- Creating a workspace report or other artifact that only restates Git or Paseo state.

## References

- [Development workflow](development-workflow.md) for the overall sequence.
- [Issue tracker](issue-tracker.md) and [triage labels](triage-labels.md) for readiness.
- [Implementation](implementation.md) for the next stage.
- [PR merge](pr-merge.md) for cleanup rules.
- [Development](../development.md) for setup, build, test, and workflow-script commands.
- [GitHub operations](github-operations.md#artifact-ownership) for the information-location model.
- Paseo documentation: [Git worktrees](https://paseo.sh/docs/worktrees) and [parallel development](https://paseo.sh/docs/parallel-development).
