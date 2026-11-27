using Microsoft.CodeAnalysis;
using Microsoft.CodeAnalysis.CSharp;
using Microsoft.CodeAnalysis.CSharp.Syntax;

namespace BaboJUPulse.ArchitectureTests;

[Trait("Category", "RepositoryPolicy")]
public sealed class SourcePolicyTests
{
    [Fact]
    public void SourceFilesContainNoUnapprovedSuppressions()
    {
        var failures = SourceFileScanner.FindSuppressions();
        Assert.True(
            failures.Count == 0,
            "Unapproved source suppressions:" + Environment.NewLine + string.Join(Environment.NewLine, failures));
    }

    [Fact]
    public void NullForcingOperatorsHaveJustification()
    {
        var failures = SourceFileScanner.FindUnjustifiedNullForcing();
        Assert.True(
            failures.Count == 0,
            "Unjustified null-forgiving operators:" + Environment.NewLine + string.Join(Environment.NewLine, failures));
    }

    [Fact]
    public void TrackedSourceDoesNotUseGeneratedSuffixes()
    {
        var failures = SourceFileScanner.FindGeneratedSourceFiles();
        Assert.True(
            failures.Count == 0,
            "Tracked source uses generated-file suffixes:" + Environment.NewLine + string.Join(Environment.NewLine, failures));
    }

    [Fact]
    public void SourceFilesDoNotClaimGeneratedCode()
    {
        var failures = SourceFileScanner.FindGeneratedCodeMarkers();
        Assert.True(
            failures.Count == 0,
            "Handwritten source claims to be generated:" + Environment.NewLine + string.Join(Environment.NewLine, failures));
    }
}

internal static class SourceFileScanner
{
    private static readonly string[] GeneratedSuffixes =
    [
        ".g.cs",
        ".g.i.cs",
        ".designer.cs",
        ".generated.cs",
    ];

    public static IReadOnlyList<string> FindSuppressions()
    {
        var failures = new List<string>();
        foreach (var file in SourceFiles())
        {
            var tree = Parse(file);
            AddDirectiveSuppressions(file, tree, failures);
            AddAttributeSuppressions(file, tree, failures);
        }

        return failures;
    }

    public static IReadOnlyList<string> FindUnjustifiedNullForcing()
    {
        var failures = new List<string>();
        foreach (var file in SourceFiles())
        {
            AddNullForcing(file, Parse(file), failures);
        }

        return failures;
    }

    public static IReadOnlyList<string> FindGeneratedSourceFiles() =>
        TrackedFiles.All()
            .Where(path => GeneratedSuffixes.Any(suffix => path.EndsWith(suffix, StringComparison.Ordinal)))
            .Select(path => $"{path}: generated-file suffix is not allowed in tracked source")
            .ToList();

    public static IReadOnlyList<string> FindGeneratedCodeMarkers()
    {
        var failures = new List<string>();
        foreach (var file in SourceFiles())
        {
            foreach (var attribute in Parse(file).GetCompilationUnitRoot().DescendantNodes().OfType<AttributeSyntax>())
            {
                var name = attribute.Name.ToString().Split('.').Last();
                if (name is "GeneratedCode" or "GeneratedCodeAttribute")
                {
                    failures.Add($"{file}:{Line(attribute)}: [{name}]");
                }
            }
        }

        return failures;
    }

    private static void AddDirectiveSuppressions(string file, SyntaxTree tree, List<string> failures)
    {
        foreach (var trivia in tree.GetCompilationUnitRoot().DescendantTrivia(descendIntoTrivia: true))
        {
            switch (trivia.GetStructure())
            {
                case PragmaWarningDirectiveTriviaSyntax pragma
                    when pragma.DisableOrRestoreKeyword.IsKind(SyntaxKind.DisableKeyword):
                    failures.Add($"{file}:{Line(trivia)}: #pragma warning disable");
                    break;
                case NullableDirectiveTriviaSyntax nullable
                    when nullable.SettingToken.IsKind(SyntaxKind.DisableKeyword):
                    failures.Add($"{file}:{Line(trivia)}: #nullable disable");
                    break;
            }
        }
    }

    private static void AddAttributeSuppressions(string file, SyntaxTree tree, List<string> failures)
    {
        foreach (var attribute in tree.GetCompilationUnitRoot().DescendantNodes().OfType<AttributeSyntax>())
        {
            var name = attribute.Name.ToString().Split('.').Last();
            if (name is "SuppressMessage"
                or "SuppressMessageAttribute"
                or "UnconditionalSuppressMessage"
                or "UnconditionalSuppressMessageAttribute")
            {
                failures.Add($"{file}:{Line(attribute)}: [{name}]");
            }
        }
    }

    private static void AddNullForcing(string file, SyntaxTree tree, List<string> failures)
    {
        var text = tree.GetText();
        foreach (var expression in tree.GetCompilationUnitRoot()
                     .DescendantNodes()
                     .OfType<PostfixUnaryExpressionSyntax>()
                     .Where(node => node.IsKind(SyntaxKind.SuppressNullableWarningExpression)))
        {
            var line = expression.GetLocation().GetLineSpan().StartLinePosition.Line;
            var currentLine = text.Lines[line].ToString();
            var previousLine = line > 0 ? text.Lines[line - 1].ToString() : string.Empty;

            if (!currentLine.Contains("// null-forgiving:", StringComparison.Ordinal)
                && !previousLine.Contains("// null-forgiving:", StringComparison.Ordinal))
            {
                failures.Add(
                    $"{file}:{line + 1}: null-forgiving operator needs a '// null-forgiving: <reason>' comment");
            }
        }
    }

    private static IEnumerable<string> SourceFiles() =>
        TrackedFiles.All()
            .Where(path => path.EndsWith(".cs", StringComparison.Ordinal))
            .Where(path => !GeneratedSuffixes.Any(suffix => path.EndsWith(suffix, StringComparison.Ordinal)))
            .Where(path => !path.Contains("/obj/", StringComparison.Ordinal)
                && !path.Contains("/bin/", StringComparison.Ordinal));

    private static SyntaxTree Parse(string relativePath) =>
        CSharpSyntaxTree.ParseText(
            TrackedFiles.ReadText(relativePath),
            new CSharpParseOptions(LanguageVersion.Latest),
            relativePath);

    private static int Line(SyntaxTrivia trivia) =>
        trivia.GetLocation().GetLineSpan().StartLinePosition.Line + 1;

    private static int Line(SyntaxNode node) =>
        node.GetLocation().GetLineSpan().StartLinePosition.Line + 1;
}
