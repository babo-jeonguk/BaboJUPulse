# GitHub operations

Authoritative for repository operations and external publication. It does not define code quality ([CODING_STANDARDS.md](../../CODING_STANDARDS.md)) or verification policy ([quality-gates.md](quality-gates.md)).

## Repository

- Target repository: `babo-jeonguk/BaboJUPulse`. Confirm with `gh repo view --json nameWithOwner` before creating an issue or PR. Do not file into another repository.
- The repository is public and MIT-licensed. Treat every issue, PR, comment, review, commit, and tracked file as publishable.
- Do not create GitHub Projects boards, roadmap artifacts, releases, or tags unless the task explicitly asks for them.

## Issues

- Use the `gh` CLI. Search existing issues before creating a new one.
- Issue creation, triage, readiness, and closure are owned by [Issue tracker](issue-tracker.md); label meanings and category cardinality are owned by [Triage labels](triage-labels.md).
- One issue per coherent unit of work. Do not split or merge work arbitrarily.
- A new issue starts in `needs-triage`. A completed template is not implementation-ready; triage establishes readiness.
- Use only labels that exist in the repository.
- Issue content follows the publication policy below.

## Branches and commits

- Branch from `main`:
  - `feat/<short-name>` for a capability.
  - `fix/<short-name>` for a defect.
  - `docs/<short-name>` for documentation.
  - `chore/<short-name>` for maintenance, tooling, or repository configuration.
  - `test/<short-name>` for test-only work.
- Commit messages follow Conventional Commits: `<type>: <subject>`.
  - Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `style`, `ci`, `perf`, `revert`.
  - Subject is at most 50 characters, imperative, with no trailing period.
  - Add a body only when the reason is not obvious from the subject.
- The local `.githooks/commit-msg` hook checks the format, the subject length, and the publication policy. It is **local-only**: it runs in clones that configured `core.hooksPath`, and a contributor can bypass it with `--no-verify`. It is not a server-side guarantee. Do not bypass it; fix the message.
- CI does not currently validate the Conventional Commits format. Public-content checks do run in CI.

## Pull requests and merge

- PR preparation, template use, evidence, and CI verification are owned by [Pull request](pull-request.md). Merge preconditions, documentation freshness, and cleanup are owned by [PR merge](pr-merge.md).
- Keep the body self-contained: linked issue, smallest-sufficient Summary, acceptance-criteria coverage, exact reviewed implementation commit, final head, any documentation-only delta, review outcome, actual verification, unverified behavior, documentation review, and Merge Danger. Do not fabricate a result for a check that did not run.
- The required status check is `build` on `windows-latest`. It runs restore/audit, formatting, build, tests, repository-policy checks, and public-content checks. The `pull_request` trigger includes `edited`, so a title or body edit is revalidated by CI.
- The separate `documentation` workflow runs lightweight documentation validation on every pull request and push to `main`. It is not a branch-protection required check; the merge procedure requires its result on the final head. Do not add path filters that could leave a required check pending.
- CodeQL and dependency review are advisory checks, not required by branch protection.
- Merge with a merge commit. Squash and rebase merges are disabled; head branches are deleted after merge. Auto-merge is enabled. Use `scripts/workflow/merge.sh` with the explicit verified final SHA. The script passes that original SHA to `--match-head-commit`; never substitute a value fetched immediately before merging.
- Required approvals are `0` because the repository has one maintainer. Administrators are subject to branch protection.
- Do not change merge strategy, repository visibility, licensing, approval requirements, required checks, or branch protection without explicit maintainer authorization.
- Local `main`, remote branches, and worktrees are synchronized and cleaned up after merge by [PR merge](pr-merge.md) and `scripts/workflow/cleanup.sh`. The GitHub settings describe server-side branch deletion, not the complete local cleanup.
- Do not make a PR's review record depend on a local report or an inaccessible artifact.

## Artifact ownership

Git, GitHub, Paseo, and the project's authoritative documents are the durable engineering record. A workflow stage should update the owner of its information instead of producing a parallel report.

| Information | Authoritative location |
| --- | --- |
| Problem, scope, requirements, acceptance criteria, and implementation slices | GitHub issue |
| Research findings and task-specific technical conclusions | GitHub issue or an appropriate ADR |
| Established domain terminology | [GLOSSARY.md](../../GLOSSARY.md) |
| Consequential architectural decisions | [ADRs](../adr/) |
| Actual implementation | Git commits |
| Regression protection | Test code |
| Final review decision and relevant review evidence | GitHub pull request |
| CI results | GitHub Actions |
| Deferred actionable work | Follow-up GitHub issue |
| Workspace and branch state | Actual Git and Paseo state |
| Temporary agent-to-agent handoff | Agent session output, or a minimal local artifact when persistence is necessary |

Do not create a document that only reproduces information already available from Git, GitHub, Paseo, or an existing authoritative document. In particular:

- Do not create a workspace report for a branch and worktree that can be queried directly.
- Do not create a separate implementation plan when the issue already carries a sufficient specification and slice breakdown.
- Do not create a standalone implementation report when commits, acceptance-criteria evidence, and the handoff output are sufficient.
- Do not add a tracked development report for every completed issue.

