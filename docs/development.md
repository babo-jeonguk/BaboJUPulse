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

Both scripts set `core.hooksPath` to `.githooks` and restore the solution. The hook enforces the commit convention and checks commit messages for local-only references. It is a local convenience, not a server-side guarantee: a contributor who has not run setup, or who uses `--no-verify`, is not stopped by it.

## Build and run

```powershell
dotnet build BaboJUPulse.slnx -c Release
dotnet run --project src/BaboJUPulse -c Release
```

The foundation build has no tray or taskbar host, so it exits immediately after startup. This is expected until the first host feature lands. The build is the current smoke test.

## Quality gates

Run these before opening a PR and after the final change:

```powershell
dotnet restore BaboJUPulse.slnx
dotnet format BaboJUPulse.slnx --verify-no-changes --no-restore
dotnet build BaboJUPulse.slnx -c Release --no-restore -warnaserror
dotnet test BaboJUPulse.slnx -c Release --no-build
```

| Gate | What it proves |
| --- | --- |
| `dotnet restore` | Package source pinning and transitive NuGet auditing |
| `dotnet format --verify-no-changes` | The tree matches `.editorconfig`; no formatting drift |
| `dotnet build -warnaserror` | Compiler, nullable, style, banned-API, complexity, and coupling checks pass |
| `dotnet test` | Behavior and repository/configuration invariant tests pass |

Do not format unrelated files. When formatting is needed, format only the files you changed and review the diff.

Required checks, suppression approval, analyzer changes, gate integrity, and enforcement limitations are defined in [Quality gates](agents/quality-gates.md). Do not duplicate or weaken those rules here.

## Workflow scripts

`scripts/workflow/` provides deterministic entry points for the mechanical parts of the development workflow. They require Bash and Git; `gh` is required for GitHub operations, and Paseo is required only for workspace cleanup when the workspace is Paseo-managed. The individual commands above remain authoritative; the scripts sequence them and fail closed.

| Script | Use |
| --- | --- |
| `scripts/workflow/workspace.sh prepare` | Verify the repository and issue, refresh `origin/main`, capture the base SHA, and detect an existing branch or worktree before a Paseo workspace operation. |
| `scripts/workflow/workspace.sh verify` | Verify the worktree, branch, base ancestry, current `origin/main` ancestry, and clean state after workspace creation. |
| `scripts/workflow/validate.sh targeted` | Run selected gates after a slice, for example `--format --build --test`, `--docs`, `--policy`, or `--workflow`. |
| `scripts/workflow/validate.sh full` | Run restore, format, build, tests, repository-policy tests, documentation, public content, and workflow-script tests. |
| `scripts/workflow/validate.sh docs` | Run documentation and public-content checks only. |
| `scripts/workflow/validate.sh range` | Verify and print a base-to-head review range, commit count, and diffstat. |
| `scripts/workflow/merge.sh inspect` | Read-only merge-readiness inspection against an explicit verified SHA. |
| `scripts/workflow/merge.sh execute` | Merge only after inspection passes, using the original verified SHA as `--match-head-commit`. |
| `scripts/workflow/cleanup.sh inspect` | Read-only post-merge cleanup inspection. |
| `scripts/workflow/cleanup.sh execute` | Verify the merge, delete a safe remote branch, fast-forward local `main`, archive the Paseo workspace, remove a clean worktree, and delete the merged local branch. Use `--remove-build-output` only to remove known reproducible output. |

Run `scripts/workflow/<script>.sh --help` for the exact options. `validate.sh` reports the repository, commit, dirty state, checks, and results. `workspace.sh` reports the base and head plus worktree cleanliness; `merge.sh` and `cleanup.sh` report the PR, SHAs, evaluated conditions, and final state. A failed required check exits nonzero; a concurrent HEAD or working-tree change during validation exits with status 3. Do not treat a script result as permission to skip review, documentation freshness, or a maintainer decision.

Run the workflow-script tests directly:

```bash
bash scripts/test-workflow.sh
```

They use temporary Git repositories and stubbed GitHub/Paseo commands; they never mutate GitHub or a real workspace.


## Documentation validation

Run the documentation checks directly when you change Markdown, links, contributor guidance, or workflow documentation. They do not build the application:

```bash
bash scripts/test-check-documentation.sh
bash scripts/check-documentation.sh
```

