# Taskbar overlay PoC (PoC B)

This directory contains the second bounded research experiment for [Issue #20](https://github.com/babo-jeonguk/BaboJUPulse/issues/20). It tests whether an app-owned, non-activating WPF overlay aligned with verified free space in the taskbar can provide a persistent readout without cross-process parenting.

This is experimental code on the `chore/taskbar-integration-poc` branch. It is not production code, is not part of `BaboJUPulse.slnx`, and does not implement real collectors, quota providers, settings, startup registration, or production host architecture. PoC A remains in `experiments/taskbar-integration/` and is unchanged.

## Result summary

The overlay rendered a readable, updating readout inside the actual taskbar in the tested clean Windows 11 24H2 session, including after three Explorer restart cycles. It did not use `SetParent`, elevation, shell injection, or an AppBar.

The result is **conditional**, not an accepted taskbar integration strategy:

- The taskbar can be raised above ordinary topmost windows in some shell states. The PoC detected this with `WindowFromPoint` and hid the overlay, keeping the tray fallback. The observed triggers were an app-button interaction and an auto-hide transition. The app recovered when the shell settled; in the auto-hide case, an Explorer restart restored visibility.
- Free space is discovered by rendering the taskbar with `PrintWindow` and treating high-contrast columns plus known taskbar child rectangles as occupied. This is a heuristic over undocumented taskbar window class names, not a supported shell extension contract. It cannot reserve taskbar space.
- The overlay has no Windows 10 runtime evidence. The project uses the product target `net10.0-windows10.0.19041.0`, but Windows 11 success is not Windows 10 proof.

See the issue handoff for the full scenario matrix and comparison with PoC A.

## Technique

The overlay is a borderless WPF window with these extended styles:

- `WS_EX_TOOLWINDOW` and `ShowInTaskbar=false`: no taskbar button or Alt-Tab entry.
- `WS_EX_NOACTIVATE` and `ShowActivated=false`: no focus theft.
- `WS_EX_TOPMOST`: stays above non-topmost windows when the shell places the taskbar normally.

Placement is performed with `SetWindowPos` in physical pixels. The process manifest uses per-monitor DPI awareness, so taskbar and overlay rectangles are physical pixels and the WPF content scales with the target monitor.

Occupied taskbar regions are discovered in two layers:

1. `PrintWindow` with `PW_RENDERFULLCONTENT` renders the taskbar itself (not windows above it). The scanner measures per-column luminance variance in the rendered bitmap and treats visible content columns as occupied. The bitmap is analyzed in memory only and is never saved or logged.
2. Known taskbar child rectangles for `Start`, `ReBarWindow32`, and `TrayNotifyWnd` are added as a safety net. These class names are Windows taskbar internals, not a documented extension contract.

`TaskbarOverlayPoc.Core` contains the pure free-gap rule: find the first gap that fits the overlay with margins, or report no placement. It has unit tests for empty, centered, left-only, no-gap, DPI, negative-coordinate, and vertical-taskbar cases. The WPF project does not call `SetParent`; it discovers the primary `Shell_TrayWnd` or a `Shell_SecondaryTrayWnd` fallback and keeps its own top-level window.

Visibility is checked after placement and on every layout tick with `WindowFromPoint` and `GetAncestor`. If the point at the overlay center belongs to another window, the overlay is hidden and the tray fallback remains. `SHQueryUserNotificationState`, foreground-window coverage, shell-popup classes, taskbar auto-hide state, and taskbar verticality are also used to hide safely. The layout timer runs every two seconds; metrics update every second. Display and user-preference events trigger an immediate re-evaluation.

The `--preview-above-taskbar` option moves the readout just above the taskbar. It is a **diagnostic control** for rendering/focus/resource observations, not taskbar integration, and must not be cited as a successful taskbar readout.

## Build

From the repository root:

```bash
dotnet restore experiments/taskbar-overlay/TaskbarOverlayPoc.slnx
dotnet format experiments/taskbar-overlay/TaskbarOverlayPoc.slnx --verify-no-changes
dotnet build experiments/taskbar-overlay/TaskbarOverlayPoc.slnx -c Release --no-restore -warnaserror
dotnet test experiments/taskbar-overlay/TaskbarOverlayPoc.Tests/TaskbarOverlayPoc.Tests.csproj -c Release --no-build
```

The WPF project needs the Windows desktop targeting pack. `Directory.Build.props` sets `EnableWindowsTargeting`, so it can be built from Linux/WSL; the executable still runs only on Windows. Publish a self-contained `win-x64` build when the Windows machine has no .NET desktop runtime:

```bash
dotnet publish experiments/taskbar-overlay/TaskbarOverlayPoc/TaskbarOverlayPoc.csproj \
  -c Release \
  -r win-x64 \
  --self-contained true \
  -o <publish-directory>
```

Run the published executable from an interactive Windows desktop session, not a service or headless CI agent.

```powershell
.\BaboJUPulse.TaskbarOverlayPoc.exe
```

Options:

```powershell
# Write geometry and lifecycle diagnostics to %TEMP%\BaboJUPulse.TaskbarOverlayPoc.log.
.\BaboJUPulse.TaskbarOverlayPoc.exe --diagnostic-log

# Exit automatically after 15 seconds.
.\BaboJUPulse.TaskbarOverlayPoc.exe --exit-after-seconds 15

# Prove the tray fallback survives discovery failure.
.\BaboJUPulse.TaskbarOverlayPoc.exe --simulate-discovery-failure

# Force the no-safe-gap hide path.
.\BaboJUPulse.TaskbarOverlayPoc.exe --simulate-no-safe-slot

# Diagnostic control only: show the readout just above the taskbar.
.\BaboJUPulse.TaskbarOverlayPoc.exe --preview-above-taskbar
```

The diagnostic log contains taskbar handles, rectangles, DPI, hide reasons, and geometry. It does not contain window titles, user names, pixel data, or taskbar screenshots.

## Expected observation

In a clean tested Windows 11 24H2 session at 200% scaling, with the taskbar centered at the bottom, the readout appears in the far-left free gap. The logged rectangle was `(8,2076)-(608,2148)` physical pixels, with the taskbar at `(0,2064)-(3840,2160)`. The values change every second and the exit button `x` ends the process.

The readout does not cover Start, search, app buttons, the notification area, or the clock in the tested layouts. If the shell raises the taskbar above the overlay, the readout hides and the tray icon remains; it is not left stale over the taskbar.

## Observed on the test machine

| Scenario | Result | Observation |
| --- | --- | --- |
| Five cold launches, normal exit | PASS | 5/5 launches showed the readout at the same computed slot; the readout exit button and auto-exit ended the process with no orphan window. |
| Explorer restart, three cycles | PASS | The process survived; it hid while the taskbar was absent, then rediscovered the new `Shell_TrayWnd` handle and showed the readout after each restart. |
| Centered taskbar | PASS | Readout at the left free gap; no overlap with Start/search/app buttons/tray. |
| Left-aligned taskbar | PASS | Readout moved to a free gap at `(1519,2076)-(2119,2148)`; no overlap in the tested layout. |
| Crowded taskbar, 16 extra windows | PASS (tested level) | The readout stayed in the left gap; a fully saturated taskbar was not reached. |
| Auto-hide enabled | PASS (safe hide) | Readout hid when auto-hide was detected. |
| Auto-hide disabled recovery | CONDITIONAL | After the transition, the taskbar stayed above the overlay and the readout remained hidden; an Explorer restart restored visibility. The app kept the tray fallback. |
| App-button interaction | CONDITIONAL | Clicking a taskbar app button raised the taskbar above the overlay; the app hid and recovered after the shell settled (about 11 seconds in the observed run). |
| Topmost test window over the readout | PASS (safe hide/recovery) | The readout hid with `topmost-foreground-overlap` and returned after the test window closed. |
| Fullscreen test window | PASS (safe hide/recovery) | The readout hid with `fullscreen-or-busy` and returned after the test window closed. |
| Focus and taskbar/Alt-Tab entry | PASS | `WS_EX_TOOLWINDOW`/`WS_EX_NOACTIVATE` and `ShowInTaskbar=false` were verified; showing or clicking the readout did not change the foreground window. |
| DPI 200% | PASS | Taskbar DPI 192; overlay 600x72 physical pixels. |
| DPI 100/125/150% | NOT TESTED | Placement math is unit-tested at 96/120/144/192 DPI, but display scaling was not changed at runtime. |
| Resolution, multi-monitor, taskbar edge, light theme | NOT TESTED | One 3840x2160 display and the Windows 11 24H2 taskbar were available; no unsupported inference is made. |
| Windows 10 | NOT TESTED | The project builds for `net10.0-windows10.0.19041.0`; no Windows 10 interactive environment was available. |
| Approximate resource use | Measured | Visible: about 1.2% total CPU over a 10-second sample on eight logical processors, 106 MB working set, 45 MB private bytes. Fallback: about 0.9%, 99 MB working set, 38 MB private bytes. These are single samples, not benchmarks. |

Evidence crops are the opaque readout rectangle only; they contain no notification icons, account information, or window titles.

## Manual verification checklist

| Scenario | Expected |
| --- | --- |
| Core: attach/update | Readout visible in the taskbar and values change every second |
| Core: no overlap | Readout does not cover Start, search, app buttons, notification area, or clock |
| Core: taskbar controls | Start, app buttons, notification area, and clock remain usable |
| Core: ordinary user | Runs without elevation or UAC |
| Core: focus | Showing or clicking the readout does not change the foreground window |
| Core: taskbar/Alt-Tab | No taskbar button and no Alt-Tab entry |
| Core: exit | `x` or tray **Exit** removes the readout and ends the process |
| Lifecycle: cold launch | Repeated launches show the readout or safely degrade |
| Lifecycle: Explorer restart | Process survives, rediscovers the taskbar, and shows the readout when safe |
| Lifecycle: discovery failure | Process survives in tray fallback with no overlay |
| Lifecycle: occlusion | Readout hides when a topmost/fullscreen window covers it and returns when safe |
| Layout: centered/left | Readout uses a free gap without overlap |
| Layout: crowded | Readout moves, shrinks only if still readable, or hides |
| Layout: auto-hide | Readout hides rather than floating over a hidden taskbar |
| Layout: DPI/resolution/multi-monitor | Readout follows the taskbar or degrades safely |
| Layout: theme/edge | Readout remains readable and follows a supported edge |
| Windows 10 | Assess separately; do not infer from Windows 11 |

Restart Explorer or change display/taskbar settings only with maintainer permission, and restore the settings afterward.

## Support and privacy

`SetWindowPos`, `PrintWindow`, `GetDpiForWindow`, `MonitorFromWindow`, `GetMonitorInfo`, `WindowFromPoint`, `GetAncestor`, `SHQueryUserNotificationState`, and `SHAppBarMessage` are documented Win32 APIs. The taskbar class names (`Shell_TrayWnd`, `Shell_SecondaryTrayWnd`, `Start`, `ReBarWindow32`, `TrayNotifyWnd`) and the taskbar content layout are Windows shell internals. This PoC uses them as an experiment, not as a supported extension contract. A topmost window is not guaranteed to stay above the taskbar in every shell state; the visibility guard is part of the experiment, not a guarantee.

The taskbar capture from `PrintWindow` is analyzed in memory only. It is never written to disk or included in logs or evidence. Evidence images are cropped to the opaque readout window and exclude other taskbar content.

## License and dependencies

The repository is MIT-licensed. This PoC has no third-party runtime package dependency; it uses WPF, WinForms `NotifyIcon`, and the .NET base class library. The test project uses the same xUnit and Microsoft.NET.Test.Sdk versions as the existing repository tests. No upstream source code was copied. External links in the issue are references, not proofs of behavior on this machine.
