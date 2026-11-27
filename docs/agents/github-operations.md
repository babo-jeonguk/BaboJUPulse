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

- PR preparation, template use, evidence, and CI verification are owned by [Pull request](pull-request.md). Merge preconditions and cleanup are owned by [PR merge](pr-merge.md).
- `gh pr create --template` pre-fills from the named file; `--body` overrides it, and API-based creation does not populate repository templates. Start from [`.github/PULL_REQUEST_TEMPLATE.md`](../../.github/PULL_REQUEST_TEMPLATE.md) explicitly.
- Keep the body self-contained: linked issue, acceptance-criteria coverage, exact reviewed commit SHA, review outcome, actual verification, unverified behavior, risk, and rollback. Do not fabricate a result for a check that did not run.
- The required status check is `build` on `windows-latest`. It runs restore/audit, formatting, build, tests, repository-policy checks, and public-content checks. The `pull_request` trigger includes `edited`, so a title or body edit is revalidated by CI.
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

  Run it from Git Bash, WSL, or another Bash environment. The checker rejects concrete `.scratch/` paths, local absolute paths, file URLs, obvious credential formats, and private keys. It accepts bare `.scratch/` convention mentions.
- Checker failure output is redacted. It reports a rule identifier, a safe file label, and a line number. It never prints the matching secret, raw prohibited text, or a local absolute path from the input. Use the reported line to fix the text locally.
- The local commit hook runs the same checker on commit messages.
- CI checks the PR title and body, PR commit messages, all tracked text files, and the synthetic checker tests. It is merge-blocking, but it runs **after** the PR content is already visible. It is post-publication detection, not prevention of initial disclosure.
- The `pull_request` trigger includes `edited`, so a changed PR title or body is revalidated. Run the local checker before editing; do not rely on CI to protect the first visible version.
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
- A repository-controlled checker is not tamper-proof. An actor who can edit both the content and the checker can weaken both; maintainer review and the separation between implementation and approval are the practical boundary. Do not claim complete tamper resistance or complete prevention of disclosure.
