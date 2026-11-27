using System.Windows;

namespace BaboJUPulse;

public partial class App : Application
{
    protected override void OnStartup(StartupEventArgs e)
    {
        base.OnStartup(e);

        // The foundation build has no tray or taskbar host yet. Exit cleanly so
        // `dotnet run` is a smoke test instead of an invisible background process.
        // Remove this call when the first host is added; ShutdownMode stays explicit.
        Shutdown();
    }
}
