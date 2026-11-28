using System.Runtime.InteropServices;

namespace BaboJUPulse.TaskbarIntegrationPoc;

internal static class WindowProbe
{
    [DllImport("user32.dll", EntryPoint = "FindWindowW", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern nint FindWindow(string? className, string? windowName);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern nint GetParent(nint windowHandle);

    [DllImport("user32.dll", SetLastError = true)]
    private static extern nint SetParent(nint childWindow, nint newParent);

    [DllImport("user32.dll", SetLastError = true)]
    [return: MarshalAs(UnmanagedType.Bool)]
    private static extern bool IsWindow(nint windowHandle);

    public static nint FindTaskbar() => FindWindow("Shell_TrayWnd", null);

    public static nint ParentOf(nint windowHandle) => GetParent(windowHandle);

    public static bool Exists(nint windowHandle) => IsWindow(windowHandle);

    public static bool IsHostedBy(nint windowHandle, nint parentWindow) =>
        windowHandle != 0 && parentWindow != 0 && ParentOf(windowHandle) == parentWindow;

    public static (nint PreviousParent, int Error) Reparent(nint childWindow, nint newParent)
    {
        Marshal.SetLastPInvokeError(0);
        var previousParent = SetParent(childWindow, newParent);
        return (previousParent, Marshal.GetLastPInvokeError());
    }
}
