using System.Xml.Linq;

namespace BaboJUPulse.ArchitectureTests;

[Trait("Category", "RepositoryPolicy")]
public sealed class ProjectPolicyTests
{
    [Fact]
    public void ProjectFilesDoNotDisableAnalyzers()
    {
        var failures = new List<string>();
        string[] propertyNames =
        [
            "NoWarn",
            "WarningsNotAsErrors",
            "TreatWarningsAsErrors",
            "EnableNETAnalyzers",
            "RunAnalyzers",
            "RunAnalyzersDuringBuild",
            "RunAnalyzersDuringLiveAnalysis",
            "AnalysisLevel",
            "AnalysisMode",
            "CodeAnalysisTreatWarningsAsErrors",
            "Nullable",
            "EnableDefaultCompileItems",
            "DefaultItemExcludes",
        ];

        foreach (var file in TrackedFiles.All().Where(IsProjectFile))
        {
            var document = XDocument.Load(Path.Combine(RepositoryPaths.Root, file));
            foreach (var element in document.Descendants())
            {
                var name = element.Name.LocalName;
                if (propertyNames.Contains(name, StringComparer.Ordinal))
                {
                    CheckProperty(file, element, failures);
                }

                if (name == "Compile"
                    && (element.Attribute("Remove") is not null
                        || IsTrue(element.Attribute("AutoGen")?.Value)))
                {
                    failures.Add($"{file}: Compile item can remove handwritten source from analysis");
                }
            }
        }

        Assert.True(
            failures.Count == 0,
            "Project configuration weakens analysis:" + Environment.NewLine + string.Join(Environment.NewLine, failures));
    }

    [Fact]
    public void NoNestedAnalyzerConfiguration()
    {
        HashSet<string> allowed =
        [
            ".editorconfig",
            ".globalconfig",
            "Directory.Build.props",
        ];

        string[] names = [".editorconfig", ".globalconfig", "Directory.Build.props", "Directory.Build.targets"];
        var failures = TrackedFiles.All()
            .Where(path => names.Contains(Path.GetFileName(path), StringComparer.Ordinal))
            .Where(path => !allowed.Contains(path))
            .Select(path => $"{path}: nested analyzer configuration is not allowed")
            .ToList();

        Assert.True(
            failures.Count == 0,
            "Nested analyzer configuration:" + Environment.NewLine + string.Join(Environment.NewLine, failures));
    }

    private static bool IsProjectFile(string path) =>
        path.EndsWith(".csproj", StringComparison.Ordinal)
        || path.EndsWith(".props", StringComparison.Ordinal)
        || path.EndsWith(".targets", StringComparison.Ordinal);

    private static bool IsTrue(string? value) =>
        string.Equals(value, "true", StringComparison.OrdinalIgnoreCase);

    private static void CheckProperty(string file, XElement element, List<string> failures)
    {
        var name = element.Name.LocalName;
        var value = element.Value.Trim();

        switch (name)
        {
            case "NoWarn" or "WarningsNotAsErrors" when value.Length > 0:
                failures.Add($"{file}: {name} is not empty");
                break;
            case "TreatWarningsAsErrors" when !IsTrue(value):
                failures.Add($"{file}: TreatWarningsAsErrors is not true");
                break;
            case "EnableNETAnalyzers" when !IsTrue(value):
                failures.Add($"{file}: EnableNETAnalyzers is not true");
                break;
            case "RunAnalyzers" or "RunAnalyzersDuringBuild" or "RunAnalyzersDuringLiveAnalysis"
                when !IsTrue(value):
                failures.Add($"{file}: {name} is not true");
                break;
            case "AnalysisLevel" when !string.Equals(value, "latest-recommended", StringComparison.Ordinal):
                failures.Add($"{file}: AnalysisLevel is not latest-recommended");
                break;
            case "AnalysisMode" when string.Equals(value, "None", StringComparison.OrdinalIgnoreCase)
                || string.Equals(value, "Minimum", StringComparison.OrdinalIgnoreCase):
                failures.Add($"{file}: AnalysisMode is {value}");
                break;
            case "CodeAnalysisTreatWarningsAsErrors" when !IsTrue(value):
                failures.Add($"{file}: CodeAnalysisTreatWarningsAsErrors is not true");
                break;
            case "Nullable" when !string.Equals(value, "enable", StringComparison.Ordinal):
                failures.Add($"{file}: Nullable is not enable");
                break;
            case "EnableDefaultCompileItems" when !IsTrue(value):
                failures.Add($"{file}: EnableDefaultCompileItems is not true");
                break;
            case "DefaultItemExcludes" when value.Contains(".cs", StringComparison.Ordinal):
                failures.Add($"{file}: DefaultItemExcludes excludes C# source");
                break;
        }
    }
}
