using System.Xml.Linq;

namespace BaboJUPulse.ArchitectureTests;

public sealed class StaticAnalysisConfigurationTests
{
    [Fact]
    public void BannedApiAnalyzerIsConfigured()
    {
        var props = XDocument.Load(Path.Combine(RepositoryPaths.Root, "Directory.Build.props"));

        var package = props.Descendants()
            .SingleOrDefault(element =>
                element.Name.LocalName == "PackageReference"
                && string.Equals(
                    element.Attribute("Include")?.Value,
                    "Microsoft.CodeAnalysis.BannedApiAnalyzers",
                    StringComparison.Ordinal));

        Assert.NotNull(package);
        Assert.Equal("all", package.Elements().Single(e => e.Name.LocalName == "PrivateAssets").Value);
        Assert.Contains(
            props.Descendants(),
            element => element.Name.LocalName == "AdditionalFiles"
                && element.Attribute("Include")?.Value.EndsWith("BannedSymbols.txt", StringComparison.Ordinal) == true);
        Assert.Contains(
            props.Descendants(),
            element => element.Name.LocalName == "AdditionalFiles"
                && element.Attribute("Include")?.Value.EndsWith("CodeMetricsConfig.txt", StringComparison.Ordinal) == true);
    }

    [Fact]
    public void BannedSymbolsCoverBlockingAndUnsafeApis()
    {
        var bannedSymbols = File.ReadAllText(Path.Combine(RepositoryPaths.Root, "BannedSymbols.txt"));

        Assert.Contains("Thread.Sleep", bannedSymbols, StringComparison.Ordinal);
        Assert.Contains("Task.Wait", bannedSymbols, StringComparison.Ordinal);
        Assert.Contains("Task`1.Result", bannedSymbols, StringComparison.Ordinal);
        Assert.Contains("Dispatcher.Invoke", bannedSymbols, StringComparison.Ordinal);
        Assert.Contains("ServerCertificateValidationCallback", bannedSymbols, StringComparison.Ordinal);
        Assert.Contains("Process.Start", bannedSymbols, StringComparison.Ordinal);
    }

    [Fact]
    public void SelectedAnalyzerRulesAreErrors()
    {
        var severities = new Dictionary<string, string>(StringComparer.Ordinal);
        foreach (var line in File.ReadAllLines(Path.Combine(RepositoryPaths.Root, ".editorconfig")))
        {
            var parts = line.Trim().Split('=', 2);
            if (parts.Length != 2 || !parts[0].StartsWith("dotnet_diagnostic.", StringComparison.Ordinal))
            {
                continue;
            }

            var key = parts[0].Trim();
            var rule = key["dotnet_diagnostic.".Length..].Replace(".severity", string.Empty, StringComparison.Ordinal);
            severities[rule] = parts[1].Trim();
        }

        string[] rules =
        [
            "CA1001",
            "CA1002",
            "CA1031",
            "CA1063",
            "CA1305",
            "CA1310",
            "CA1502",
            "CA1506",
            "CA1816",
            "CA1819",
            "CA1849",
            "CA2000",
            "CA2012",
            "CA2016",
            "CA2201",
            "CA2213",
        ];

        foreach (var rule in rules)
        {
            Assert.True(
                severities.TryGetValue(rule, out var severity),
                $"Missing analyzer severity for {rule}");
            Assert.Equal("error", severity);
        }
    }

    [Fact]
    public void CouplingThresholdsAreConfigured()
    {
        var config = File.ReadAllText(Path.Combine(RepositoryPaths.Root, "CodeMetricsConfig.txt"));

        Assert.Contains("CA1506(Type): 40", config, StringComparison.Ordinal);
        Assert.Contains("CA1506(Method): 20", config, StringComparison.Ordinal);
    }
}
