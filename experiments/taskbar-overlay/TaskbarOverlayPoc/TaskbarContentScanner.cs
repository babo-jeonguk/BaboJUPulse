using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
using BaboJUPulse.TaskbarOverlayPoc.Core;

namespace BaboJUPulse.TaskbarOverlayPoc;

/// <summary>
/// Discovers the visible taskbar content that the independent overlay must not
/// cover. Windows 11 renders Start, search, app buttons, and the notification
/// area through XAML islands that were not exposed to UI Automation or as
/// ordinary taskbar child windows in the tested session. The scanner therefore
/// renders the taskbar with PrintWindow and treats columns with visible contrast
/// as occupied, then adds the known taskbar child rectangles as a safety net.
///
/// The captured bitmap is analyzed in memory only. It is never saved, logged,
/// or published, because it can contain notification icons and the clock.
/// </summary>
internal static class TaskbarContentScanner
{
    private const double ContentStdDevThreshold = 6.0;
    private const int ContentLuminanceRangeThreshold = 45;
    private const int ContentPaddingDip = 6;

    public static bool TryGetOccupied(
        TaskbarSnapshot taskbar,
        out IReadOnlyList<PixelRect> occupied)
    {
        occupied = Array.Empty<PixelRect>();

        if (taskbar.Bounds.IsEmpty)
        {
            return false;
        }

        var intervals = new List<(int Left, int Right)>();
        if (!TryReadContentIntervals(taskbar, intervals))
        {
            return false;
        }

        AddKnownControl(taskbar, "Start", intervals);
        AddKnownControl(taskbar, "ReBarWindow32", intervals);
        AddKnownControl(taskbar, "TrayNotifyWnd", intervals);

        if (intervals.Count == 0)
        {
            return false;
        }

        intervals.Sort(static (left, right) => left.Left.CompareTo(right.Left));
        var merged = Merge(intervals);
        var regions = new List<PixelRect>(merged.Count);

        foreach (var interval in merged)
        {
            var region = new PixelRect(
                interval.Left,
                taskbar.Bounds.Top,
                interval.Right,
                taskbar.Bounds.Bottom).Intersect(taskbar.Bounds);

            if (!region.IsEmpty)
            {
                regions.Add(region);
            }
        }

        occupied = regions;
        return regions.Count > 0;
    }

    private static bool TryReadContentIntervals(
        TaskbarSnapshot taskbar,
        List<(int Left, int Right)> intervals)
    {
        var width = taskbar.Bounds.Width;
        var height = taskbar.Bounds.Height;
        if (width <= 0 || height <= 0)
        {
            return false;
        }

        try
        {
            using var bitmap = new Bitmap(width, height, PixelFormat.Format32bppArgb);
            using var graphics = Graphics.FromImage(bitmap);
            var deviceContext = graphics.GetHdc();

            try
            {
                if (!NativeMethods.PrintWindow(
                        taskbar.Handle,
                        deviceContext,
                        NativeMethods.PwRenderFullContent))
                {
                    return false;
                }
            }
            finally
            {
                graphics.ReleaseHdc(deviceContext);
            }

            var data = bitmap.LockBits(
                new Rectangle(0, 0, width, height),
                ImageLockMode.ReadOnly,
                PixelFormat.Format32bppArgb);

            try
            {
                var stride = data.Stride;
                if (stride <= 0)
                {
                    return false;
                }

                var pixels = new byte[stride * height];
                Marshal.Copy(data.Scan0, pixels, 0, pixels.Length);
                return TryScanColumns(taskbar, pixels, stride, width, height, intervals);
            }
            finally
            {
                bitmap.UnlockBits(data);
            }
        }
        catch (ExternalException)
        {
            return false;
        }
        catch (ArgumentException)
        {
            return false;
        }
    }

    private static bool TryScanColumns(
        TaskbarSnapshot taskbar,
        byte[] pixels,
        int stride,
        int width,
        int height,
        List<(int Left, int Right)> intervals)
    {
        var inset = Math.Max(2, (int)Math.Round(4.0 * taskbar.Dpi / 96.0));
        var top = Math.Min(inset, height - 1);
        var bottom = Math.Max(top + 1, height - inset);
        var padding = Math.Max(2, (int)Math.Round(ContentPaddingDip * taskbar.Dpi / 96.0));
        var runStart = -1;

        for (var x = 0; x < width; x++)
        {
            var sum = 0.0;
            var sumOfSquares = 0.0;
            var minimum = int.MaxValue;
            var maximum = int.MinValue;
            var count = 0;

            for (var y = top; y < bottom; y++)
            {
                var index = (y * stride) + (x * 4);
                var blue = pixels[index];
                var green = pixels[index + 1];
                var red = pixels[index + 2];
                var luminance = (0.114 * blue) + (0.587 * green) + (0.299 * red);

                sum += luminance;
                sumOfSquares += luminance * luminance;
                minimum = Math.Min(minimum, (int)luminance);
                maximum = Math.Max(maximum, (int)luminance);
                count++;
            }

            var mean = sum / count;
            var variance = Math.Max(0, (sumOfSquares / count) - (mean * mean));
            var standardDeviation = Math.Sqrt(variance);
            var isContent = standardDeviation >= ContentStdDevThreshold
                || maximum - minimum >= ContentLuminanceRangeThreshold;

            if (isContent && runStart < 0)
            {
                runStart = x;
            }
            else if (!isContent && runStart >= 0)
            {
                intervals.Add((Math.Max(0, runStart - padding), Math.Min(width, x + padding)));
                runStart = -1;
            }
        }

        if (runStart >= 0)
        {
            intervals.Add((Math.Max(0, runStart - padding), width));
        }

        return intervals.Count > 0;
    }

    private static void AddKnownControl(
        TaskbarSnapshot taskbar,
        string className,
        List<(int Left, int Right)> intervals)
    {
        var control = NativeMethods.FindWindowEx(taskbar.Handle, 0, className, null);
        if (control == 0 || !NativeMethods.GetWindowRect(control, out var rect))
        {
            return;
        }

        var bounds = NativeMethods.ToPixelRect(rect).Intersect(taskbar.Bounds);
        if (!bounds.IsEmpty)
        {
            intervals.Add((bounds.Left, bounds.Right));
        }
    }

    private static List<(int Left, int Right)> Merge(List<(int Left, int Right)> intervals)
    {
        var merged = new List<(int Left, int Right)>(intervals.Count);

        foreach (var interval in intervals)
        {
            if (merged.Count == 0 || interval.Left > merged[^1].Right)
            {
                merged.Add(interval);
                continue;
            }

            var previous = merged[^1];
            merged[^1] = (previous.Left, Math.Max(previous.Right, interval.Right));
        }

        return merged;
    }
}
