using System.Diagnostics.CodeAnalysis;
using System.Windows;
using System.Windows.Threading;
using BaboJUPulse.TaskbarOverlayPoc.Core;
using Microsoft.Win32;

namespace BaboJUPulse.TaskbarOverlayPoc;

internal sealed class PocController : IDisposable
{
    private const double DesiredWidthDip = 300;
    private const double DesiredHeightDip = 36;

    private readonly Dispatcher _dispatcher;
    private readonly PocOptions _options;
    private readonly PocLog _log;
    private readonly SyntheticMetricSource _metrics = new();
    private readonly OverlayWindow _overlay;
    private readonly TrayIcon _tray;
    private readonly DispatcherTimer _metricTimer;
    private readonly DispatcherTimer _layoutTimer;
    private readonly DispatcherTimer? _exitTimer;
    private bool _isDisposed;
    private bool _isRefreshing;
    private PixelRect? _currentSlot;
    private TaskbarSnapshot? _lastTaskbar;
    private string? _lastHideReason;
    private bool _occlusionDetected;
    private int _occlusionRetryCountdown;
    private bool _placementDirty;

    public PocController(Dispatcher dispatcher, PocOptions options)
    {
        _dispatcher = dispatcher;
        _options = options;
        _log = new PocLog(options.DiagnosticLog);
        _overlay = new OverlayWindow();
        _overlay.ExitRequested += OnExitRequested;
        _tray = new TrayIcon();
        _tray.ExitRequested += OnExitRequested;

        _metricTimer = new DispatcherTimer(DispatcherPriority.Background, dispatcher)
        {
            Interval = TimeSpan.FromSeconds(1),
        };
        _metricTimer.Tick += OnMetricTick;

        _layoutTimer = new DispatcherTimer(DispatcherPriority.Background, dispatcher)
        {
            Interval = TimeSpan.FromSeconds(2),
        };
        _layoutTimer.Tick += OnLayoutTick;

        if (options.ExitAfter is { } exitAfter)
        {
            _exitTimer = new DispatcherTimer(DispatcherPriority.Normal, dispatcher)
            {
                Interval = exitAfter,
            };
            _exitTimer.Tick += OnExitTimerTick;
        }

        SystemEvents.DisplaySettingsChanged += OnDisplaySettingsChanged;
        SystemEvents.UserPreferenceChanged += OnUserPreferenceChanged;
    }

    public void Start()
    {
        _log.Write("app:start");
        _overlay.CreateAndHide();
        UpdateMetrics();
        _metricTimer.Start();
        _layoutTimer.Start();
        _exitTimer?.Start();
        RefreshLayout();
    }

    public void Dispose()
    {
        if (_isDisposed)
        {
            return;
        }

        _isDisposed = true;
        _log.Write("app:dispose");
        SystemEvents.DisplaySettingsChanged -= OnDisplaySettingsChanged;
        SystemEvents.UserPreferenceChanged -= OnUserPreferenceChanged;

        _metricTimer.Stop();
        _metricTimer.Tick -= OnMetricTick;
        _layoutTimer.Stop();
        _layoutTimer.Tick -= OnLayoutTick;

        if (_exitTimer is not null)
        {
            _exitTimer.Stop();
            _exitTimer.Tick -= OnExitTimerTick;
        }

        _overlay.ExitRequested -= OnExitRequested;
        _overlay.HideOverlay();
        _overlay.Close();
        _tray.ExitRequested -= OnExitRequested;
        _tray.Dispose();
        _log.Dispose();
        GC.SuppressFinalize(this);
    }

    private void RefreshLayout()
    {
        if (_isDisposed || _isRefreshing)
        {
            return;
        }

        _isRefreshing = true;

        try
        {
            if (!TryGetPlacement(out var taskbar, out var occupied, out var reason))
            {
                Hide(reason);
                return;
            }

            var slot = FindTargetSlot(taskbar, occupied, out reason);
            if (slot is null)
            {
                Hide(reason);
                return;
            }

            ApplyPlacement(taskbar, slot.GetValueOrDefault(), occupied);
        }
        finally
        {
            _isRefreshing = false;
        }
    }

