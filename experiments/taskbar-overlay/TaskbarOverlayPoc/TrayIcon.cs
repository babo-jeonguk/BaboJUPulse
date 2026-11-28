using System.Drawing;
using System.Windows.Forms;

namespace BaboJUPulse.TaskbarOverlayPoc;

internal sealed class TrayIcon : IDisposable
{
    private const int MaximumTooltipLength = 63;

    private readonly NotifyIcon _notifyIcon;
    private readonly ContextMenuStrip _menu;
    private readonly ToolStripMenuItem _statusItem;
    private bool _isDisposed;

    public TrayIcon()
    {
        _statusItem = new ToolStripMenuItem("Starting...")
        {
            Enabled = false,
        };

        var exitItem = new ToolStripMenuItem("Exit");
        exitItem.Click += OnExitClick;

        _menu = new ContextMenuStrip();
        _menu.Items.Add(_statusItem);
        _menu.Items.Add(new ToolStripSeparator());
        _menu.Items.Add(exitItem);

        _notifyIcon = new NotifyIcon
        {
            Icon = SystemIcons.Application,
            Text = "BaboJUPulse taskbar overlay PoC",
            ContextMenuStrip = _menu,
            Visible = true,
        };
    }

    public event EventHandler? ExitRequested;

    public void SetStatus(string status)
    {
        _statusItem.Text = status;
        _notifyIcon.Text = Truncate(status);
    }

    public void Dispose()
    {
        if (_isDisposed)
        {
            return;
        }

        _isDisposed = true;
        _notifyIcon.Visible = false;
        _notifyIcon.Dispose();
        _statusItem.Dispose();
        _menu.Dispose();
        GC.SuppressFinalize(this);
    }

    private static string Truncate(string value) =>
        value.Length <= MaximumTooltipLength
            ? value
            : value[..MaximumTooltipLength];

    private void OnExitClick(object? sender, EventArgs e) =>
        ExitRequested?.Invoke(this, EventArgs.Empty);
}
