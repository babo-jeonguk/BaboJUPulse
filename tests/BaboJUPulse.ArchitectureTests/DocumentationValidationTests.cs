using System.Diagnostics;

namespace BaboJUPulse.ArchitectureTests;

[Trait("Category", "RepositoryPolicy")]
public sealed class DocumentationValidationTests
{
    [Fact]
    public void DocumentationPassesValidation()
    {
        var result = Run("scripts/check-documentation.sh");

        Assert.True(
            result.ExitCode == 0,
            "Documentation validation failed:" + Environment.NewLine + result.Output);
    }

    [Fact]
    public void DocumentationValidationRejectsRepresentativeInvalidDocuments()
    {
        var result = Run("scripts/test-check-documentation.sh");

        Assert.True(
            result.ExitCode == 0,
            "Documentation validation synthetic tests failed:" + Environment.NewLine + result.Output);
    }

    [Fact]
    public void ScratchDirectoryIsIgnored()
    {
        var lines = File.ReadAllLines(Path.Combine(RepositoryPaths.Root, ".gitignore"))
            .Select(line => line.Trim());

        Assert.Contains(".scratch/", lines);
    }

    private static (int ExitCode, string Output) Run(string script)
    {
        using var process = new Process
        {
            StartInfo = new ProcessStartInfo(BashExecutable())
            {
                WorkingDirectory = RepositoryPaths.Root,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
                UseShellExecute = false,
            },
        };

        process.StartInfo.ArgumentList.Add(script);
        process.Start();
        var output = process.StandardOutput.ReadToEnd();
        var error = process.StandardError.ReadToEnd();
        process.WaitForExit();

        return (process.ExitCode, output + error);
    }

    private static string BashExecutable()
    {
        if (!OperatingSystem.IsWindows())
        {
            return "bash";
        }

        var programRoots = new[]
        {
            Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
            Environment.GetFolderPath(Environment.SpecialFolder.ProgramFilesX86),
        };

        foreach (var root in programRoots)
        {
            if (string.IsNullOrEmpty(root))
            {
                continue;
            }

            var candidate = Path.Combine(root, "Git", "bin", "bash.exe");
            if (File.Exists(candidate))
            {
                return candidate;
            }
        }

        return "bash";
    }
}