    private bool TryGetPlacement(
        [NotNullWhen(true)] out TaskbarSnapshot? taskbar,
        out IReadOnlyList<PixelRect> occupied,
        out string reason)
    {
        taskbar = null;
        occupied = Array.Empty<PixelRect>();

        if (_options.SimulateDiscoveryFailure)
        {
            reason = "simulated discovery failure";
            return false;
        }

        if (_options.SimulateNoSafeSlot)
        {
            reason = "simulated no safe slot";
            return false;
        }

        if (!TaskbarDiscovery.TryFind(out var found) || found is null)
        {
            reason = "taskbar not found";
            return false;
        }

        taskbar = found;
        var taskbarChanged = !SameTaskbar(_lastTaskbar, found);
        LogTaskbarIfChanged(found);

        if (taskbarChanged)
        {
            _occlusionDetected = false;
            _occlusionRetryCountdown = 0;
            _placementDirty = true;
        }

        if (_occlusionDetected && !_options.PreviewAboveTaskbar)
        {
            if (_occlusionRetryCountdown > 0)
            {
                _occlusionRetryCountdown--;
                reason = "overlay occluded by taskbar";
                return false;
            }

            _occlusionDetected = false;
        }

        if (found.IsVertical)
        {
            reason = "vertical taskbar unsupported";
            return false;
        }

        if (found.IsAutoHide)
        {
            reason = "auto-hide enabled";
            return false;
        }

        if (TryGetObscuredReason(found, out reason))
        {
            return false;
        }

        if (!TaskbarContentScanner.TryGetOccupied(found, out occupied))
        {
            reason = "taskbar content scan failed";
            return false;
        }

        reason = string.Empty;
        return true;
    }

    private PixelRect? FindTargetSlot(
        TaskbarSnapshot taskbar,
        IReadOnlyList<PixelRect> occupied,
        out string reason)
    {
        reason = string.Empty;
        var margin = Math.Max(2, (int)Math.Round(4.0 * taskbar.Dpi / 96.0));
        var heightDip = CalculateOverlayHeightDip(taskbar, margin);
        if (heightDip < 28)
        {
            reason = "taskbar too short";
            return null;
        }

        var widthPixels = (int)Math.Round(DesiredWidthDip * taskbar.Dpi / 96.0);
        var heightPixels = (int)Math.Round(heightDip * taskbar.Dpi / 96.0);
        var slot = TaskbarLayout.FindHorizontalSlot(
            taskbar.Bounds,
            occupied,
            widthPixels,
            heightPixels,
            margin);

        if (slot is null)
        {
            reason = "no safe gap";
            return null;
        }

        var placedSlot = slot.GetValueOrDefault();
        if (!_options.PreviewAboveTaskbar)
        {
            return placedSlot;
        }

        var previewTop = taskbar.Bounds.Top - heightPixels - margin;
        if (previewTop < taskbar.MonitorBounds.Top)
        {
            reason = "preview position unavailable";
            return null;
        }

        return new PixelRect(
            placedSlot.Left,
            previewTop,
            placedSlot.Left + widthPixels,
            previewTop + heightPixels);
    }

