# BaboJUPulse

A lightweight Windows tray utility that keeps system resource use and AI coding subscription quotas visible without a separate dashboard.

> **Status: foundation only.** This repository currently contains a buildable WPF host shell, engineering conventions, and CI. No monitoring, quota, tray, taskbar, settings, or notification feature is implemented yet. Do not install this build expecting a working monitor.

## Why it exists

The information that matters while coding is scattered across Task Manager, vendor utilities, and several provider dashboards. BaboJUPulse is intended to put the repeated checks in one place: the Windows taskbar and system tray.

The product deliberately has no standalone main window. The taskbar readout, tray icon, and compact tray popup are the interface.

## Planned scope

| Area | Planned capability |
| --- | --- |
| System monitoring | CPU utilization, RAM usage, GPU utilization, GPU VRAM usage, and CPU/GPU temperatures where the hardware and drivers expose them |
| AI subscriptions | Claude Code, Codex, Antigravity, and OpenCode Go accounts; remaining quota, reset time, provider-specific quota windows, banked or manually available resets where supported, account aliases, and last successful synchronization |
| Windows integration | Persistent taskbar metrics, tray icon, compact tray popup, configurable metric visibility and ordering, startup with Windows, and resource or quota notifications |

This is product intent, not a promise that every provider exposes every field. Provider-specific limitations will be documented with each adapter.

## What it is not

- Not a general-purpose process monitor or a replacement for Task Manager.
- Not a cross-platform desktop app.
- Not a cloud service; account and metric ownership stays on the local machine unless a provider requires a network request.
- Not a dashboard with a main window.

## Requirements

- Windows 10 version 2004 (build 19041) or later, or Windows 11.
- [.NET 10 SDK](https://dotnet.microsoft.com/download/dotnet/10.0) to build from source.
- No administrator rights are required by the current host.

GPU and temperature readings depend on hardware, drivers, and vendor support. They are not guaranteed on every machine.

## Build from source

```powershell
git clone https://github.com/babo-jeonguk/BaboJUPulse.git
cd BaboJUPulse
./scripts/setup-dev.ps1
dotnet build BaboJUPulse.slnx -c Release
```

WSL and Linux contributors can compile the Windows-targeted projects with `./scripts/setup-dev.sh` and the same `dotnet build` command. The WPF executable still only runs on Windows.

The foundation host exits immediately after startup because there is no tray or taskbar host yet. The build and test commands are the current smoke check.

## Quality gates

```powershell
dotnet restore BaboJUPulse.slnx
dotnet format BaboJUPulse.slnx --verify-no-changes --no-restore
dotnet build BaboJUPulse.slnx -c Release --no-restore -warnaserror
dotnet test BaboJUPulse.slnx -c Release --no-build
```

CI runs the same gates on `windows-latest`. Warnings are errors, nullable reference types are enabled, formatting is verified rather than auto-applied, and restore audits direct and transitive packages. Selected analyzers reject blocking waits, dispatcher blocking, TLS validation bypass, arbitrary command strings, and excessive complexity or coupling.

Documentation changes also get a lightweight check that does not build the application:

```bash
bash scripts/test-check-documentation.sh
bash scripts/check-documentation.sh
```

It validates relative links, heading fragments, Git-ignored and local-only targets, table shape, fenced-code closure, and the public-content policy. The separate `documentation` workflow runs the same checks on every pull request and push to `main`; the required `build` check remains mandatory on the final head.

Suppression approval, gate integrity, and known limitations are in [Quality gates](docs/agents/quality-gates.md); the tool decisions are in [ADR-0002](docs/adr/0002-static-analysis-and-architecture-enforcement.md).

## Contributing

Bug reports and feature requests are welcome through the repository issue templates. Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. It covers issue search, branch setup, validation, review, privacy, and licensing. You may use any editor, IDE, or local workflow.

The internal agent workflow is described in [Development workflow](docs/agents/development-workflow.md). It is not a requirement for external contributors.

## Documentation

- [Product scope](docs/product-scope.md) — intended capabilities, constraints, and non-goals.
- [GLOSSARY](GLOSSARY.md) — canonical product-domain terminology.
- [Architecture](docs/architecture.md) — current shape and the boundaries future features must respect.
- [Development](docs/development.md) — setup, build/run, tests, workflow scripts, and troubleshooting.
- [Development workflow](docs/agents/development-workflow.md) — issue-to-merge sequence and stage transitions.
- [Issue tracker](docs/agents/issue-tracker.md) and [triage labels](docs/agents/triage-labels.md) — issue readiness and repository labels.
- [Pull request](docs/agents/pull-request.md) and [PR merge](docs/agents/pr-merge.md) — PR evidence, documentation freshness, merge, and cleanup.
- [GitHub operations](docs/agents/github-operations.md) — issues, PRs, commits, publication, and local-only artifacts.
- [Quality gates](docs/agents/quality-gates.md) — verification, documentation validation, analyzer enforcement, suppressions, and limitations.
- [Architecture decisions](docs/adr/) — accepted decisions and their rationale.
- [Coding standards](CODING_STANDARDS.md) — enforceable engineering rules.
- [Agent guide](AGENTS.md) — entry point and task routing for coding agents.
- [Documentation map](docs/README.md) — index of all project documentation.

## Security

Do not commit credentials, tokens, account identifiers, local configuration, or references to local-only working artifacts. The product will eventually read AI provider credentials; those values must stay in Windows Credential Manager or a DPAPI-protected store, never in source, logs, crash reports, or fixtures.

Report vulnerabilities privately as described in [SECURITY.md](SECURITY.md), not in a public issue.

## License

[MIT](LICENSE)
