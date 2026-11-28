using System;
using System.Windows;

namespace BaboJUPulse.TaskbarIntegrationPoc;

public partial class TaskbarReadout : System.Windows.Controls.UserControl
{
    public TaskbarReadout() => InitializeComponent();

    public event EventHandler? ExitRequested;

    public void UpdateMetrics(int cpuPercent, int ramPercent) =>
        MetricText.Text = $"CPU {cpuPercent}%  RAM {ramPercent}%";

    private void OnExitButtonClicked(object sender, RoutedEventArgs e) =>
        ExitRequested?.Invoke(this, EventArgs.Empty);
}
