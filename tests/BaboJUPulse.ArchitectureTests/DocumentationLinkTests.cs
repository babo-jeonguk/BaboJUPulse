using System.Diagnostics;
using System.Text.RegularExpressions;

namespace BaboJUPulse.ArchitectureTests;

[Trait("Category", "RepositoryPolicy")]
public sealed partial class DocumentationLinkTests
{
    private static readonly string[] IgnoredDirectories =
    [
        ".git",
        ".scratch",
        "bin",
        "obj",
        "TestResults",
    ];

    [Fact]
    public void RelativeMarkdownLinksResolve()
    {
        var brokenLinks = new List<string>();

        foreach (var document in MarkdownFiles())
        {
            var content = StripFencedCodeBlocks(File.ReadAllText(document));
            foreach (Match match in LinkPattern().Matches(content))
            {
                var target = match.Groups["target"].Value.Trim().Trim('<', '>');
                if (IsExternalOrAnchor(target))
                {
                    continue;
                }

                var path = target.Split('#', 2)[0].Split('?', 2)[0];
                if (string.IsNullOrEmpty(path))
                {
                    continue;
                }

                var documentDirectory = Path.GetDirectoryName(document)
                    ?? throw new InvalidOperationException($"Document has no directory: {document}");
                var resolved = Path.GetFullPath(
                    Path.Combine(documentDirectory, Uri.UnescapeDataString(path)));

                if (!File.Exists(resolved) && !Directory.Exists(resolved))
                {
                    brokenLinks.Add(
                        $"{Path.GetRelativePath(RepositoryPaths.Root, document)} -> {target}");
                }
            }
        }

        Assert.True(
            brokenLinks.Count == 0,
            "Broken relative Markdown links:" + Environment.NewLine + string.Join(Environment.NewLine, brokenLinks));
    }

    [Fact]
    public void RelativeMarkdownLinksDoNotTargetIgnoredPaths()
    {
        var failures = new List<string>();

        foreach (var document in MarkdownFiles())
        {
            var content = StripFencedCodeBlocks(File.ReadAllText(document));
            foreach (Match match in LinkPattern().Matches(content))
            {
                var target = match.Groups["target"].Value.Trim().Trim('<', '>');
                if (IsExternalOrAnchor(target))
                {
                    continue;
                }

                var path = target.Split('#', 2)[0].Split('?', 2)[0];
                if (string.IsNullOrEmpty(path))
                {
                    continue;
                }

                var documentDirectory = Path.GetDirectoryName(document)
                    ?? throw new InvalidOperationException($"Document has no directory: {document}");
                var resolved = Path.GetFullPath(
                    Path.Combine(documentDirectory, Uri.UnescapeDataString(path)));

                if (!File.Exists(resolved) && !Directory.Exists(resolved))
                {
                    continue;
                }

                var relative = Path.GetRelativePath(RepositoryPaths.Root, resolved).Replace('\\', '/');
                if (relative.StartsWith("..", StringComparison.Ordinal))
                {
                    failures.Add($"{Path.GetRelativePath(RepositoryPaths.Root, document)} -> {target} (outside repository)");
                }
                else if (IsGitIgnored(relative))
                {
                    failures.Add($"{Path.GetRelativePath(RepositoryPaths.Root, document)} -> {target} (Git-ignored)");
                }
            }
        }

        Assert.True(
            failures.Count == 0,
            "Markdown links target local-only paths:" + Environment.NewLine + string.Join(Environment.NewLine, failures));
    }

    [Fact]
    public void MarkdownLinksDoNotUseLocalAbsolutePaths()
    {
        var failures = new List<string>();

        foreach (var document in MarkdownFiles())
        {
            var content = StripFencedCodeBlocks(File.ReadAllText(document));
            foreach (Match match in LinkPattern().Matches(content))
            {
                var target = match.Groups["target"].Value.Trim().Trim('<', '>');
                if (IsLocalAbsoluteReference(target))
                {
                    failures.Add($"{Path.GetRelativePath(RepositoryPaths.Root, document)} -> {target}");
                }
            }
        }

        Assert.True(
            failures.Count == 0,
            "Markdown links use local absolute paths:" + Environment.NewLine + string.Join(Environment.NewLine, failures));
    }

    [Fact]
    public void ScratchDirectoryIsIgnored()
    {
        var lines = File.ReadAllLines(Path.Combine(RepositoryPaths.Root, ".gitignore"))
            .Select(line => line.Trim());

        Assert.Contains(".scratch/", lines);
    }

    private static IEnumerable<string> MarkdownFiles() =>
        Directory.EnumerateFiles(RepositoryPaths.Root, "*.md", SearchOption.AllDirectories)
            .Where(path => !IgnoredDirectories.Any(directory =>
                path.Contains(
                    $"{Path.DirectorySeparatorChar}{directory}{Path.DirectorySeparatorChar}",
                    StringComparison.Ordinal)));

    private static bool IsExternalOrAnchor(string target) =>
        target.StartsWith('#')
        || target.StartsWith("http://", StringComparison.OrdinalIgnoreCase)
        || target.StartsWith("https://", StringComparison.OrdinalIgnoreCase)
        || target.StartsWith("mailto:", StringComparison.OrdinalIgnoreCase);

    private static bool IsLocalAbsoluteReference(string target) =>
        target.StartsWith("/home/", StringComparison.Ordinal)
        || target.StartsWith("/Users/", StringComparison.Ordinal)
        || target.StartsWith("C:\\", StringComparison.OrdinalIgnoreCase)
        || target.StartsWith("file" + "://", StringComparison.OrdinalIgnoreCase);

    private static bool IsGitIgnored(string relativePath)
    {
        using var process = new Process
        {
            StartInfo = new ProcessStartInfo("git")
            {
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
            },
        };

        process.StartInfo.ArgumentList.Add("-C");
        process.StartInfo.ArgumentList.Add(RepositoryPaths.Root);
        process.StartInfo.ArgumentList.Add("check-ignore");
        process.StartInfo.ArgumentList.Add("--quiet");
        process.StartInfo.ArgumentList.Add("--no-index");
        process.StartInfo.ArgumentList.Add("--");
        process.StartInfo.ArgumentList.Add(relativePath);

        process.Start();
        process.WaitForExit();
        return process.ExitCode == 0;
    }

    private static string StripFencedCodeBlocks(string content) =>
        FencedCodeBlockPattern().Replace(content, string.Empty);

    [GeneratedRegex(@"\[[^\]]*\]\((?<target>[^)\s]+)(?:\s+""[^""]*"")?\)")]
    private static partial Regex LinkPattern();

    [GeneratedRegex("```.*?```", RegexOptions.Singleline)]
    private static partial Regex FencedCodeBlockPattern();
}
