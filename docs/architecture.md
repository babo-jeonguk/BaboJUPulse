# Architecture

> **Status:** working boundaries for the foundation. No collector, provider adapter, settings store, tray host, or taskbar host exists yet.

## Current shape

The repository contains:

- `src/BaboJUPulse/` — a WPF executable with no window and no product features. It is the process host that future tray and taskbar surfaces will attach to.
- `tests/BaboJUPulse.ArchitectureTests/` — repository and configuration invariants: target framework, no startup window, quality-gate settings, analyzer configuration, CI gates, relative documentation links, and ignored scratch files.

The current executable intentionally exits after startup. When the first host lands, it will keep the process alive and own the shutdown path.

Cross-assembly dependency tests are deliberately absent while the app is the only production assembly. [ADR-0002](adr/0002-static-analysis-and-architecture-enforcement.md) records the trigger and tool choice for adding them.

## Target boundaries

```text
┌─────────────────────────────────────────────────────────┐
│ Windows hosts                                            │
│ taskbar readout · tray icon · tray popup · notifications │
└──────────────────────────┬──────────────────────────────┘
                           │ view state / user intent
┌──────────────────────────▼──────────────────────────────┐
│ Application                                              │
│ refresh scheduling · metric ordering · sync orchestration│
│ notification rules · settings application                │
└───────────────┬──────────────────────────┬──────────────┘
                │                          │
┌───────────────▼──────────────┐  ┌────────▼──────────────┐
│ Domain                       │  │ Provider adapters      │
│ metric samples · accounts    │  │ Claude Code · Codex    │
│ quota windows · reset state  │  │ Antigravity · OpenCode │
└───────────────▲──────────────┘  └────────┬──────────────┘
                │                          │
┌───────────────┴──────────────────────────▼──────────────┐
│ Infrastructure                                           │
│ Windows performance APIs · GPU/vendor APIs · credentials │
│ HTTP clients · local persistence                         │
└─────────────────────────────────────────────────────────┘
```

The diagram is a dependency direction, not a file layout. Do not create all of these layers in advance.

## Rules

- Domain types are pure. They do not reference WPF, Windows interop, HTTP, or provider SDKs.
- Hosts render and forward intent. They do not collect metrics, parse provider payloads, or decide quota semantics.
- Provider-specific capabilities stay in adapters. A missing capability is represented explicitly, not as a zero value.
- Infrastructure is replaceable at its boundary. A hardware sensor, HTTP client, clock, or credential store must have a testable seam.
- The application owns scheduling and failure isolation. A failed provider refresh must not stop system metrics, and a failed GPU probe must not stop CPU readings.
- Windows interop is isolated and documented. Native handles use `SafeHandle`; ownership is explicit.
- One process, no elevation by default, no background service until a documented requirement demands one.

## Open decisions

These require an ADR before implementation:

- **Taskbar integration technique.** Windows 11 does not support the legacy deskband model the same way earlier versions did. The supported approach, its limitations, and its fallback need a decision before UI work starts.
- **GPU and temperature sources.** Vendor APIs, DXGI, WMI, and performance counters have different coverage and reliability. The first supported set needs a decision.
- **Credential storage.** Windows Credential Manager versus DPAPI-protected local storage, and how accounts are identified without storing secrets in settings.
- **Provider authentication.** How each provider's quota is obtained, what data leaves the machine, and how a failed or expired session is represented.
- **Packaging and updates.** Installer, portable build, startup registration, and update channel.

Do not implement a speculative abstraction for these decisions. Record the decision, then build the smallest concrete implementation that satisfies it.

## Foundation constraints

- Target framework: `net10.0-windows10.0.19041.0`.
- Minimum OS: Windows 10 version 2004 (build 19041).
- UI framework: WPF, per [ADR-0001](adr/0001-windows-desktop-stack.md).
- No runtime dependency on Node.js, Python, or a browser engine.
- The app must remain runnable without administrator rights.
