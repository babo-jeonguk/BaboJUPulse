# Product scope

> **Status:** product intent. This document describes what BaboJUPulse is meant to become. It is not a statement that any capability is implemented.

## Problem

A developer running local AI coding agents repeatedly checks two unrelated places: Windows resource monitors for CPU, memory, GPU, and temperatures, and several provider dashboards for subscription quota and reset times. The checks are small but frequent, and each one interrupts the work it is meant to support.

BaboJUPulse should make those checks ambient. The information lives in the Windows taskbar and system tray; there is no dashboard to open and no main window to manage.

## Product shape

- A persistent taskbar readout for the metrics the user chooses.
- A system tray icon that opens a compact detail popup.
- Notifications for resource thresholds and quota events.
- Configuration for metric visibility, ordering, accounts, and startup behavior.

The taskbar and tray are the primary interface. A settings surface may exist, but it is secondary and should not become a general dashboard.

## Intended capabilities

### System monitoring

- CPU utilization.
- RAM usage.
- GPU utilization.
- GPU VRAM usage.
- CPU and GPU temperatures where the hardware, driver, and vendor interfaces expose them.

Readings must carry their own freshness and availability. A metric that cannot be read is shown as unavailable, not as zero.

### AI subscription monitoring

- Claude Code, Codex, Antigravity, and OpenCode Go.
- Multiple accounts per provider.
- Remaining quota.
- Quota reset time.
- Provider-specific quota windows.
- Banked or manually available quota resets where the provider supports them.
- Custom account aliases.
- Last successful synchronization time.

Provider support is not uniform. Each adapter must document which fields it can supply and how it handles a provider that does not expose a field.

### Windows integration

- Persistent taskbar metrics.
- System tray icon.
- Compact tray popup.
- Configurable metric visibility and ordering.
- Automatic startup with Windows.
- Resource and quota notifications.

## Non-goals

- A general-purpose process monitor or Task Manager replacement.
- A cross-platform desktop application.
- A cloud service or account system owned by this project.
- A web dashboard or a standalone main window.
- Remote monitoring of another machine.
- Automatic remediation of resource pressure, such as killing processes or changing power plans.

## Constraints

- The product targets Windows 10 version 2004 or later and Windows 11.
- The application should remain lightweight: no Electron runtime, no always-open browser engine, and no background service unless a documented requirement needs one.
- The application should not require administrator rights for normal operation.
- Credentials must stay on the local machine in a Windows-protected store.
- Provider integrations must degrade independently. One unavailable provider must not blank the taskbar or prevent other metrics from updating.
- Taskbar integration must use a supported technique. The technique is not decided yet; see [Architecture](architecture.md#open-decisions).

## Foundation exit criteria

The foundation is complete when:

- The repository builds and tests on Windows CI.
- The coding standards and quality gates are documented and enforced.
- The branch, commit, and PR workflow is defined.
- The stack decision is recorded in an ADR.
- At least one product feature can be added without re-litigating the project structure.

Feature work starts only after the foundation is accepted. The current build is a host shell, not a usable monitor.
