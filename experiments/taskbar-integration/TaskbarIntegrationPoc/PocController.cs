using System;
using System.ComponentModel;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Threading;
using Deskband11Lib.Wpf;

namespace BaboJUPulse.TaskbarIntegrationPoc;

internal sealed class PocController : IDisposable
{
    private readonly Dispatcher _dispatcher;
    private readonly PocOptions _options;
    private readonly SyntheticMetricSource _metricSource = new();
    private readonly TrayIcon _tray;
    private readonly DispatcherTimer _metricTimer;
    private readonly DispatcherTimer? _exitTimer;
    private MainWindow? _window;
    private bool _isRecreating;
    private bool _isDisposed;

    public PocController(Dispatcher dispatcher, PocOptions options)
    {
        _dispatcher = dispatcher;
        _options = options;
        _tray = new TrayIcon("Starting taskbar PoC...");
        _tray.ExitRequested += OnExitRequested;

        _metricTimer = new DispatcherTimer(DispatcherPriority.Background, dispatcher)
        {
            Interval = TimeSpan.FromSeconds(1),
        };
        _metricTimer.Tick += OnMetricTimerTick;

        if (options.ExitAfter is { } exitAfter)
        {
            _exitTimer = new DispatcherTimer(DispatcherPriority.Normal, dispatcher)
            {
                Interval = exitAfter,
            };
            _exitTimer.Tick += OnExitTimerTick;
        }
    }

    public async Task StartAsync()
    {
        _metricTimer.Start();
        _exitTimer?.Start();

        if (_options.SimulateAttachFailure)
        {
            _tray.SetStatus("Simulated attach failure; tray fallback is running");
            return;
        }

        await AttachAsync();
    }

    public void Dispose()
    {
        if (_isDisposed)
        {
            return;
        }

        _isDisposed = true;
        PocDiagnostics.Write("app:dispose");
        _metricTimer.Stop();
        _metricTimer.Tick -= OnMetricTimerTick;

        if (_exitTimer is not null)
        {
            _exitTimer.Stop();
            _exitTimer.Tick -= OnExitTimerTick;
        }

        _tray.ExitRequested -= OnExitRequested;
        DisposeWindow();
        _tray.Dispose();
        GC.SuppressFinalize(this);
    }

    private async Task AttachAsync()
    {
        PocDiagnostics.Write("attach:begin");
        var window = new MainWindow();
        _window = window;
        window.ExitRequested += OnWindowExitRequested;
        window.Host.TaskbarWindowRecreationRequired += OnRecreationRequired;

        try
        {
            await window.AttachAsync();
            LogWindowState("attach:returned", window);
            if (!EnsureHostedByTaskbar(window))
            {
                FailAttachment(window, "Attach did not parent to the taskbar; tray fallback is running");
                return;
            }

            window.Show();
            LogWindowState("attach:shown", window);
            _tray.SetStatus("Attached to taskbar; SYNTH values are updating");
        }
        catch (ObjectDisposedException exception)
        {
            LogFailure("attach", exception, window);
            FailAttachment(window, "Attach failed; tray fallback is running");
        }
        catch (InvalidOperationException exception)
        {
            LogFailure("attach", exception, window);
            FailAttachment(window, "Attach failed; tray fallback is running");
        }
        catch (COMException exception)
        {
            LogFailure("attach", exception, window);
            FailAttachment(window, "Attach failed; tray fallback is running");
        }
        catch (Win32Exception exception)
        {
            LogFailure("attach", exception, window);
            FailAttachment(window, "Attach failed; tray fallback is running");
        }
    }

    private static bool EnsureHostedByTaskbar(MainWindow window)
    {
        var handle = window.WindowHandle;
        var taskbar = WindowProbe.FindTaskbar();
        if (WindowProbe.IsHostedBy(handle, taskbar))
        {
            return true;
        }

        var (previousParent, error) = WindowProbe.Reparent(handle, taskbar);
        var hosted = WindowProbe.IsHostedBy(handle, taskbar);
        PocDiagnostics.Write(
            $"attach:repair hosted={hosted} previousParent=0x{previousParent.ToInt64():X} " +
            $"error={error} parent=0x{WindowProbe.ParentOf(handle).ToInt64():X} " +
            $"taskbar=0x{taskbar.ToInt64():X}");

        if (hosted)
        {
            window.Host.RefreshLayout();
        }

        return hosted;
    }

