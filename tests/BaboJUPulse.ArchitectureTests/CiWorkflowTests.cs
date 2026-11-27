using YamlDotNet.RepresentationModel;

namespace BaboJUPulse.ArchitectureTests;

[Trait("Category", "RepositoryPolicy")]
public sealed class CiWorkflowTests
{
    [Fact]
    public void CiWorkflowRunsMandatoryGatesUnconditionally()
    {
        var root = LoadWorkflow();
        var jobs = RequireMapping(root, "jobs");
        var build = RequireMapping(jobs, "build");

        Assert.Equal("build", StringValue(build, "name"));
        Assert.Null(Child(build, "if"));
        Assert.Null(Child(build, "continue-on-error"));
        var permissions = RequireMapping(root, "permissions");
        Assert.Equal("read", StringValue(permissions, "contents"));
        AssertReadOnlyPermissions(permissions, "workflow");

        if (Child(build, "permissions") is YamlMappingNode jobPermissions)
        {
            AssertReadOnlyPermissions(jobPermissions, "build job");
        }

        Assert.True(HasPullRequestTrigger(root), "CI must run on pull requests");

        var steps = RequireSequence(build, "steps");
        var runs = new List<string>();

        foreach (var node in steps.Children)
        {
            var step = (YamlMappingNode)node;
            var name = StringValue(step, "name") ?? "<unnamed>";
            var run = StringValue(step, "run");

            if (run is not null)
            {
                Assert.True(Child(step, "if") is null, $"Mandatory step is conditional: {name}");
                var continueOnError = StringValue(step, "continue-on-error");
                Assert.True(
                    continueOnError is null || string.Equals(continueOnError, "false", StringComparison.OrdinalIgnoreCase),
                    $"Mandatory step allows failure: {name}");

                foreach (var forbidden in new[] { "|| true", "|| exit 0", "set +e", "exit 0" })
                {
                    Assert.False(
                        run.Contains(forbidden, StringComparison.Ordinal),
                        $"Mandatory step contains '{forbidden}': {name}");
                }

                runs.Add(run);
            }
        }

        Assert.True(
            HasRun(runs, "dotnet restore BaboJUPulse.slnx"),
            "Missing mandatory restore command");
        Assert.True(
            HasRun(runs, "dotnet format BaboJUPulse.slnx --verify-no-changes"),
            "Missing mandatory format command");
        Assert.True(
            HasRun(runs, "dotnet build BaboJUPulse.slnx -c Release --no-restore -warnaserror"),
            "Missing mandatory warnings-as-errors build");
        Assert.True(
            HasRun(runs, "dotnet test BaboJUPulse.slnx -c Release --no-build"),
            "Missing mandatory test command");
        Assert.True(
            HasRun(
                runs,
                "dotnet test tests/BaboJUPulse.ArchitectureTests/BaboJUPulse.ArchitectureTests.csproj -c Release --no-build --filter \"Category=RepositoryPolicy\""),
            "Missing mandatory repository-policy test command");
        Assert.True(
            runs.Any(run => run.Contains("bash scripts/check-public-content.sh", StringComparison.Ordinal)),
            "Missing public-content check");
        Assert.True(
            runs.Any(run => run.Contains("bash scripts/test-public-content.sh", StringComparison.Ordinal)),
            "Missing public-content checker tests");
        Assert.True(
            runs.Any(run => run.Contains("RunConfiguration.TreatNoTestsAsError=true", StringComparison.Ordinal)),
            "No-test runs must not pass silently");

        var publicContentStep = steps.Children
            .Select(node => (YamlMappingNode)node)
            .Single(step => StringValue(step, "name") == "Check public content");
        var publicContentRun = StringValue(publicContentStep, "run");
        Assert.NotNull(publicContentRun);
        Assert.Contains(
            "bash scripts/check-public-content.sh --tracked",
            publicContentRun,
            StringComparison.Ordinal);
        Assert.Contains(
            "bash scripts/test-public-content.sh",
            publicContentRun,
            StringComparison.Ordinal);
        Assert.Contains(
            "printf '%s\\n\\n%s\\n' \"$PR_TITLE\" \"$PR_BODY\" | bash scripts/check-public-content.sh",
            publicContentRun,
            StringComparison.Ordinal);
        Assert.Contains(
            "git log --format=%B \"$BASE_SHA..$HEAD_SHA\" | bash scripts/check-public-content.sh",
            publicContentRun,
            StringComparison.Ordinal);
        var publicContentEnvironment = RequireMapping(publicContentStep, "env");
        Assert.Equal(
            "${{ github.event.pull_request.title }}",
            StringValue(publicContentEnvironment, "PR_TITLE"));
        Assert.Equal(
            "${{ github.event.pull_request.body }}",
            StringValue(publicContentEnvironment, "PR_BODY"));

        var checkout = steps.Children
            .Select(node => (YamlMappingNode)node)
            .Single(step => StringValue(step, "uses")?.StartsWith("actions/checkout@", StringComparison.Ordinal) == true);
        Assert.Equal("0", StringValue(RequireMapping(checkout, "with"), "fetch-depth"));
    }

