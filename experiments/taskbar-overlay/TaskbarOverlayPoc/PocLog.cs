using System.IO;

namespace BaboJUPulse.TaskbarOverlayPoc;

internal sealed class PocLog : IDisposable
{
    private readonly StreamWriter? _writer;
    private bool _isDisposed;

    public PocLog(bool isEnabled)
    {
        if (!isEnabled)
        {
            return;
        }

        try
        {
            var path = Path.Combine(Path.GetTempPath(), "BaboJUPulse.TaskbarOverlayPoc.log");
            _writer = new StreamWriter(path, append: true)
            {
                AutoFlush = true,
            };
        }
        catch (IOException)
        {
            _writer = null;
        }
        catch (UnauthorizedAccessException)
        {
            _writer = null;
        }
    }

    public void Write(string message)
    {
        if (_writer is null)
        {
            return;
        }

        try
        {
            _writer.WriteLine(
                FormattableString.Invariant($"{DateTimeOffset.Now:O} {message}"));
        }
        catch (IOException)
        {
            _writer.Dispose();
        }
        catch (ObjectDisposedException)
        {
            // The log was already closed by a failed write or shutdown.
        }
    }

    public void Dispose()
    {
        if (_isDisposed)
        {
            return;
        }

        _isDisposed = true;
        _writer?.Dispose();
        GC.SuppressFinalize(this);
    }
}
