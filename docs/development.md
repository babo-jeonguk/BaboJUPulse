# Development

## Prerequisites

- Windows 10 version 2004 (build 19041) or later, or Windows 11.
- [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0). The repository pins `10.0.404` in `global.json`; newer patches in the same feature band are accepted.
- Git for Windows, or Git in WSL.
- Optional: Visual Studio 2022 17.14+ with the **.NET desktop development** workload, or JetBrains Rider.

Linux and WSL can compile the Windows-targeted projects because `EnableWindowsTargeting` is enabled. They cannot run the WPF executable. Runtime checks require Windows.

## First setup

Windows PowerShell:

```powershell
./scripts/setup-dev.ps1
```

WSL or Linux:

```bash
./scripts/setup-dev.sh
```

Both scripts set `core.hooksPath` to `.githooks` and restore the solution. The hook enforces Conventional Commits at commit time.

## Build and run

```powershell
dotnet build BaboJUPulse.slnx -c Release
dotnet run --project src/BaboJUPulse -c Release
```

The foundation build has no tray or taskbar host, so it exits immediately after startup. This is expected until the first host feature lands. The build is the current smoke test.

## Quality gates

Run these before opening a PR and after the final change:

```powershell
dotnet format BaboJUPulse.slnx --verify-no-changes --no-restore
dotnet build BaboJUPulse.slnx -c Release --no-restore -warnaserror
dotnet test BaboJUPulse.slnx -c Release --no-build
```

| Gate | What it proves |
| --- | --- |
| `dotnet format --verify-no-changes` | The tree matches `.editorconfig`; no formatting drift |
| `dotnet build -warnaserror` | Compiler, nullable, .NET analyzer, and code-style analyzer checks pass |
| `dotnet test` | Behavior and repository-invariant tests pass |

Do not run `dotnet format` without `--verify-no-changes` on unrelated files. If formatting is needed, format only the files you changed and review the diff.

## Tests

- `tests/BaboJUPulse.ArchitectureTests/` protects repository invariants: target framework, no startup window, quality-gate settings, relative documentation links, and `.scratch/` being ignored.
- Product tests belong in the layer that owns the behavior. Add a test project when the first product behavior exists; do not create a broad test pyramid in advance.
- A bug fix needs a regression test that fails before the fix.
- Tests must not depend on machine load, GPU presence, network access, locale, or wall-clock time.

Run one test class while iterating:

```powershell
dotnet test tests/BaboJUPulse.ArchitectureTests -c Release --filter FullyQualifiedName~ProjectConfigurationTests
```

## Branch and commit flow

- Open a GitHub Issue for the change. Keep the issue small enough to review as one unit.
- Branch from `main`:
  - `feat/<short-name>` for a capability.
  - `fix/<short-name>` for a defect.
  - `docs/<short-name>` for documentation or repository configuration.
- Commit with Conventional Commits:

  ```text
  <type>: <subject>
  ```

  Allowed types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `style`, `ci`, `perf`, `revert`. The subject is at most 50 characters and uses the imperative mood. Add a body only when the reason is not obvious from the subject.

- The `commit-msg` hook checks the format and subject length. Do not bypass it with `--no-verify`; fix the message.
- Open a PR using the repository template. Include the commands you ran and their results.
- Merge with a merge commit. Squash and rebase merges are disabled so individual commits remain reviewable.
- Delete the branch after merge. `main` must stay releasable.

## Pull requests

A PR is ready when:

- The change matches the linked issue and does not add unrequested scope.
- The final commit passes formatting, build, and tests.
- New behavior has tests, and a bug fix has a regression test.
- The PR body states what was verified and what was not.
- No quality gate, warning, suppression, or test was weakened.

CI runs on `windows-latest`. A green local run on Linux is necessary but not sufficient for runtime behavior; Windows-specific changes need Windows validation or a CI run.

## CI

| Workflow | Trigger | Purpose |
| --- | --- | --- |
| `CI` | Push to `main`, every PR, manual | Format, build, test on Windows |
| `CodeQL` | Push to `main`, PRs, weekly schedule | C# security analysis |
| `Dependency review` | PRs | Reject new dependencies with known vulnerabilities or disallowed licenses |

The `CI` workflow is the required status check for `main`. CodeQL is currently advisory; promote it to a required check once its signal is stable.

## Repository settings

- `main` is protected: a pull request is required, the `build` check must pass, the branch must be up to date, force pushes and deletions are blocked, and conversations must be resolved before merge.
- Required approvals are `0` because the repository has one maintainer. CI is the gate. Raise the requirement when a second maintainer joins.
- Only merge commits are allowed. Squash and rebase merges are disabled, and head branches are deleted after merge.
- Auto-merge is enabled so a PR can merge once the required check passes.
- Secret scanning, push protection, Dependabot alerts, and Dependabot security updates are enabled. Private vulnerability reporting is enabled through [SECURITY.md](../SECURITY.md).
- Repository administrators are subject to the protection rules. A temporary protection change is an explicit maintenance action, not a way to land a feature.

## Windows-specific validation

- Run the app on Windows to verify startup, shutdown, DPI behavior, and any host integration.
- Test at 100%, 125%, 150%, and mixed-DPI configurations when touching UI.
- Test with the taskbar on each monitor edge when taskbar behavior is involved.
- Do not assume a GPU or temperature sensor exists. Test the unavailable path as well as the available path.

## Local scratch files

`.scratch/` is ignored by Git. Use it for local experiments, logs, captured provider responses with secrets removed, and intermediate artifacts. Do not put anything there that is required to build or test the project.

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `NETSDK1100` on Linux/WSL | Windows targeting is disabled | Confirm `EnableWindowsTargeting` is `true` in `Directory.Build.props` |
| The app exits immediately | Expected in the foundation build; no host exists | Use build and tests until the tray host lands |
| `dotnet format` reports changes | Code does not match `.editorconfig` | Format only the changed files, review the diff, and commit the formatting |
| Commit rejected by `commit-msg` | Message is not Conventional Commits or the subject is too long | Reword the message; do not use `--no-verify` |
| CI cannot find the SDK | `global.json` pins an unavailable patch | Update `global.json` in a dedicated PR |

## Releases

No release process exists yet. Packaging, signing, update channels, and versioning will be decided in an ADR before the first distributable build.