    private void ApplyPlacement(
        TaskbarSnapshot taskbar,
        PixelRect targetSlot,
        IReadOnlyList<PixelRect> occupied)
    {
        if (_overlay.IsOverlayVisible && _currentSlot == targetSlot && !_placementDirty)
        {
            if (IsOverlayOnTop(targetSlot))
            {
                _currentSlot = targetSlot;
                return;
            }

            _log.Write(
                FormattableString.Invariant($"overlay:occluded rect={targetSlot}"));
            _occlusionDetected = true;
            _occlusionRetryCountdown = 10;
            Hide("overlay occluded by taskbar");
            return;
        }

        _overlay.Place(targetSlot, taskbar.Dpi);
        if (!_overlay.IsOverlayVisible)
        {
            Hide("SetWindowPos failed");
            return;
        }

        if (!IsOverlayOnTop(targetSlot))
        {
            _log.Write(
                FormattableString.Invariant($"overlay:occluded rect={targetSlot}"));
            _occlusionDetected = true;
            _occlusionRetryCountdown = 10;
            Hide("overlay occluded by taskbar");
            return;
        }

        _occlusionDetected = false;
        _placementDirty = false;
        _currentSlot = targetSlot;
        _lastHideReason = null;
        _log.Write(
            FormattableString.Invariant(
                $"{(_options.PreviewAboveTaskbar ? "preview" : "layout")}:show rect={targetSlot} dpi={taskbar.Dpi} occupied={occupied.Count}"));
        _tray.SetStatus(
            _options.PreviewAboveTaskbar
                ? "Preview above taskbar (control only)"
                : "Overlay active; SYNTH values updating");
    }

    private void Hide(string reason)
    {
        var wasVisible = _overlay.IsOverlayVisible;
        _overlay.HideOverlay();
        _currentSlot = null;

        if (!wasVisible && string.Equals(_lastHideReason, reason, StringComparison.Ordinal))
        {
            return;
        }

        _lastHideReason = reason;
        _log.Write($"layout:hide reason={reason}");
        _tray.SetStatus($"Overlay hidden: {reason}");
    }

    private bool TryGetObscuredReason(TaskbarSnapshot taskbar, out string reason)
    {
        reason = string.Empty;

        if (NativeMethods.SHQueryUserNotificationState(out var notificationState) == 0
            && notificationState is NativeMethods.QueryUserNotificationState.Busy
                or NativeMethods.QueryUserNotificationState.RunningDirect3DFullScreen
                or NativeMethods.QueryUserNotificationState.PresentationMode)
        {
            reason = "fullscreen-or-busy";
            return true;
        }

        var foreground = NativeMethods.GetForegroundWindow();
        if (foreground == 0
            || foreground == _overlay.Handle
            || foreground == taskbar.Handle
            || foreground == NativeMethods.GetDesktopWindow()
            || foreground == NativeMethods.GetShellWindow())
        {
            return false;
        }

        var className = NativeMethods.ReadClassName(foreground);
        if (!NativeMethods.GetWindowRect(foreground, out var foregroundRect))
        {
            return false;
        }

        var foregroundBounds = NativeMethods.ToPixelRect(foregroundRect);
        var target = _currentSlot ?? taskbar.Bounds;

        if (IsAlwaysHiddenShellPopup(className) && NativeMethods.IsWindowVisible(foreground))
        {
            reason = "shell-popup";
            return true;
        }

        if (IsOverlappingShellSurface(className, foregroundBounds, target))
        {
            reason = "shell-popup";
            return true;
        }

        if (CoversMonitor(foregroundBounds, taskbar.MonitorBounds))
        {
            reason = "fullscreen-foreground";
            return true;
        }

        if (IsTopmost(foreground) && foregroundBounds.IntersectsWith(target))
        {
            reason = "topmost-foreground-overlap";
            return true;
        }

        return false;
    }

    private static bool IsAlwaysHiddenShellPopup(string className) =>
        className is "XamlExplorerHostIslandWindow"
            or "NotifyIconOverflowWindow"
            or "TopLevelWindowForOverflowXamlIsland";

    private static bool IsOverlappingShellSurface(
        string className,
        PixelRect foreground,
        PixelRect target) =>
        (className is "Windows.UI.Core.CoreWindow" or "#32768")
        && foreground.IntersectsWith(target);

    private static bool CoversMonitor(PixelRect foreground, PixelRect monitor) =>
        foreground.Left <= monitor.Left
        && foreground.Top <= monitor.Top
        && foreground.Right >= monitor.Right
        && foreground.Bottom >= monitor.Bottom;

