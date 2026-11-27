# AGENTS.md

BaboJUPulse is a Windows tray utility for system metrics and AI coding subscription quotas. The repository is in its foundation stage: it has a buildable WPF host shell and no product features.

Read this file first, then only the linked document that matches the task.

## Current state

- Stack: C# / .NET 10 LTS with WPF, targeting Windows 10 2004 or later ([ADR-0001](docs/adr/0001-windows-desktop-stack.md)).
- Product scope is intent, not a commitment: [product scope](docs/product-scope.md).
- No monitoring, quota, tray, taskbar, notification, or settings feature exists yet.
- Do not add product features unless the task explicitly asks for them.

## Commands

Run from the repository root:

```powershell
dotnet restore BaboJUPulse.slnx
dotnet format BaboJUPulse.slnx --verify-no-changes --no-restore
dotnet build BaboJUPulse.slnx -c Release --no-restore -warnaserror
dotnet test BaboJUPulse.slnx -c Release --no-build
```

- `dotnet format` is the formatting gate. Do not reformat unrelated files.
- The build treats warnings as errors. Do not suppress a warning merely to make CI pass. A narrow, justified suppression follows the [suppression policy](CODING_STANDARDS.md#suppressions-and-exceptions).
- `EnableWindowsTargeting` lets Linux and WSL compile the WPF project, but the app cannot run there. Runtime validation requires Windows.

## Workflow

- Start from a GitHub Issue. Use a `feat/<short-name>`, `fix/<short-name>`, or `docs/<short-name>` branch.
- Commit messages follow Conventional Commits: `<type>: <subject>`, subject at most 50 characters. The local `commit-msg` hook enforces this when `core.hooksPath` is configured; it is not a server-side guarantee.
- Open a PR. CI must pass. Merge with a merge commit; squash and rebase merges are disabled.
- Keep `main` releasable. Do not commit generated output, local settings, credentials, or `.scratch/`.
- A project-wide analyzer or quality-gate change is a separate PR. Weakening a gate requires an ADR and maintainer approval; never bundle it with a feature fix.

## Boundaries

- UI hosts (taskbar, tray, popup) must not own collection, quota, or persistence logic.
- Provider-specific quota rules stay behind provider adapters. Do not leak provider DTOs into UI code.
- Windows interop stays in a small, documented boundary with explicit ownership and `SafeHandle` where handles are involved.
- Credentials never enter source, logs, crash reports, or test fixtures. Use Windows Credential Manager or DPAPI when credentials are implemented.

## Documentation

- Product intent and non-goals: `docs/product-scope.md`
- Architecture boundaries: `docs/architecture.md`
- Architecture decisions: `docs/adr/`
- Build, test, branch, and release workflow: `docs/development.md`
- Coding rules: `CODING_STANDARDS.md`
- User-facing overview and setup: `README.md`

## Agent conduct

- Use the model the maintainer names for the task. Do not delegate to another model without approval.
- State what you verified and what you did not. Never claim a command or CI run passed unless you ran it.
- Ask before a consequential choice the repository does not answer: public API shape, credential storage, taskbar integration technique, or a dependency with a security or licensing cost.
- Prefer the smallest change that satisfies the request. Do not add speculative abstractions.
- When a task is done, report files changed, commands run with results, and remaining risks.