The pull request remains the durable review record even when a reviewer used a local report. Its review section must be understandable without any temporary file.

## Temporary handoffs

Agent session output is the default mechanism for short-lived implementation and review handoffs. Use `.scratch/` only when a real coordination need requires persistence across sessions.

A temporary artifact must be minimal, task-specific, clearly disposable once its information has been transferred, and free from duplicated authoritative content. There is no required set of generated files for an issue.

Before workspace cleanup, move any information needed to understand, verify, maintain, or continue the work into its durable location: the issue, PR, glossary, ADR, commit, test, or tracked documentation. Do not require a local artifact after the worktree is removed.

Raw local artifacts, private working notes, machine-specific paths, workspace identifiers, and sensitive information must not be published.

## Public communication

Published content must be understandable and verifiable without access to a particular developer's machine.

Allowed evidence:

- Tracked repository files and documentation.
- Issues and pull requests.
- Commit SHAs and CI run results.
- Public external references.
- Self-contained technical explanations, sanitized conclusions, and summaries derived from local work.

Do not publish:

- Credentials, tokens, cookies, account identifiers, or private provider data.
- Local absolute paths or local worktree paths.
- Paseo workspace identifiers, agent session URLs, session IDs, or local session paths.
- References to local-only working artifacts or inaccessible local files.
- Raw private logs, unredacted provider responses, or local configuration.
- Claims about behavior, tests, or CI that were not actually verified.

## Local-only artifacts

`.scratch/` is the designated local workspace and is Git-ignored. Ordinary build outputs such as `bin/` and `obj/` are not private working artifacts, but do not link to them in published content either.

- Do not reference a concrete file under `.scratch/` in an issue, PR, comment, review, commit message, tracked Markdown file, or source-code comment.
- A bare convention mention is allowed: `The .scratch/ directory is local-only.` A reference to a particular artifact below it is not.
- Do not copy raw local artifacts into GitHub or attach them to GitHub merely because Git ignores the originals.
- Do not publish local absolute paths or links that only work on one machine.
- If local work contains durable knowledge, extract the conclusion into a tracked document, ADR, issue, or test with enough context to stand alone. Do not simply link to the local artifact.

## Publication checks

- **Before posting** an issue or PR, check the title and body together. For a comment or review, check the exact text.

  ```bash
  { printf '%s\n\n' "<title>"; cat "<body-file>"; } \
    | bash scripts/check-public-content.sh
  ```

  Run it from Git Bash, WSL, or another Bash environment. The checker rejects concrete `.scratch/` paths, local absolute paths, file URLs, obvious credential formats, and private keys. It accepts bare `.scratch/` convention mentions.
- Checker failure output is redacted. It reports a rule identifier, a safe file label, and a line number. It never prints the matching secret, raw prohibited text, or a local absolute path from the input. Use the reported line to fix the text locally.
- The local commit hook runs the same checker on commit messages.
- CI checks the PR title and body, PR commit messages, all tracked text files, and the synthetic checker tests. It is merge-blocking, but it runs **after** the PR content is already visible. It is post-publication detection, not prevention of initial disclosure.
- The `pull_request` trigger includes `edited`, so a changed PR title or body is revalidated. Run the local checker before editing; do not rely on CI to protect the first visible version.
- Tracked Markdown links, heading fragments, and local-only targets are checked by [documentation validation](../development.md#documentation-validation). The publication checker targets the designated `.scratch/` workspace and local absolute paths, not every ignored build output such as `bin/` or `obj/`.
- A documentation-only follow-up still requires the documentation workflow and the full `build` check to pass on the final head. Do not describe a documentation-only pull request as exempt from code CI when it also contains a reviewed implementation.
- Issue and comment publication has no server-side pre-publication guard. The local checker is the practical control; review and edit before posting.
- GitHub secret scanning and push protection cover known secret formats, not local paths or private context.
- If prohibited content is published, edit or delete it and rotate any exposed credential. Do not assume deletion removes every copy or cache.

## GitHub enforcement and limits

- `main` requires a pull request, the `build` check, an up-to-date branch, and resolved conversations. Force pushes and deletions are blocked; administrators are included.
- The separate `documentation` workflow runs on every pull request and push to `main` but is not required by branch protection until the maintainer changes that setting. The merge procedure still requires its final-head result.
- Secret scanning and push protection are enabled. Dependabot alerts and security updates are enabled. Private vulnerability reporting is enabled through [SECURITY.md](../../SECURITY.md).
- Secret scanning non-provider patterns and validity checks are unavailable on the current plan.
- The default Actions token is read-only. All Actions are allowed, and commit-SHA pinning is not enforced; workflows use major version tags and Dependabot updates them weekly.
- Local hooks and agent instructions are not server-side enforcement. A rule that must hold for every contributor belongs in CI or branch protection.
- A repository-controlled checker is not tamper-proof. An actor who can edit both the content and the checker can weaken both; maintainer review and the separation between implementation and approval are the practical boundary. Do not claim complete tamper resistance or complete prevention of disclosure.
