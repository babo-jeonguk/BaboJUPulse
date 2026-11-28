using System;
using System.Drawing;
using System.Windows.Forms;

namespace BaboJUPulse.TaskbarIntegrationPoc;

internal sealed class TrayIcon : IDisposable
{
    private readonly NotifyIcon _notifyIcon;
    private readonly ContextMenuStrip _contextMenu;
    private readonly ToolStripMenuItem _statusItem;
    private bool _isDisposed;

    public TrayIcon(string status)
    {
        _statusItem = new ToolStripMenuItem(status)
        {
            Enabled = false,
        };

        var exitItem = new ToolStripMenuItem("Exit");
        exitItem.Click += OnExitItemClicked;

        _contextMenu = new ContextMenuStrip
        {
            ShowImageMargin = false,
        };
        _contextMenu.Items.Add(_statusItem);
        _contextMenu.Items.Add(new ToolStripSeparator());
        _contextMenu.Items.Add(exitItem);

        _notifyIcon = new NotifyIcon
        {
            Icon = SystemIcons.Application,
            Text = Shorten(status),
            Visible = true,
            ContextMenuStrip = _contextMenu,
        };
    }

    public event EventHandler? ExitRequested;

    public void SetStatus(string status)
    {
        _statusItem.Text = status;
        _notifyIcon.Text = Shorten(status);
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
        _contextMenu.Dispose();
        GC.SuppressFinalize(this);
    }

    private static string Shorten(string status) =>
        status.Length <= 63 ? status : string.Concat(status.AsSpan(0, 60), "...");

    private void OnExitItemClicked(object? sender, EventArgs e) =>
        ExitRequested?.Invoke(this, EventArgs.Empty);
}
