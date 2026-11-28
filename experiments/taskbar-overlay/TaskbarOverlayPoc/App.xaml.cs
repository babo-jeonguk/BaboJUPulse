using System.Windows;

namespace BaboJUPulse.TaskbarOverlayPoc;

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

    protected override void OnStartup(StartupEventArgs e)
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
                "BaboJUPulse Taskbar Overlay PoC",
                MessageBoxButton.OK,
                MessageBoxImage.Warning);
            Shutdown(2);
            return;
        }

        _controller = new PocController(Dispatcher, options);
        _controller.Start();
    }

    protected override void OnExit(ExitEventArgs e)
    {
        Dispose();
        base.OnExit(e);
    }
}