The checker validates relative links, heading fragments, Git-ignored targets, local absolute paths, table shape, fenced-code closure, and the public-content policy. The repository-policy test invokes the same script, so there is one implementation of the rules. Policy and limitations are in [Quality gates](agents/quality-gates.md#documentation-validation).

The separate [documentation workflow](../.github/workflows/docs.yml) runs the same checks, the workflow-script tests, and the public-content tests on every pull request and push to `main`. It is not a branch-protection required check; the existing `build` workflow remains required and still runs on documentation-only commits.

## Tests

- `tests/BaboJUPulse.ArchitectureTests/` protects repository and configuration invariants: target framework, no startup window, quality-gate settings, CI commands, analyzer configuration, source suppressions, documentation validation, and local-only content.
- Product tests belong in the layer that owns the behavior. Add a test project when the first product behavior exists; do not create a broad test pyramid in advance.
- A bug fix needs a regression test that fails before the fix.
- Tests must not depend on machine load, GPU presence, network access, locale, or wall-clock time.

Run one test class while iterating:

```powershell
dotnet test tests/BaboJUPulse.ArchitectureTests -c Release --filter FullyQualifiedName~ProjectPolicyTests
```

Run the repository-policy subset used by the dedicated CI step:

```powershell
dotnet test tests/BaboJUPulse.ArchitectureTests/BaboJUPulse.ArchitectureTests.csproj -c Release --no-build --filter "Category=RepositoryPolicy" -- RunConfiguration.TreatNoTestsAsError=true
```

CI treats a test run with no matching tests as an error, so removing the policy tests cannot turn the gate into a silent pass.

Run the public-content checker and its synthetic tests directly:

```bash
bash scripts/test-public-content.sh
bash scripts/check-public-content.sh --tracked
```

The checker reports only a rule identifier, safe file label, and line number. It never prints the matching text.

## Contribution workflow

External contributors start at [CONTRIBUTING.md](../CONTRIBUTING.md). They may use any editor, IDE, or local workflow; Paseo and the internal agent orchestration are not required.

The internal sequence is defined in [Development workflow](agents/development-workflow.md): issue and readiness, isolated workspace, slice-based implementation, independent review, PR, documentation freshness review, and merge with cleanup. Branch naming, commit messages, publication, and local-only artifact rules are in [GitHub operations](agents/github-operations.md). Required validation and review gates are in [Quality gates](agents/quality-gates.md). The PR Summary and Merge Danger guidance is in [Pull request](agents/pull-request.md). Canonical product terminology is in [GLOSSARY.md](../GLOSSARY.md) and [Domain guidance](agents/domain.md).

## Windows-specific validation

- Run the app on Windows to verify startup, shutdown, DPI behavior, and any host integration.
- Test at 100%, 125%, 150%, and mixed-DPI configurations when touching UI.
- Test with the taskbar on each monitor edge when taskbar behavior is involved.
- Do not assume a GPU or temperature sensor exists. Test the unavailable path as well as the available path.

## Local-only artifacts

`.scratch/` is the designated local workspace and is ignored by Git. It may contain plans, investigation notes, handoffs, logs, and intermediate artifacts. Do not reference a concrete artifact below it in published content; see [GitHub operations](agents/github-operations.md#local-only-artifacts). Do not put anything there that is required to build or test the project.

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `NETSDK1100` on Linux/WSL | Windows targeting is disabled | Confirm `EnableWindowsTargeting` is `true` in `Directory.Build.props` |
| The app exits immediately | Expected in the foundation build; no host exists | Use build and tests until the tray host lands |
| `dotnet format` reports changes | Code does not match `.editorconfig` | Format only the changed files, review the diff, and commit the formatting |
| Commit rejected by `commit-msg` | Invalid Conventional Commit, too-long subject, or local-only reference | Fix the message; do not use `--no-verify` |
| CI cannot find the SDK | `global.json` pins an unavailable patch | Update `global.json` in a dedicated PR |
| Repository-policy test fails | A source suppression, nested config, disabled analyzer, weakened threshold, conditional CI step, or null-forgiving operator was introduced | Fix the code/configuration or request maintainer approval under [Quality gates](agents/quality-gates.md) |
| Documentation checker rejects a file | A relative link or fragment is broken, a target is Git-ignored or local, a table has inconsistent columns, or a fence is unclosed | Use the reported rule and line to fix the document; rerun `bash scripts/check-documentation.sh` |
| Public-content checker rejects text | A concrete local-only artifact path, local absolute path, or obvious secret pattern matched | Use the reported rule and line to fix the text locally; do not paste the matching value into a comment |

## Releases

No release process exists yet. Packaging, signing, update channels, and versioning will be decided in an ADR before the first distributable build.
