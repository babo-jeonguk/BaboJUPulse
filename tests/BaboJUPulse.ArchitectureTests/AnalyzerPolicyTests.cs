using System.Globalization;
using System.Text.RegularExpressions;

namespace BaboJUPulse.ArchitectureTests;

[Trait("Category", "RepositoryPolicy")]
public sealed class AnalyzerPolicyTests
{
    [Fact]
    public void BannedSymbolsRemainActive()
    {
        var active = ActiveLines("BannedSymbols.txt")
            .Select(line => line.Split(';', 2)[0].Trim())
            .ToHashSet(StringComparer.Ordinal);

        string[] required =
        [
            "M:System.Threading.Thread.Sleep(System.Int32)",
            "M:System.Threading.Tasks.Task.Wait",
            "P:System.Threading.Tasks.Task`1.Result",
            "M:System.Windows.Threading.Dispatcher.Invoke(System.Action)",
            "P:System.Net.ServicePointManager.ServerCertificateValidationCallback",
            "M:System.Diagnostics.Process.Start(System.String)",
        ];

        var missing = required.Where(symbol => !active.Contains(symbol)).ToList();
        Assert.True(
            missing.Count == 0,
            "Banned symbols are missing or commented out:" + Environment.NewLine + string.Join(Environment.NewLine, missing));
    }

    [Fact]
    public void CouplingThresholdsRemainStrict()
    {
        var thresholds = new Dictionary<string, int>(StringComparer.Ordinal);
        foreach (var line in ActiveLines("CodeMetricsConfig.txt"))
        {
            var match = Regex.Match(line, @"^CA1506\((Type|Method)\):\s*(\d+)$", RegexOptions.CultureInvariant);
            if (match.Success)
            {
                thresholds[match.Groups[1].Value] = int.Parse(
                    match.Groups[2].Value,
                    NumberStyles.None,
                    CultureInfo.InvariantCulture);
            }
        }

        Assert.True(thresholds.TryGetValue("Type", out var typeThreshold), "Missing CA1506(Type) threshold");
        Assert.True(thresholds.TryGetValue("Method", out var methodThreshold), "Missing CA1506(Method) threshold");
        Assert.True(typeThreshold <= 40, $"CA1506(Type) must stay at or below 40, was {typeThreshold}");
        Assert.True(methodThreshold <= 20, $"CA1506(Method) must stay at or below 20, was {methodThreshold}");
    }

    private static IEnumerable<string> ActiveLines(string relativePath) =>
        File.ReadAllLines(Path.Combine(RepositoryPaths.Root, relativePath))
            .Select(line => line.Trim())
            .Where(line => line.Length > 0 && !line.StartsWith("//", StringComparison.Ordinal));
}