    private async Task RecreateAsync()
    {
        PocDiagnostics.Write("recreate:begin");
        DisposeWindow();
        await Task.Delay(TimeSpan.FromSeconds(1));
        await AttachAsync();
        PocDiagnostics.Write("recreate:end");
    }

    private void FailAttachment(MainWindow window, string status)
    {
        if (ReferenceEquals(_window, window))
        {
            _window = null;
        }

        window.Host.TaskbarWindowRecreationRequired -= OnRecreationRequired;
        window.ExitRequested -= OnWindowExitRequested;
        window.Dispose();
        if (window.IsWindowAlive() && window.IsLoaded)
        {
            window.Close();
        }

        _tray.SetStatus(status);
        PocDiagnostics.Write("attach:fallback");
    }

    private void DisposeWindow()
    {
        var window = _window;
        _window = null;
        if (window is null)
        {
            return;
        }

        LogWindowState("dispose:window", window);
        window.Host.TaskbarWindowRecreationRequired -= OnRecreationRequired;
        window.ExitRequested -= OnWindowExitRequested;
        window.Dispose();
        if (window.IsWindowAlive() && window.IsLoaded)
        {
            window.Close();
        }
    }

    private static void LogFailure(string operation, Exception exception, MainWindow window)
    {
        var handle = window.WindowHandle;
        PocDiagnostics.Write(
            $"{operation}:error type={exception.GetType().Name} message={exception.Message} " +
            $"hwnd=0x{handle.ToInt64():X} parent=0x{WindowProbe.ParentOf(handle).ToInt64():X} " +
            $"taskbar=0x{WindowProbe.FindTaskbar().ToInt64():X}");
    }

    private static void LogWindowState(string operation, MainWindow window)
    {
        var handle = window.WindowHandle;
        PocDiagnostics.Write(
            $"{operation} attached={window.Host.IsAttached} edge={window.Host.TaskbarEdge} " +
            $"hwnd=0x{handle.ToInt64():X} parent=0x{WindowProbe.ParentOf(handle).ToInt64():X} " +
            $"taskbar=0x{WindowProbe.FindTaskbar().ToInt64():X} alive={WindowProbe.Exists(handle)}");
    }

    private void OnMetricTimerTick(object? sender, EventArgs e)
    {
        var window = _window;
        if (window is null)
        {
            return;
        }

        var sample = _metricSource.Next();
        window.UpdateMetrics(sample.CpuPercent, sample.RamPercent);
    }

    private async void OnRecreationRequired(object? sender, EventArgs e)
    {
        if (_isRecreating || _isDisposed)
        {
            return;
        }

        _isRecreating = true;
        try
        {
            PocDiagnostics.Write("recreate:required");
            _tray.SetStatus("Taskbar changed; reattaching...");
            await RecreateAsync();
        }
        catch (ObjectDisposedException exception)
        {
            PocDiagnostics.Write($"recreate:error type={exception.GetType().Name} message={exception.Message}");
            _tray.SetStatus("Reattach failed; tray fallback is running");
        }
        catch (InvalidOperationException exception)
        {
            PocDiagnostics.Write($"recreate:error type={exception.GetType().Name} message={exception.Message}");
            _tray.SetStatus("Reattach failed; tray fallback is running");
        }
        catch (COMException exception)
        {
            PocDiagnostics.Write($"recreate:error type={exception.GetType().Name} message={exception.Message}");
            _tray.SetStatus("Reattach failed; tray fallback is running");
        }
        catch (Win32Exception exception)
        {
            PocDiagnostics.Write($"recreate:error type={exception.GetType().Name} message={exception.Message}");
            _tray.SetStatus("Reattach failed; tray fallback is running");
        }
        finally
        {
            _isRecreating = false;
        }
    }

    private void OnWindowExitRequested(object? sender, EventArgs e) => RequestShutdown();

    private void OnExitRequested(object? sender, EventArgs e) => RequestShutdown();

    private void OnExitTimerTick(object? sender, EventArgs e)
    {
        _exitTimer?.Stop();
        RequestShutdown();
    }

    private void RequestShutdown()
    {
        if (_dispatcher.CheckAccess())
        {
            System.Windows.Application.Current.Shutdown();
            return;
        }

        _ = _dispatcher.BeginInvoke(new Action(System.Windows.Application.Current.Shutdown));
    }
}
