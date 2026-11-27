using System.Xml.Linq;

namespace BaboJUPulse.ArchitectureTests;

public sealed class ProjectConfigurationTests
{
    [Fact]
    public void AppProjectTargetsWindowsAndWpf()
    {
        var project = LoadXml("src/BaboJUPulse/BaboJUPulse.csproj");

        Assert.Equal("net10.0-windows10.0.19041.0", Value(project, "TargetFramework"));
        Assert.Equal("true", Value(project, "UseWPF"));
    }

    [Fact]
    public void AppShellHasNoStartupWindow()
    {
        var application = LoadXml("src/BaboJUPulse/App.xaml").Root;

        Assert.NotNull(application);
        Assert.Equal("OnExplicitShutdown", application.Attribute("ShutdownMode")?.Value);
        Assert.Null(application.Attribute("StartupUri"));
    }

    [Fact]
    public void BuildConfigurationEnforcesQualityGates()
    {
        var props = LoadXml("Directory.Build.props");

        Assert.Equal("enable", Value(props, "Nullable"));
        Assert.Equal("true", Value(props, "TreatWarningsAsErrors"));
        Assert.Equal("true", Value(props, "EnforceCodeStyleInBuild"));
        Assert.Equal("latest-recommended", Value(props, "AnalysisLevel"));
        Assert.Equal("true", Value(props, "EnableNETAnalyzers"));
        Assert.Equal("true", Value(props, "CodeAnalysisTreatWarningsAsErrors"));
        Assert.Equal("true", Value(props, "NuGetAudit"));
        Assert.Equal("all", Value(props, "NuGetAuditMode"));
        Assert.Equal("true", Value(props, "EnableWindowsTargeting"));
    }

    [Fact]
    public void AppManifestRequestsPerMonitorDpiAwareness()
    {
        var manifest = LoadXml("src/BaboJUPulse/app.manifest");
        var dpiAwareness = manifest.Descendants()
            .Single(element => element.Name.LocalName == "dpiAwareness");

        Assert.Contains("permonitorv2", dpiAwareness.Value, StringComparison.Ordinal);
    }

    private static XDocument LoadXml(string relativePath) =>
        XDocument.Load(Path.Combine(RepositoryPaths.Root, relativePath));

    private static string? Value(XDocument document, string elementName) =>
        document.Descendants().FirstOrDefault(element => element.Name.LocalName == elementName)?.Value;
}