    [Fact]
    public void PublicContentChecksRerunWhenPullRequestTextChanges()
    {
        var root = LoadWorkflow();
        var trigger = Child(root, "on") ?? Child(root, "true");
        var triggerMapping = Assert.IsType<YamlMappingNode>(trigger);
        Assert.Null(Child(triggerMapping, "pull_request_target"));
        var pullRequest = Assert.IsType<YamlMappingNode>(Child(triggerMapping, "pull_request"));
        var types = Assert.IsType<YamlSequenceNode>(Child(pullRequest, "types"));
        var configured = types.Children
            .OfType<YamlScalarNode>()
            .Select(node => node.Value)
            .ToHashSet(StringComparer.Ordinal);

        foreach (var required in new[] { "opened", "synchronize", "reopened", "edited" })
        {
            Assert.True(
                configured.Contains(required),
                $"Public-content validation must run when a pull request is '{required}'");
        }
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

    private static string WorkflowPath() =>
        Path.Combine(RepositoryPaths.Root, ".github", "workflows", "ci.yml");

    private static YamlMappingNode LoadWorkflow()
    {
        using var reader = File.OpenText(WorkflowPath());
        var stream = new YamlStream();
        stream.Load(reader);
        return (YamlMappingNode)stream.Documents[0].RootNode;
    }

    private static bool HasPullRequestTrigger(YamlMappingNode root)
    {
        var trigger = Child(root, "on") ?? Child(root, "true");
        return trigger switch
        {
            YamlMappingNode mapping => Child(mapping, "pull_request") is not null,
            YamlScalarNode scalar => scalar.Value?.Contains("pull_request", StringComparison.Ordinal) == true,
            _ => false,
        };
    }

    private static void AssertReadOnlyPermissions(YamlMappingNode permissions, string scope)
    {
        foreach (var permission in permissions.Children)
        {
            var name = ((YamlScalarNode)permission.Key).Value ?? "<unnamed>";
            var value = (permission.Value as YamlScalarNode)?.Value;
            Assert.False(
                value?.Contains("write", StringComparison.OrdinalIgnoreCase) == true,
                $"{scope} permission '{name}' must remain read-only");
        }
    }

    private static bool HasRun(IEnumerable<string> runs, string prefix) =>
        runs.Any(run => run.TrimStart().StartsWith(prefix, StringComparison.Ordinal));

    private static YamlNode? Child(YamlMappingNode node, string key) =>
        node.Children
            .FirstOrDefault(pair => pair.Key is YamlScalarNode scalar && scalar.Value == key)
            .Value;

    private static YamlMappingNode RequireMapping(YamlMappingNode node, string key) =>
        Child(node, key) as YamlMappingNode
        ?? throw new InvalidOperationException($"Missing mapping key: {key}");

    private static YamlSequenceNode RequireSequence(YamlMappingNode node, string key) =>
        Child(node, key) as YamlSequenceNode
        ?? throw new InvalidOperationException($"Missing sequence key: {key}");

    private static string? StringValue(YamlMappingNode node, string key) =>
        (Child(node, key) as YamlScalarNode)?.Value;
}
