using System.Diagnostics;

namespace BaboJUPulse.ArchitectureTests;

internal static class TrackedFiles
{
    public static IReadOnlyList<string> All()
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
        process.StartInfo.ArgumentList.Add("ls-files");
        process.StartInfo.ArgumentList.Add("-z");

        process.Start();
        var output = process.StandardOutput.ReadToEnd();
        var error = process.StandardError.ReadToEnd();
        process.WaitForExit();

        if (process.ExitCode != 0)
        {
            throw new InvalidOperationException($"git ls-files failed: {error}");
        }

        return output.Split('\0', StringSplitOptions.RemoveEmptyEntries);
    }

    public static string ReadText(string relativePath) =>
        File.ReadAllText(Path.Combine(RepositoryPaths.Root, relativePath));
}
