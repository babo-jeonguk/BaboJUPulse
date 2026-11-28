using System.Globalization;
using System.IO;

namespace BaboJUPulse.TaskbarIntegrationPoc;

internal static class PocDiagnostics
{
    private static readonly object Sync = new();

    public static bool IsEnabled { get; set; }

    public static void Write(string message)
    {
        if (!IsEnabled)
        {
            return;
        }

        try
        {
            var line = string.Concat(
                DateTimeOffset.UtcNow.ToString("O", CultureInfo.InvariantCulture),
                " ",
                message,
                Environment.NewLine);

            lock (Sync)
            {
                File.AppendAllText(
                    Path.Combine(Path.GetTempPath(), "BaboJUPulse.TaskbarIntegrationPoc.log"),
                    line);
            }
        }
        catch (IOException)
        {
        }
        catch (UnauthorizedAccessException)
        {
        }
    }
}
