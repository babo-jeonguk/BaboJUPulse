namespace BaboJUPulse.TaskbarOverlayPoc.Core;

/// <summary>
/// Pure horizontal placement rules for an independent overlay. The overlay has
/// no reserved taskbar space, so the only safe policy is: find a gap that fits
/// with margins, or report no placement and let the host hide the overlay.
/// </summary>
public static class TaskbarLayout
{
    public static PixelRect? FindHorizontalSlot(
        PixelRect taskbarBounds,
        IReadOnlyList<PixelRect> occupiedRegions,
        int overlayWidth,
        int overlayHeight,
        int margin)
    {
        if (taskbarBounds.IsEmpty)
        {
            return null;
        }

        if (overlayWidth <= 0 || overlayHeight <= 0 || margin < 0)
        {
            throw new ArgumentOutOfRangeException(
                nameof(overlayWidth),
                "Overlay dimensions must be positive and the margin must not be negative.");
        }

        var usable = taskbarBounds.Deflate(margin);
        if (usable.Width < overlayWidth || usable.Height < overlayHeight)
        {
            return null;
        }

        var blocked = BuildBlockedIntervals(usable, occupiedRegions, margin);
        var firstGap = FindFirstGap(usable.Left, usable.Right, blocked, overlayWidth);
        if (firstGap is null)
        {
            return null;
        }

        var top = usable.Top + ((usable.Height - overlayHeight) / 2);
        return PixelRect.FromSize(firstGap.Value.Left, top, overlayWidth, overlayHeight);
    }

    private static List<(int Left, int Right)> BuildBlockedIntervals(
        PixelRect usable,
        IReadOnlyList<PixelRect> occupiedRegions,
        int margin)
    {
        var intervals = new List<(int Left, int Right)>(occupiedRegions.Count);

        foreach (var region in occupiedRegions)
        {
            var expanded = region.Inflate(margin).Intersect(usable);
            if (!expanded.IsEmpty)
            {
                intervals.Add((expanded.Left, expanded.Right));
            }
        }

        intervals.Sort(static (left, right) => left.Left.CompareTo(right.Left));
        return Merge(intervals);
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

    private static (int Left, int Right)? FindFirstGap(
        int left,
        int right,
        IReadOnlyList<(int Left, int Right)> blocked,
        int minimumWidth)
    {
        var cursor = left;

        foreach (var interval in blocked)
        {
            if (interval.Left - cursor >= minimumWidth)
            {
                return (cursor, interval.Left);
            }

            cursor = Math.Max(cursor, interval.Right);
            if (cursor >= right)
            {
                break;
            }
        }

        return right - cursor >= minimumWidth
            ? (cursor, right)
            : null;
    }
}
