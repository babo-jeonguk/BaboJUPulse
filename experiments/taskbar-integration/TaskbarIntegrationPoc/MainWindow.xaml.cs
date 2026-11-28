using System;
using System.Threading.Tasks;
using System.Windows;
using System.Windows.Interop;
using Deskband11Lib.Core;
using Deskband11Lib.Wpf;

namespace BaboJUPulse.TaskbarIntegrationPoc;

public sealed partial class MainWindow : Window, IDisposable
{
    private readonly TaskbarContentHost _host;
    private bool _isDisposed;

    public MainWindow()
    {
        InitializeComponent();

        _host = new TaskbarContentHost(this, Readout, new TaskbarContentHostOptions
        {
            PreferredWidth = 320,
            PreferredHeight = 40,
            AnimateLayoutChanges = false,
            Placement = TaskbarContentPlacement.Auto,
        });

        Readout.ExitRequested += OnReadoutExitRequested;
    }

    public event EventHandler? ExitRequested;

    public TaskbarContentHost Host => _host;

    public nint WindowHandle => new WindowInteropHelper(this).Handle;

    public Task AttachAsync() => _host.AttachWhenLayoutReadyAsync();

    public void UpdateMetrics(int cpuPercent, int ramPercent) =>
        Readout.UpdateMetrics(cpuPercent, ramPercent);

    public void Dispose()
    {
        if (_isDisposed)
        {
            return;
        }

        _isDisposed = true;
        Readout.ExitRequested -= OnReadoutExitRequested;
        _host.Dispose();
        GC.SuppressFinalize(this);
    }

    protected override void OnClosed(EventArgs e)
    {
        Dispose();
        base.OnClosed(e);
    }

    private void OnReadoutExitRequested(object? sender, EventArgs e) =>
        ExitRequested?.Invoke(this, EventArgs.Empty);
}
