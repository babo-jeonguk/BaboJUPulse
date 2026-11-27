using System.Xml.Linq;

namespace BaboJUPulse.ArchitectureTests;

[Trait("Category", "RepositoryPolicy")]
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
    public void SelectedAnalyzerRulesAreErrors()
    {
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

        var seen = new HashSet<string>(StringComparer.Ordinal);
        var failures = new List<string>();

        foreach (var file in new[] { ".editorconfig", ".globalconfig" })
        {
            foreach (var line in File.ReadAllLines(Path.Combine(RepositoryPaths.Root, file)))
            {
                var parts = line.Trim().Split('=', 2);
                if (parts.Length != 2 || !parts[0].StartsWith("dotnet_diagnostic.", StringComparison.Ordinal))
                {
                    continue;
                }

                var key = parts[0].Trim();
                var rule = key["dotnet_diagnostic.".Length..].Replace(".severity", string.Empty, StringComparison.Ordinal);
                if (!rules.Contains(rule, StringComparer.Ordinal))
                {
                    continue;
                }

                seen.Add(rule);
                var severity = parts[1].Trim();
                if (!string.Equals(severity, "error", StringComparison.Ordinal))
                {
                    failures.Add($"{file}: {rule} is {severity}, not error");
                }
            }
        }

        foreach (var rule in rules.Where(rule => !seen.Contains(rule)))
        {
            failures.Add($"Missing analyzer severity for {rule}");
        }

        Assert.True(
            failures.Count == 0,
            "Analyzer rule severities were weakened:" + Environment.NewLine + string.Join(Environment.NewLine, failures));
    }

}
