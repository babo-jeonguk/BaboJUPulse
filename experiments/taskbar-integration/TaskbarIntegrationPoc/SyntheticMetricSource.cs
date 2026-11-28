namespace BaboJUPulse.TaskbarIntegrationPoc;

internal sealed class SyntheticMetricSource
{
    private int _tick;

    public (int CpuPercent, int RamPercent) Next()
    {
        _tick++;
        var cpuPercent = 35 + ((_tick * 7) % 41);
        var ramPercent = 48 + ((_tick * 3) % 21);
        return (cpuPercent, ramPercent);
    }
}
