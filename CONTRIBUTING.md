# Contributing to BaboJUPulse

Thanks for taking the time to improve BaboJUPulse. The project is currently a foundation build: the WPF host, engineering rules, and CI exist, but the tray and taskbar product features do not. Small, well-scoped contributions are easiest to review.

## Before you start

- Search existing issues and pull requests so you do not duplicate work.
- Open an issue before implementing a new capability, a cross-cutting change, or anything that changes the product scope. A defect fix with a clear reproduction can usually go straight to a pull request.
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
git remote add upstream https://github.com/babo-jeonguk/BaboJUPulse.git
git fetch upstream
git checkout -b fix/<short-name> upstream/main
```

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

A successful build is not proof of Windows runtime behavior. State what you actually verified and what you could not verify.

## Tests

Behavior changes need tests. A bug fix needs a regression test that fails before the fix. A new behavior needs its success path and important failure path covered. Tests must be deterministic: do not depend on machine load, a GPU, network access, locale, or wall-clock time.

## Submit a pull request

Keep the pull request focused on its issue and link the issue with a closing keyword such as `Closes #123`. Start from the repository template at [.github/PULL_REQUEST_TEMPLATE.md](.github/PULL_REQUEST_TEMPLATE.md).

Interactive:

```bash
gh pr create --template .github/PULL_REQUEST_TEMPLATE.md --base main
```

Non-interactive: copy the template, fill it in, and pass the body file:

```bash
cp .github/PULL_REQUEST_TEMPLATE.md "<body-file>"
# Edit the body file on your machine.
bash scripts/check-public-content.sh < "<body-file>"
gh pr create --title "<type>: <subject>" --body-file "<body-file>" --base main
```

`gh pr create --body` overrides `--template`, and API-based creation does not populate repository templates. Fill in the actual evidence; do not leave placeholder claims. Use "not applicable" or "unverified" when a check does not apply or did not run.

The required CI check is `build` on `windows-latest`. CodeQL and dependency review are advisory unless the maintainer says otherwise.

## Review and remediation

A maintainer reviews the change against the issue and the repository rules. Address blocking findings with code changes and evidence, then push a new commit. Approval of an earlier commit does not cover later changes; the reviewer must approve the current head.

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
