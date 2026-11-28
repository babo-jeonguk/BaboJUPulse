namespace BaboJUPulse.TaskbarOverlayPoc;

internal sealed class SyntheticMetricSource
{
    private int _cpuPercent = 42;
    private int _ramPercent = 63;

    public MetricSample Next()
    {
        _cpuPercent = NextValue(_cpuPercent);
        _ramPercent = NextValue(_ramPercent);
        return new MetricSample(_cpuPercent, _ramPercent);
    }

    private static int NextValue(int current) =>
        Math.Clamp(current + Random.Shared.Next(-7, 8), 5, 95);
}

internal readonly record struct MetricSample(int CpuPercent, int RamPercent);
