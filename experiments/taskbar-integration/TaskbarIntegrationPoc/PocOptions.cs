using System.Globalization;

namespace BaboJUPulse.TaskbarIntegrationPoc;

internal sealed record PocOptions(bool SimulateAttachFailure, bool DiagnosticLog, TimeSpan? ExitAfter)
{
    public static PocOptions Parse(IReadOnlyList<string> arguments)
    {
        var simulateAttachFailure = false;
        var diagnosticLog = false;
        TimeSpan? exitAfter = null;

        for (var index = 0; index < arguments.Count; index++)
        {
            switch (arguments[index])
            {
                case "--simulate-attach-failure":
                    simulateAttachFailure = true;
                    break;
                case "--diagnostic-log":
                    diagnosticLog = true;
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

        return new PocOptions(simulateAttachFailure, diagnosticLog, exitAfter);
    }
}
