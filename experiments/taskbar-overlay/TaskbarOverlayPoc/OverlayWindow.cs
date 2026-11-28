using System.Windows;
using System.Windows.Automation;
using System.Windows.Controls;
using System.Windows.Input;
using System.Windows.Interop;
using System.Windows.Media;
using BaboJUPulse.TaskbarOverlayPoc.Core;

namespace BaboJUPulse.TaskbarOverlayPoc;

internal sealed class OverlayWindow : Window
{
    private readonly TextBlock _cpuText;
    private readonly TextBlock _ramText;
    private nint _handle;

    public OverlayWindow()
    {
        ConfigureWindow();
        _cpuText = CreateMetricText();
        _ramText = CreateMetricText();
        Content = CreateContent();
        SourceInitialized += OnSourceInitialized;
    }

    public event EventHandler? ExitRequested;

    public nint Handle => _handle;

    public bool IsOverlayVisible { get; private set; }

    public void CreateAndHide()
    {
        Show();
        HideOverlay();
    }

    public void Place(PixelRect bounds, uint dpi)
    {
        if (_handle == 0)
        {
            return;
        }

        Width = Math.Max(1, bounds.Width * 96.0 / dpi);
        Height = Math.Max(1, bounds.Height * 96.0 / dpi);

        IsOverlayVisible = NativeMethods.SetWindowPos(
            _handle,
            NativeMethods.HwndTopmost,
            bounds.Left,
            bounds.Top,
            bounds.Width,
            bounds.Height,
            NativeMethods.SwpNoActivate
                | NativeMethods.SwpShowWindow
                | NativeMethods.SwpNoOwnerZOrder);
    }

    public void HideOverlay()
    {
        if (_handle != 0)
        {
            NativeMethods.ShowWindow(_handle, NativeMethods.SwHide);
        }

        IsOverlayVisible = false;
    }

    public void SetMetrics(int cpuPercent, int ramPercent)
    {
        _cpuText.Text = $"CPU {cpuPercent}%";
        _ramText.Text = $"RAM {ramPercent}%";
        AutomationProperties.SetName(_cpuText, $"Synthetic CPU {cpuPercent} percent");
        AutomationProperties.SetName(_ramText, $"Synthetic RAM {ramPercent} percent");
    }

    protected override void OnClosed(EventArgs e)
    {
        _handle = 0;
        IsOverlayVisible = false;
        base.OnClosed(e);
    }

    private void ConfigureWindow()
    {
        Title = "BaboJUPulse Taskbar Overlay PoC";
        WindowStyle = WindowStyle.None;
        ResizeMode = ResizeMode.NoResize;
        AllowsTransparency = true;
        Background = Brushes.Transparent;
        ShowInTaskbar = false;
        ShowActivated = false;
        Topmost = true;
        WindowStartupLocation = WindowStartupLocation.Manual;
        Left = -10000;
        Top = -10000;
        Width = 300;
        Height = 36;
        UseLayoutRounding = true;
        SnapsToDevicePixels = true;
    }

    private Border CreateContent()
    {
        var stack = new StackPanel
        {
            Orientation = Orientation.Horizontal,
            VerticalAlignment = VerticalAlignment.Center,
        };
        stack.Children.Add(CreateSyntheticLabel());
        stack.Children.Add(_cpuText);
        stack.Children.Add(_ramText);
        stack.Children.Add(CreateExitButton());

        return new Border
        {
            Background = new SolidColorBrush(Color.FromArgb(255, 18, 24, 38)),
            BorderBrush = new SolidColorBrush(Color.FromArgb(110, 255, 255, 255)),
            BorderThickness = new Thickness(1),
            CornerRadius = new CornerRadius(10),
            Padding = new Thickness(10, 2, 2, 2),
            Child = stack,
        };
    }

    private static TextBlock CreateSyntheticLabel() =>
        new()
        {
            Text = "SYNTH",
            FontFamily = new FontFamily("Segoe UI"),
            FontSize = 11,
            FontWeight = FontWeights.SemiBold,
            Foreground = new SolidColorBrush(Color.FromRgb(143, 211, 255)),
            VerticalAlignment = VerticalAlignment.Center,
        };

    private static TextBlock CreateMetricText()
    {
        var text = new TextBlock
        {
            Width = 64,
            Margin = new Thickness(8, 0, 0, 0),
            FontFamily = new FontFamily("Segoe UI"),
            FontSize = 13,
            FontWeight = FontWeights.SemiBold,
            Foreground = Brushes.White,
            TextAlignment = TextAlignment.Center,
            VerticalAlignment = VerticalAlignment.Center,
        };

        return text;
    }

    private Button CreateExitButton()
    {
        var button = new Button
        {
            Content = "×",
            Width = 22,
            Height = 22,
            Margin = new Thickness(8, 0, 0, 0),
            Padding = new Thickness(0),
            Background = Brushes.Transparent,
            BorderThickness = new Thickness(0),
            Foreground = Brushes.White,
            FontFamily = new FontFamily("Segoe UI"),
            FontSize = 14,
            Focusable = false,
            IsTabStop = false,
            ToolTip = "Exit taskbar overlay",
            Cursor = Cursors.Hand,
        };

        button.Click += OnExitClick;
        AutomationProperties.SetName(button, "Exit taskbar overlay");
        return button;
    }

    private void OnSourceInitialized(object? sender, EventArgs e)
    {
        _handle = new WindowInteropHelper(this).Handle;
        ApplyNoActivateStyles();
    }

    private void ApplyNoActivateStyles()
    {
        if (_handle == 0)
        {
            return;
        }

        var extendedStyle = NativeMethods.GetWindowLongPtr(_handle, NativeMethods.GwlExStyle).ToInt64();
        extendedStyle |= NativeMethods.WsExToolWindow
            | NativeMethods.WsExNoActivate
            | NativeMethods.WsExTopmost;
        extendedStyle &= ~NativeMethods.WsExAppWindow;

        NativeMethods.SetWindowLongPtr(
            _handle,
            NativeMethods.GwlExStyle,
            new nint(extendedStyle));

        NativeMethods.SetWindowPos(
            _handle,
            0,
            0,
            0,
            0,
            0,
            NativeMethods.SwpNoMove
                | NativeMethods.SwpNoSize
                | NativeMethods.SwpNoZOrder
                | NativeMethods.SwpNoActivate
                | NativeMethods.SwpFrameChanged);
    }

    private void OnExitClick(object? sender, RoutedEventArgs e) =>
        ExitRequested?.Invoke(this, EventArgs.Empty);
}
