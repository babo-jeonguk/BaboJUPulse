# Architecture

> **Status:** working boundaries for the foundation. No collector, provider adapter, settings store, tray host, or taskbar host exists yet. Product-specific vocabulary is in [GLOSSARY.md](../GLOSSARY.md); this document uses those terms.

## Current shape

The repository contains:

- `src/BaboJUPulse/` — a WPF executable with no window and no product features. It is the process host that future tray and taskbar surfaces will attach to.
- `tests/BaboJUPulse.ArchitectureTests/` — repository and configuration invariants: target framework, no startup window, quality-gate settings, analyzer configuration, source suppressions, CI gates, documentation validation, and local-only content. The operating policy is in [Quality gates](agents/quality-gates.md).

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

## Module design

The boundaries above are only useful if the code inside them is shaped well. Use the following vocabulary when designing or reviewing a module. The enforceable code rules are in [Coding standards](../CODING_STANDARDS.md).

- **Module** means anything with an interface and an implementation: a function, type, package, or a slice spanning several collaborators. **Interface** means everything a caller must know to use it correctly, including invariants, ordering, failure modes, and configuration. It is broader than a method signature.
- **Depth** is leverage at the interface: how much useful behavior a caller or test can exercise per unit of interface it must learn. A module is deep when substantial behavior sits behind a small, clear contract. Depth is a property of the interface, not a count of lines or classes.
- **Seam** is the place where a module's interface lives and behavior can be replaced without editing that place. **Adapter** is the role a concrete implementation plays at a seam. Put a seam where something genuinely varies or must be tested in isolation, not on every class.
- **Leverage** is what callers gain from depth. **Locality** is what maintainers gain: one place to change, verify, and understand a behavior.

A provider adapter is a good example of a deep module. Its interface should let the application refresh an account and receive a quota result or an explicit failure. Authentication, request construction, provider-specific parsing, retry rules, and error translation belong behind that interface. The taskbar host, tray host, and notification rules must not learn provider payload shapes.

Depth does not require a large class. A deep module may be composed of small internal types, helpers, and internal seams that its own tests use. Only the external contract is part of the interface.

Apply these tests when adding or changing a module:

- **The deletion test.** If deleting the module would move its complexity into several callers, it earns its keep. If the complexity simply disappears, it was a pass-through.
- **The seam test.** One concrete adapter means a hypothetical seam; two real variations or a required test boundary justify the seam. Do not add an interface for a single implementation without a boundary or test reason.
- **The interface test.** Callers and tests should cross the same contract. If a test must reach past the interface into internal details, the module is the wrong shape or the test is at the wrong level.
- **The dependency test.** Dependencies point inward. Domain and application code do not learn about WPF, Windows handles, HTTP clients, provider SDKs, or credential storage.
- **The locality test.** A new provider or sensor should add behavior behind an existing contract, not scatter conditionals through hosts and notification rules.

Avoid shallow pass-through abstractions: a wrapper that only forwards every call, a view model that only exposes a service, or a layer that exists to demonstrate a pattern. Name the concrete concept first; extract a shared abstraction after the third real use or a genuine boundary.

Do not create speculative interfaces, assemblies, dependency-injection containers, or domain layers for these principles. The smallest concrete design that keeps the dependency direction and test surface sound is the preferred one.

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
