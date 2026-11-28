# Taskbar integration PoC

This directory contains the bounded research experiment for [Issue #20](https://github.com/babo-jeonguk/BaboJUPulse/issues/20). It tests whether a WPF process can host a persistent, readable taskbar readout with `SetParent`-style child-window hosting, using [Deskband11Lib.Wpf](https://github.com/airtaxi/Deskband11Lib) as the first candidate.

This is experimental code on the `chore/taskbar-integration-poc` branch. It is not production code, is not part of `BaboJUPulse.slnx`, and does not implement real collectors, quota providers, settings, startup registration, or the production host architecture.

## Candidate and constraints

- Candidate: `Deskband11Lib.Wpf` 1.5.1, MIT, built from upstream commit [`dca8508`](https://github.com/airtaxi/Deskband11Lib/commit/dca8508e86265c0f856bef7ed263b03f3cfc91dc).
- The package ships only `lib/net10.0-windows10.0.26100` and targets `net10.0-windows10.0.26100.0`.
- The product targets `net10.0-windows10.0.19041.0` (Windows 10 2004 or later). The candidate package cannot be consumed from that TFM. This PoC therefore uses `net10.0-windows10.0.26100.0` and can only be evaluated on Windows 11 build 26100 or later.
- No elevation, Explorer injection, shell patching, custom drivers, or registry workarounds are used. The PoC reparents only its own WPF window with public Win32 APIs through the candidate library.

## What the PoC does

- Creates a transparent, borderless WPF window and asks `TaskbarContentHost` to attach it to `Shell_TrayWnd`.
- Shows a compact readout with clearly labeled synthetic CPU and RAM percentages. Values change every second; they are not real measurements.
- Keeps a tray icon with a status line and an **Exit** command.
- Keeps a `x` button in the taskbar readout as a second explicit exit control.
- If attachment throws or the window is not actually parented to the taskbar, the process stays alive and the tray icon reports the fallback state. No standalone window is shown.
- Recreates the hosted window when the candidate reports that the taskbar window must be recreated (Explorer restart, DPI change, or monitor change).
- Never requires administrator rights.

## Build

From the repository root:

```bash
dotnet restore experiments/taskbar-integration/TaskbarIntegrationPoc/TaskbarIntegrationPoc.csproj
dotnet build experiments/taskbar-integration/TaskbarIntegrationPoc/TaskbarIntegrationPoc.csproj -c Release --no-restore -warnaserror
```

The Windows desktop runtime may not be installed on the test machine. A self-contained Windows build avoids that dependency:

```bash
dotnet publish experiments/taskbar-integration/TaskbarIntegrationPoc/TaskbarIntegrationPoc.csproj \
  -c Release \
  -r win-x64 \
  --self-contained true \
  -o <publish-directory>
```

Choose a publish directory outside the repository, then run the published executable from an interactive Windows desktop session. Do not run it from a headless CI agent or a non-interactive service session; the result would not prove taskbar hosting.

```powershell
.\BaboJUPulse.TaskbarIntegrationPoc.exe
```

Optional arguments:

```powershell
# Prove that attachment failure leaves the process alive in tray fallback mode.
.\BaboJUPulse.TaskbarIntegrationPoc.exe --simulate-attach-failure

# Exit automatically after 15 seconds, useful for a repeatable smoke run.
.\BaboJUPulse.TaskbarIntegrationPoc.exe --exit-after-seconds 15

# Write lifecycle and attachment diagnostics to %TEMP%\BaboJUPulse.TaskbarIntegrationPoc.log.
.\BaboJUPulse.TaskbarIntegrationPoc.exe --diagnostic-log
```

## Expected observation

- A dark rounded readout labeled `SYNTH` appears inside the actual taskbar, in the free space selected by the candidate. It is not a top-level window and it is not a tray-only display.
- The text changes once per second, for example `CPU 42%  RAM 69%`.
- The rest of the taskbar remains usable: Start, app buttons, notification area, and clock still respond.
- Clicking the readout `x` or the tray menu **Exit** ends the process without leaving a taskbar artifact.
- With `--simulate-attach-failure`, no readout appears. The tray icon remains and reports that the fallback is running.

## Manual verification checklist

Use this checklist when running the experiment on a Windows machine. Record the OS edition, version, build, architecture, display scaling, taskbar alignment, privilege level, and whether the session is interactive.

| Scenario | Expected | Observed |
| --- | --- | --- |
| Core: attach and update | Readout visible in the taskbar and changes every second | |
| Core: taskbar controls | Start, app buttons, notification area, and clock remain usable | |
| Core: no overlap | Readout does not cover taskbar buttons or the notification area in the normal layout | |
| Core: ordinary user | Runs without elevation | |
| Core: exit | `x` and tray **Exit** remove the readout and end the process | |
| Layout: centered taskbar | Readout appears in a free gap without covering the centered group | |
| Layout: left-aligned taskbar | Readout appears in the documented placement | |
| Layout: crowded taskbar | Observe whether the candidate shrinks, moves, or overlaps | |
| Layout: DPI 100/125/150/200% | Readout remains aligned and readable after the candidate's recreation event | |
| Layout: resolution change | Readout follows the taskbar or degrades safely | |
| Layout: multi-monitor | Readout stays on the preferred taskbar or degrades safely | |
| Layout: taskbar edge | Readout follows the edge where the OS supports moving it | |
| Layout: auto-hide | Readout follows the taskbar or degrades safely | |
| Layout: fullscreen app | Readout behavior matches the taskbar behavior | |
| Layout: light/dark theme | Readout remains readable | |
| Lifecycle: relaunch | A second launch attaches or reports a clear failure | |
| Lifecycle: Explorer restart | The candidate recreates the hosted window or the tray fallback survives | |
| Lifecycle: attach failure | Process survives in tray fallback with no orphan window | |
| Lifecycle: clean exit | No orphan window, tray icon, or process remains | |
| Windows 10 | Assess only from upstream compatibility evidence; do not infer from this build | |

Do not change display scaling, taskbar alignment, auto-hide, monitor topology, or restart Explorer unless the maintainer has approved the change for the test session. Restore every changed setting afterward.

## Troubleshooting

If no readout appears, run with `--diagnostic-log` and inspect the lifecycle entries in `%TEMP%\BaboJUPulse.TaskbarIntegrationPoc.log`. The log records the hosted window handle, its parent, the discovered taskbar handle, and the `SetParent` repair result and Win32 error. The process stays alive in tray fallback when attachment fails.

On the Windows 11 environment used for Issue #20, attachment succeeded on the first run and then failed after an Explorer restart: `SetParent` returned `ERROR_INVALID_PARAMETER` (87), the same failure occurred for a plain Win32 window and for the upstream WPF sample, and the process remained in tray fallback. Treat that as a recorded experiment result, not a defect in the readout content.

## Technique and support status

The candidate discovers `Shell_TrayWnd` or `Shell_SecondaryTrayWnd`, changes the app window to a child window, calls `SetParent`, and positions it with `SetWindowPos` and `SetWindowRgn`. It uses UI Automation and the `TaskbarAl` registry value to find free space, and polls for Explorer restarts and DPI changes.

`SetParent` is a public Win32 API. Parenting an application window under Explorer's taskbar is **not a documented, supported shell extension contract**. The candidate depends on undocumented window class names, taskbar internals, and UI Automation behavior. A successful PoC on one build is evidence for that build, not a guarantee of supported or future-proof integration.

## License

`Deskband11Lib.Wpf` 1.5.1 is MIT-licensed. No upstream source is copied into this repository; the experiment consumes the pinned NuGet package.
