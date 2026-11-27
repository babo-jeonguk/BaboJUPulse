namespace BaboJUPulse.ArchitectureTests;

public sealed class CiWorkflowTests
{
    [Fact]
    public void CiWorkflowRunsRequiredGatesOnWindows()
    {
        var workflow = File.ReadAllText(
            Path.Combine(RepositoryPaths.Root, ".github", "workflows", "ci.yml"));

        Assert.Contains("runs-on: windows-latest", workflow, StringComparison.Ordinal);
        Assert.Contains("contents: read", workflow, StringComparison.Ordinal);
        Assert.Contains("dotnet restore BaboJUPulse.slnx", workflow, StringComparison.Ordinal);
        Assert.Contains("dotnet format BaboJUPulse.slnx --verify-no-changes", workflow, StringComparison.Ordinal);
        Assert.Contains(
            "dotnet build BaboJUPulse.slnx -c Release --no-restore -warnaserror",
            workflow,
            StringComparison.Ordinal);
        Assert.Contains("dotnet test BaboJUPulse.slnx -c Release --no-build", workflow, StringComparison.Ordinal);
    }

    [Fact]
    public void SecurityWorkflowsExist()
    {
        string[] workflows = ["codeql.yml", "dependency-review.yml"];
        foreach (var workflow in workflows)
        {
            Assert.True(
                File.Exists(Path.Combine(RepositoryPaths.Root, ".github", "workflows", workflow)),
                $"Missing .github/workflows/{workflow}");
        }
    }
}
