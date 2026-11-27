using System.Text.RegularExpressions;

namespace BaboJUPulse.ArchitectureTests;

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

                var resolved = Path.GetFullPath(
                    Path.Combine(Path.GetDirectoryName(document)!, Uri.UnescapeDataString(path)));

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

    private static string StripFencedCodeBlocks(string content) =>
        FencedCodeBlockPattern().Replace(content, string.Empty);

    [GeneratedRegex(@"\[[^\]]*\]\((?<target>[^)\s]+)(?:\s+""[^""]*"")?\)")]
    private static partial Regex LinkPattern();

    [GeneratedRegex("```.*?```", RegexOptions.Singleline)]
    private static partial Regex FencedCodeBlockPattern();
}
