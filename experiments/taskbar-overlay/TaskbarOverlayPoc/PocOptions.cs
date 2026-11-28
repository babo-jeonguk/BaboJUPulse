using System.Globalization;

namespace BaboJUPulse.TaskbarOverlayPoc;

internal sealed record PocOptions(
    bool DiagnosticLog,
    bool SimulateDiscoveryFailure,
    bool SimulateNoSafeSlot,
    bool PreviewAboveTaskbar,
    TimeSpan? ExitAfter)
{
    public static PocOptions Parse(IReadOnlyList<string> arguments)
    {
        var diagnosticLog = false;
        var simulateDiscoveryFailure = false;
        var simulateNoSafeSlot = false;
        var previewAboveTaskbar = false;
        TimeSpan? exitAfter = null;

        for (var index = 0; index < arguments.Count; index++)
        {
            switch (arguments[index])
            {
                case "--diagnostic-log":
                    diagnosticLog = true;
                    break;
                case "--simulate-discovery-failure":
                    simulateDiscoveryFailure = true;
                    break;
                case "--simulate-no-safe-slot":
                    simulateNoSafeSlot = true;
                    break;
                case "--preview-above-taskbar":
                    previewAboveTaskbar = true;
                    break;
                case "--exit-after-seconds":
                    if (index + 1 >= arguments.Count
                        || !int.TryParse(
                            arguments[++index],
                            NumberStyles.Integer,
                            CultureInfo.InvariantCulture,
                            out var seconds)
                        || seconds <= 0)
                    {
                        throw new ArgumentException(
                            "--exit-after-seconds requires a positive integer.");
                    }

                    exitAfter = TimeSpan.FromSeconds(seconds);
                    break;
                default:
                    throw new ArgumentException($"Unknown argument: {arguments[index]}");
            }
        }

        return new PocOptions(
            diagnosticLog,
            simulateDiscoveryFailure,
            simulateNoSafeSlot,
            previewAboveTaskbar,
            exitAfter);
    }
}