    private static bool IsTopmost(nint window) =>
        (NativeMethods.GetWindowLongPtr(window, NativeMethods.GwlExStyle).ToInt64()
            & NativeMethods.WsExTopmost) != 0;

    private bool IsOverlayOnTop(PixelRect slot)
    {
        var centerY = slot.Top + (slot.Height / 2);
        int[] sampleXs =
        [
            slot.Left + (slot.Width / 4),
            slot.Left + (slot.Width / 2),
            slot.Left + ((slot.Width * 3) / 4),
        ];

        foreach (var x in sampleXs)
        {
            var point = new NativeMethods.Point
            {
                X = x,
                Y = centerY,
            };

            var hit = NativeMethods.WindowFromPoint(point);
            if (hit == 0
                || (hit != _overlay.Handle
                    && NativeMethods.GetAncestor(hit, NativeMethods.GaRoot) != _overlay.Handle))
            {
                return false;
            }
        }

        return true;
    }

    private static double CalculateOverlayHeightDip(TaskbarSnapshot taskbar, int marginPixels)
    {
        var taskbarHeightDip = taskbar.Bounds.Height * 96.0 / taskbar.Dpi;
        var marginDip = marginPixels * 96.0 / taskbar.Dpi;
        return Math.Min(DesiredHeightDip, taskbarHeightDip - (2.0 * marginDip));
    }

    private static bool SameTaskbar(TaskbarSnapshot? previous, TaskbarSnapshot current) =>
        previous is not null
        && previous.Handle == current.Handle
        && previous.Bounds == current.Bounds
        && previous.MonitorBounds == current.MonitorBounds
        && previous.Dpi == current.Dpi
        && previous.IsVertical == current.IsVertical
        && previous.IsAutoHide == current.IsAutoHide;

    private void LogTaskbarIfChanged(TaskbarSnapshot taskbar)
    {
        if (SameTaskbar(_lastTaskbar, taskbar))
        {
            return;
        }

        _lastTaskbar = taskbar;
        _log.Write(
            FormattableString.Invariant(
                $"taskbar:found handle=0x{taskbar.Handle.ToInt64():X} rect={taskbar.Bounds} dpi={taskbar.Dpi} vertical={taskbar.IsVertical} autohide={taskbar.IsAutoHide}"));
    }

    private void UpdateMetrics()
    {
        var sample = _metrics.Next();
        _overlay.SetMetrics(sample.CpuPercent, sample.RamPercent);
    }

    private void OnMetricTick(object? sender, EventArgs e) => UpdateMetrics();

    private void OnLayoutTick(object? sender, EventArgs e) => RefreshLayout();

    private void OnExitTimerTick(object? sender, EventArgs e)
    {
        _exitTimer?.Stop();
        RequestShutdown();
    }

    private void OnExitRequested(object? sender, EventArgs e) => RequestShutdown();

    private void RequestShutdown()
    {
        if (_isDisposed)
        {
            return;
        }

        _log.Write("app:shutdown-requested");
        _dispatcher.BeginInvoke(
            DispatcherPriority.Normal,
            new Action(() => System.Windows.Application.Current.Shutdown(0)));
    }

    private void OnDisplaySettingsChanged(object? sender, EventArgs e) =>
        QueueRefresh("display-settings");

    private void OnUserPreferenceChanged(object? sender, UserPreferenceChangedEventArgs e)
    {
        if (e.Category is UserPreferenceCategory.Color
            or UserPreferenceCategory.Desktop
            or UserPreferenceCategory.General
            or UserPreferenceCategory.VisualStyle
            or UserPreferenceCategory.Window)
        {
            QueueRefresh("user-preference");
        }
    }

    private void QueueRefresh(string trigger)
    {
        if (_isDisposed)
        {
            return;
        }

        _dispatcher.BeginInvoke(
            DispatcherPriority.Background,
            new Action(() =>
            {
                _log.Write($"layout:refresh trigger={trigger}");
                RefreshLayout();
            }));
    }
}
