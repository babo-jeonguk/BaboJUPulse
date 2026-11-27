# ADR-0001: Windows desktop stack

- **Status:** Accepted
- **Date:** 2026-11-27
- **Deciders:** Maintainer

## Context

BaboJUPulse is a Windows-only utility whose primary surfaces are the taskbar and system tray. It must:

- Stay resident with a small memory and CPU footprint.
- Read Windows performance counters, GPU data, and temperature sources.
- Host tray and taskbar UI without a browser engine.
- Be distributable without a Node.js, Python, or Java runtime.
- Remain maintainable by a small team and by coding agents using conventional .NET tooling.

The stack decision is a foundation decision because it determines the project layout, CI runner, analyzers, packaging, and the interop boundary. It does not decide the taskbar integration technique; that remains a separate decision.

## Decision

Use **C# on .NET 10 LTS with WPF**, targeting `net10.0-windows` and Windows 10 version 2004 (build 19041) or later.

- WPF provides the process host, XAML UI, data binding, and per-monitor DPI support.
- Windows interop is written in C# against the Windows SDK, isolated behind small boundaries.
- The application is a single desktop process. No background service is introduced unless a later requirement demands one.
- .NET 10 is the LTS release supported until November 14, 2028, which gives the project a stable baseline without tracking an STS release.

## Alternatives considered

### Tauri v2 with React and TypeScript

**Why it was attractive:** it matches the maintainer's existing Tauri experience and allows a web UI.

**Why it was rejected for this product:** it adds a WebView2 runtime and a Rust plus Node toolchain to a utility whose UI is a taskbar readout and a compact popup. The taskbar integration still requires native Windows code, so the web UI does not remove the hardest part. The result is more moving parts and a larger install for little UI benefit.

### Electron

Rejected. It is explicitly contrary to the lightweight requirement, adds a Chromium runtime, and is heavier than the product warrants.

### Rust with `windows-rs`

**Why it was attractive:** a small native binary, no managed runtime, and direct Win32 access.

**Why it was rejected:** tray, taskbar, accessibility, and settings UI would require substantially more custom UI infrastructure. The maintainer's existing product work is closer to C# and TypeScript than to a Rust-native desktop UI, and the project would spend its early effort rebuilding controls instead of monitoring.

### WinUI 3

**Why it was attractive:** the modern Windows UI stack and Fluent design.

**Why it was rejected:** the packaging and deployment model is heavier for a tray-first utility, and WPF has a simpler path for a long-lived tray process with custom chrome. WinUI 3 remains a candidate if the product later needs a full settings experience that justifies the packaging cost.

### Windows Forms

Rejected as the primary UI stack. It is viable for a tray icon, but WPF gives better layout, styling, DPI behavior, and data binding for the compact popup and future settings surface. Windows Forms types may still be used narrowly for tray integration if WPF alone is insufficient.

## Consequences

### Positive

- One language and one build system for UI, collectors, provider adapters, and tests.
- Mature analyzers, nullable reference types, and a first-class CI story on `windows-latest`.
- WPF is Windows-only, which matches the product boundary instead of pretending to be cross-platform.
- The .NET SDK is available on Windows CI and can compile the Windows-targeted projects on Linux/WSL with `EnableWindowsTargeting`.

### Negative

- The app cannot run on Linux or macOS. CI can compile and test, but runtime validation requires Windows.
- WPF is a mature rather than modern UI stack. Newer Fluent controls require additional libraries or custom styling.
- A framework-dependent build requires the .NET Desktop Runtime; a self-contained build is larger. Packaging will decide this trade-off.
- Windows 11 taskbar customization is constrained by the operating system. The stack choice does not guarantee that a persistent taskbar readout is possible with a supported API; that must be proven by the taskbar integration ADR.

### Follow-up

- Record the taskbar integration technique in a dedicated ADR before implementing the taskbar host.
- Record the GPU and temperature data sources in a dedicated ADR before implementing system collectors.
- Record the credential storage decision before implementing account management.
- Decide framework-dependent versus self-contained packaging, code signing, and the update channel before the first release.

## References

- [.NET support policy](https://dotnet.microsoft.com/platform/support/policy/dotnet-core) — .NET 10 is LTS, supported until November 14, 2028.
- [WPF overview](https://learn.microsoft.com/dotnet/desktop/wpf/overview/) — WPF is a Windows-only UI framework.
- [.NET 10 download](https://dotnet.microsoft.com/download/dotnet/10.0)
- [WPF repository](https://github.com/dotnet/wpf)
