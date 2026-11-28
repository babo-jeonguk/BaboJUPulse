using System.Runtime.InteropServices;
using BaboJUPulse.TaskbarOverlayPoc.Core;

namespace BaboJUPulse.TaskbarOverlayPoc;

internal static class TaskbarDiscovery
{
    private const string PrimaryTaskbarClass = "Shell_TrayWnd";
    private const string SecondaryTaskbarClass = "Shell_SecondaryTrayWnd";

    public static bool TryFind(out TaskbarSnapshot? snapshot)
    {
        snapshot = null;

        var handle = FindTaskbar();
        if (handle == 0 || !NativeMethods.IsWindow(handle) || !NativeMethods.IsWindowVisible(handle))
        {
            return false;
        }

        if (!NativeMethods.GetWindowRect(handle, out var windowRect))
        {
            return false;
        }

        var bounds = NativeMethods.ToPixelRect(windowRect);
        if (bounds.IsEmpty)
        {
            return false;
        }

        var dpi = NativeMethods.GetDpiForWindow(handle);
        if (dpi == 0)
        {
            dpi = 96;
        }

        var monitorBounds = ReadMonitorBounds(handle, bounds);
        snapshot = new TaskbarSnapshot(
            handle,
            bounds,
            monitorBounds,
            dpi,
            IsVertical: bounds.Height > bounds.Width,
            IsAutoHide: IsAutoHideEnabled());

        return true;
    }

    private static nint FindTaskbar()
    {
        var primary = NativeMethods.FindWindow(PrimaryTaskbarClass, null);
        if (primary != 0)
        {
            return primary;
        }

        return NativeMethods.FindWindow(SecondaryTaskbarClass, null);
    }

    private static PixelRect ReadMonitorBounds(nint taskbar, PixelRect fallback)
    {
        var monitor = NativeMethods.MonitorFromWindow(taskbar, NativeMethods.MonitorDefaultToNearest);
        if (monitor == 0)
        {
            return fallback;
        }

        var info = new NativeMethods.MonitorInfo
        {
            Size = Marshal.SizeOf<NativeMethods.MonitorInfo>(),
        };

        return NativeMethods.GetMonitorInfo(monitor, ref info)
            ? NativeMethods.ToPixelRect(info.Monitor)
            : fallback;
    }

    private static bool IsAutoHideEnabled()
    {
        var data = new NativeMethods.AppBarData
        {
            Size = Marshal.SizeOf<NativeMethods.AppBarData>(),
        };

        var state = NativeMethods.SHAppBarMessage(NativeMethods.AbmGetState, ref data);
        return (state.ToUInt64() & NativeMethods.AbsAutoHide) != 0;
    }
}
