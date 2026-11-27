using System.Globalization;
using System.Text.RegularExpressions;

namespace BaboJUPulse.ArchitectureTests;

[Trait("Category", "RepositoryPolicy")]
public sealed class AnalyzerPolicyTests
{
    [Fact]
    public void BannedSymbolsRemainActive()
    {
        var activeLines = ActiveLines("BannedSymbols.txt").ToList();
        var active = activeLines
            .Select(line => line.Split(';', 2)[0].Trim())
            .ToHashSet(StringComparer.Ordinal);

        // Adding a banned symbol is a deliberate gate change: add it here too so
        // the repository-policy test protects every active entry.
        string[] required =
        [
            "M:System.Threading.Thread.Sleep(System.Int32)",
            "M:System.Threading.Thread.Sleep(System.TimeSpan)",
            "M:System.Threading.Tasks.Task.Wait",
            "M:System.Threading.Tasks.Task.Wait(System.Int32)",
            "M:System.Threading.Tasks.Task.Wait(System.TimeSpan)",
            "M:System.Threading.Tasks.Task.Wait(System.Threading.CancellationToken)",
            "M:System.Threading.Tasks.Task.WaitAll(System.Threading.Tasks.Task[])",
            "M:System.Threading.Tasks.Task.WaitAny(System.Threading.Tasks.Task[])",
            "P:System.Threading.Tasks.Task`1.Result",
            "M:System.Runtime.CompilerServices.TaskAwaiter.GetResult",
            "M:System.Runtime.CompilerServices.TaskAwaiter`1.GetResult",
            "M:System.Windows.Threading.Dispatcher.Invoke(System.Action)",
            "M:System.Windows.Threading.Dispatcher.Invoke``1(System.Func{``0})",
            "P:System.Net.ServicePointManager.ServerCertificateValidationCallback",
            "P:System.Net.Http.HttpClientHandler.ServerCertificateCustomValidationCallback",
            "M:System.Diagnostics.Process.Start(System.String)",
            "M:System.Diagnostics.Process.Start(System.String,System.String)",
        ];

        var missing = required.Where(symbol => !active.Contains(symbol)).ToList();
        Assert.True(
            missing.Count == 0,
            "Banned symbols are missing or commented out:" + Environment.NewLine + string.Join(Environment.NewLine, missing));

        var requiredSet = required.ToHashSet(StringComparer.Ordinal);
        var unexpected = active.Where(symbol => !requiredSet.Contains(symbol)).ToList();
        Assert.True(
            unexpected.Count == 0,
            "New banned symbols must also be added to the required list:"
                + Environment.NewLine
                + string.Join(Environment.NewLine, unexpected));

        var undocumented = activeLines
            .Where(line =>
            {
                var parts = line.Split(';', 2);
                return parts.Length < 2 || parts[1].Trim().Length == 0;
            })
            .ToList();
        Assert.True(
            undocumented.Count == 0,
            "Banned symbols need a replacement reason after ';':" + Environment.NewLine + string.Join(Environment.NewLine, undocumented));
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
