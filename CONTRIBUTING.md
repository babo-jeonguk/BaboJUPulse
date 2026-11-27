# Contributing to BaboJUPulse

Thanks for taking the time to improve BaboJUPulse. The project is currently a foundation build: the WPF host, engineering rules, and CI exist, but the tray and taskbar product features do not. Small, well-scoped contributions are easiest to review.

## Before you start

- Search existing issues and pull requests so you do not duplicate work.
- Open or find an issue for every pull request. A defect fix can use a short issue with the reproduction; a new capability or cross-cutting change needs a fuller specification.
- Treat the issue as the agreement on behavior. If the requirement is unclear, ask before writing the implementation.
- Do not report a vulnerability in a public issue. Follow [SECURITY.md](SECURITY.md).

## Find a contribution opportunity

Look for issues labeled `good first issue` or `help wanted`. Comment on the issue before starting so the maintainer can confirm the scope and avoid duplicate work. Issues labeled `ready-for-agent` or `ready-for-human` have completed triage; they are not necessarily beginner-friendly.

The product scope and non-goals are in [docs/product-scope.md](docs/product-scope.md). Do not add a dashboard, a cross-platform UI, or an unrequested provider capability.

## Report a bug or request a feature

Use the repository issue templates:

- **Bug report** for broken or regressed behavior. Include the version or commit, Windows version, the smallest reproduction, and sanitized evidence. Say whether it is a regression and, if known, the last working version.
- **Feature request** for a user problem or desired capability. Describe the problem and benefit; an architectural design is not required.
- **Technical research** when the question needs evidence or a comparison before implementation.

Redact logs and screenshots before attaching them. Do not include credentials, tokens, account identifiers, raw provider responses, local absolute paths, or references to local-only working artifacts.

## Fork, clone, and branch

Fork the repository and clone your fork:

```bash
gh repo fork babo-jeonguk/BaboJUPulse --clone
cd BaboJUPulse
git remote -v
git fetch upstream
git checkout -b fix/<short-name> upstream/main
```

`gh repo fork --clone` normally configures `upstream` as the project repository. If `git remote -v` does not show it, add `https://github.com/babo-jeonguk/BaboJUPulse.git` as `upstream` before fetching.

Use `feat/`, `fix/`, `docs/`, or another clear descriptive prefix. Keep one coherent change per branch. Do not commit directly to `main` in the upstream repository.

## Set up the environment

Follow [docs/development.md](docs/development.md) for prerequisites and commands. The short version:

```powershell
./scripts/setup-dev.ps1
dotnet build BaboJUPulse.slnx -c Release
```

WSL and Linux can compile the Windows-targeted projects, but the WPF executable only runs on Windows. Runtime checks require Windows.

## Follow the project standards

Read [CODING_STANDARDS.md](CODING_STANDARDS.md) before changing code. In particular:

- Do not add unrequested product features or unrelated refactors.
- Do not suppress a diagnostic, weaken a quality gate, or change analyzer configuration. A narrow exception needs maintainer approval under [Quality gates](docs/agents/quality-gates.md).
- Do not use the null-forgiving operator. Fix the nullability model with explicit checks or a sound contract.
- Keep secrets and private data out of source, tests, logs, commits, issues, and pull requests.
- Do not use a local absolute path or a reference to a local-only artifact in published content.

## Run validation

Run the checks in [docs/development.md](docs/development.md#quality-gates) before opening a pull request. The standard set is:

```bash
dotnet restore BaboJUPulse.slnx
dotnet format BaboJUPulse.slnx --verify-no-changes --no-restore
dotnet build BaboJUPulse.slnx -c Release --no-restore -warnaserror
dotnet test BaboJUPulse.slnx -c Release --no-build
bash scripts/test-public-content.sh
bash scripts/check-public-content.sh --tracked
```

If you changed documentation, also run:

```bash
bash scripts/test-check-documentation.sh
bash scripts/check-documentation.sh
```

A successful build is not proof of Windows runtime behavior. State what you actually verified and what you could not verify.

## Tests

Behavior changes need tests. A bug fix needs a regression test that fails before the fix. A new behavior needs its success path and important failure path covered. Tests must be deterministic: do not depend on machine load, a GPU, network access, locale, or wall-clock time.

## Submit a pull request

Keep the pull request focused on its issue and link the issue with a closing keyword such as `Closes #123`. Start from the repository template at [.github/PULL_REQUEST_TEMPLATE.md](.github/PULL_REQUEST_TEMPLATE.md).

The default procedure copies the template to a body file, fills it in, checks it, and creates the PR:

```bash
cp .github/PULL_REQUEST_TEMPLATE.md "<body-file>"
# Edit the body file on your machine.
{ printf '%s\n\n' "<type>: <subject>"; cat "<body-file>"; } \
  | bash scripts/check-public-content.sh
gh pr create --title "<type>: <subject>" --body-file "<body-file>" --base main
```

Interactive `gh pr create --template .github/PULL_REQUEST_TEMPLATE.md` is acceptable only if you save the completed body and run the checker before submitting. `gh pr create --body` overrides `--template`, and API-based creation does not populate repository templates. Fill in the actual evidence; do not leave placeholder claims. Use "not applicable" or "unverified" when a check does not apply or did not run.

Use a Summary that shows the shape of the change with the smallest clear representation, then keep the detailed evidence in the other sections. The Merge Danger section classifies the change as a two-way or one-way door and records blast radius, failure scenarios, mitigation, and rollback. For a one-way door, explain why a Git revert is insufficient and ask the maintainer before merging.

The required CI check is `build` on `windows-latest`. A separate `documentation` workflow validates documentation and runs on every pull request. CodeQL and dependency review are advisory unless the maintainer says otherwise. A later documentation-only commit does not skip the required build or documentation checks.

## Review and remediation

A maintainer reviews the change against the issue and the repository rules. Address blocking findings with code changes and evidence, then push a new commit. Approval of an earlier commit does not cover later changes; the reviewer must approve the current head unless the only later change is an ordinary documentation update recorded under the internal documentation-only exception. Production code, executable configuration, tests, dependencies, quality gates, and substantive policy changes always return to review.

If you disagree with a finding, explain it with evidence and ask for a decision. Do not weaken a gate or rewrite the acceptance criteria to make the change pass. The internal review and remediation process is described in [Code review](docs/agents/code-review.md) and [Review remediation](docs/agents/review-remediation.md); external contributors only need the outcome.

## Privacy and local-only artifacts

- Never commit or publish credentials, tokens, cookies, account identifiers, machine names, or local absolute paths.
- Redact logs and provider responses before sharing them.
- Keep local notes in the Git-ignored `.scratch/` directory. Do not link to a concrete artifact below it in an issue, pull request, commit, or tracked document. A bare mention of the `.scratch/` convention is fine.
- If local investigation produced durable knowledge, put the conclusion in a tracked document, issue, or test with enough context to stand alone.
- Report security problems privately through [SECURITY.md](SECURITY.md). Do not open a public issue for them.

## Licensing

BaboJUPulse is MIT-licensed. By contributing, you agree that your contribution is provided under the same [MIT license](LICENSE). No contributor license agreement is required.

## Workflow freedom

Use the editor, IDE, operating system, and local workflow you prefer. Paseo and the repository's internal agent orchestration are not required for external contributions. Your change needs to satisfy the project's tests, standards, and review requirements, not a particular toolchain.
