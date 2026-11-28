using System;
using System.Windows;

namespace BaboJUPulse.TaskbarIntegrationPoc;

public sealed partial class App : System.Windows.Application, IDisposable
{
    private PocController? _controller;
    private bool _isDisposed;

    public void Dispose()
    {
        if (_isDisposed)
        {
            return;
        }

        _isDisposed = true;
        _controller?.Dispose();
        _controller = null;
        GC.SuppressFinalize(this);
    }

    protected override async void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        PocOptions options;
        try
        {
            options = PocOptions.Parse(e.Args);
        }
        catch (ArgumentException exception)
        {
            System.Windows.MessageBox.Show(
                exception.Message,
                "BaboJUPulse Taskbar Integration PoC",
                MessageBoxButton.OK,
                MessageBoxImage.Warning);
            Shutdown(2);
            return;
        }

        _controller = new PocController(Dispatcher, options);
        PocDiagnostics.IsEnabled = options.DiagnosticLog;
        PocDiagnostics.Write("app:start");
        await _controller.StartAsync();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        Dispose();
        base.OnExit(e);
    }
}
