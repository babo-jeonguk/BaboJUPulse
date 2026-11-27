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
    }

    [Fact]
    public void SelectedAnalyzerRulesAreErrors()
    {
        var lines = File.ReadAllLines(Path.Combine(RepositoryPaths.Root, ".editorconfig"))
            .Select(line => line.Trim());

        string[] rules = ["CA1001", "CA1502", "CA1506", "CA1849", "CA2016", "CA2201", "CA2213"];
        foreach (var rule in rules)
        {
            Assert.Contains(lines, line => line == $"dotnet_diagnostic.{rule}.severity = error");
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
