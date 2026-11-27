# GitHub operations

Authoritative for repository operations and external publication. It does not define code quality ([CODING_STANDARDS.md](../../CODING_STANDARDS.md)) or verification policy ([quality-gates.md](quality-gates.md)).

## Repository

- Target repository: `babo-jeonguk/BaboJUPulse`. Confirm with `gh repo view --json nameWithOwner` before creating an issue or PR. Do not file into another repository.
- The repository is public and MIT-licensed. Treat every issue, PR, comment, review, commit, and tracked file as publishable.
- Do not create GitHub Projects boards, roadmap artifacts, releases, or tags unless the task explicitly asks for them.

## Issues

- Use the `gh` CLI. Search existing issues before creating a new one.
- One issue per coherent unit of work. Do not split or merge work arbitrarily.
- Use only labels that exist in the repository. The templates apply `needs-triage` plus a category label.
- Issue content follows the publication policy below.

## Branches and commits

- Branch from `main`:
  - `feat/<short-name>` for a capability.
  - `fix/<short-name>` for a defect.
  - `docs/<short-name>` for documentation or repository configuration.
- Commit messages follow Conventional Commits: `<type>: <subject>`.
  - Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `style`, `ci`, `perf`, `revert`.
  - Subject is at most 50 characters, imperative, with no trailing period.
  - Add a body only when the reason is not obvious from the subject.
- The local `.githooks/commit-msg` hook checks the format, the subject length, and the publication policy. It is **local-only**: it runs in clones that configured `core.hooksPath`, and a contributor can bypass it with `--no-verify`. It is not a server-side guarantee. Do not bypass it; fix the message.
- CI does not currently validate the Conventional Commits format. Public-content checks do run in CI.

## Pull requests and merge

- Open a PR with the repository template. Keep the body self-contained:
  - `Summary`: what changed and why, linked to the issue when one exists.
  - `Evidence`: final commit SHA, commands or CI run links, results, and what was not verified.
  - `Risk`: blast radius and rollback.
- The required status check is `build` on `windows-latest`. It runs restore/audit, formatting, build, tests, repository-policy checks, and public-content checks.
- CodeQL and dependency review are advisory checks, not required by branch protection.
- Merge with a merge commit. Squash and rebase merges are disabled; head branches are deleted after merge. Auto-merge is enabled.
- Required approvals are `0` because the repository has one maintainer. Administrators are subject to branch protection.
- Do not change merge strategy, repository visibility, licensing, approval requirements, or branch protection without explicit maintainer authorization.

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
- Local absolute paths.
- Agent session URLs, session IDs, or local session paths.
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

- **Before posting** an issue, PR body, comment, or review, pipe the exact text through:

  ```bash
  bash scripts/check-public-content.sh
  ```

  Run it from Git Bash, WSL, or another Bash environment. The checker rejects concrete `.scratch/` paths, local absolute paths, and obvious credential patterns. It accepts bare `.scratch/` convention mentions.
- The local commit hook runs the same checker on commit messages.
- CI checks the PR title and body, PR commit messages, all tracked text files, and the synthetic checker tests. It is merge-blocking, but it runs **after** the PR content is already visible. It cannot prevent initial disclosure in a PR.
- Tracked Markdown links are checked against Git's actual ignore rules. The publication checker targets the designated `.scratch/` workspace and local absolute paths, not every ignored build output such as `bin/` or `obj/`.
- Issue and comment publication has no server-side pre-publication guard. The local checker is the practical control; review and edit before posting.
- GitHub secret scanning and push protection cover known secret formats, not local paths or private context.
- If prohibited content is published, edit or delete it and rotate any exposed credential. Do not assume deletion removes every copy or cache.

## GitHub enforcement and limits

- `main` requires a pull request, the `build` check, an up-to-date branch, and resolved conversations. Force pushes and deletions are blocked; administrators are included.
- Secret scanning and push protection are enabled. Dependabot alerts and security updates are enabled. Private vulnerability reporting is enabled through [SECURITY.md](../../SECURITY.md).
- Secret scanning non-provider patterns and validity checks are unavailable on the current plan.
- The default Actions token is read-only. All Actions are allowed, and commit-SHA pinning is not enforced; workflows use major version tags and Dependabot updates them weekly.
- Local hooks and agent instructions are not server-side enforcement. A rule that must hold for every contributor belongs in CI or branch protection.
