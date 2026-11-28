using BaboJUPulse.TaskbarOverlayPoc.Core;

namespace BaboJUPulse.TaskbarOverlayPoc.Tests;

public sealed class TaskbarLayoutTests
{
    private static readonly PixelRect Taskbar = new(0, 0, 1920, 48);

    [Fact]
    public void PlacesInLeftmostGapWhenTaskbarIsEmpty()
    {
        var slot = TaskbarLayout.FindHorizontalSlot(Taskbar, [], 320, 32, 6);

        Assert.Equal(new PixelRect(6, 8, 326, 40), slot);
    }

    [Fact]
    public void AvoidsCenteredControlsAndUsesTheLeftmostFittingGap()
    {
        PixelRect[] occupied =
        [
            new(760, 0, 1180, 48),
        ];

        var slot = TaskbarLayout.FindHorizontalSlot(Taskbar, occupied, 320, 32, 6);

        Assert.Equal(new PixelRect(6, 8, 326, 40), slot);
    }

    [Fact]
    public void UsesRightGapWhenLeftGapIsTooSmall()
    {
        PixelRect[] occupied =
        [
            new(250, 0, 1400, 48),
        ];

        var slot = TaskbarLayout.FindHorizontalSlot(Taskbar, occupied, 320, 32, 6);

        Assert.Equal(new PixelRect(1406, 8, 1726, 40), slot);
    }

    [Fact]
    public void ReturnsNullWhenNoGapFits()
    {
        PixelRect[] occupied =
        [
            new(300, 0, 1600, 48),
        ];

        var slot = TaskbarLayout.FindHorizontalSlot(Taskbar, occupied, 320, 32, 6);

        Assert.Null(slot);
    }

    [Fact]
    public void ReturnsNullWhenOverlayIsWiderThanTaskbar()
    {
        var slot = TaskbarLayout.FindHorizontalSlot(Taskbar, [], 2000, 32, 6);

        Assert.Null(slot);
    }

    [Fact]
    public void ReturnsNullWhenOverlayIsTallerThanUsableTaskbar()
    {
        var slot = TaskbarLayout.FindHorizontalSlot(Taskbar, [], 320, 44, 6);

        Assert.Null(slot);
    }

    [Fact]
    public void InflatesObstaclesByTheMargin()
    {
        PixelRect[] occupied =
        [
            new(320, 0, 800, 48),
        ];

        var slot = TaskbarLayout.FindHorizontalSlot(Taskbar, occupied, 300, 32, 6);

        Assert.Equal(new PixelRect(6, 8, 306, 40), slot);
    }

    [Fact]
    public void MergesOverlappingObstacles()
    {
        PixelRect[] occupied =
        [
            new(300, 0, 700, 48),
            new(650, 0, 1000, 48),
        ];

        var slot = TaskbarLayout.FindHorizontalSlot(Taskbar, occupied, 250, 32, 6);

        Assert.Equal(new PixelRect(6, 8, 256, 40), slot);
    }

    [Fact]
    public void KeepsPlacementInsideANegativeCoordinateMonitor()
    {
        var leftMonitorTaskbar = new PixelRect(-1920, 0, 0, 48);
        PixelRect[] occupied =
        [
            new(-1300, 0, -800, 48),
        ];

        var slot = TaskbarLayout.FindHorizontalSlot(leftMonitorTaskbar, occupied, 320, 32, 6);

        Assert.Equal(new PixelRect(-1914, 8, -1594, 40), slot);
    }

    [Theory]
    [InlineData(96, 320)]
    [InlineData(120, 400)]
    [InlineData(144, 480)]
    [InlineData(192, 640)]
    public void ScalesTheOverlayUsingTheTaskbarDpi(int dpi, int expectedWidth)
    {
        var overlayWidth = (int)Math.Round(320 * dpi / 96.0);
        var taskbar = new PixelRect(0, 0, 1920, 48 * dpi / 96);
        var occupied = new PixelRect(700 * dpi / 96, 0, 1200 * dpi / 96, taskbar.Height);

        var slot = TaskbarLayout.FindHorizontalSlot(taskbar, [occupied], overlayWidth, 32 * dpi / 96, 6 * dpi / 96);

        Assert.True(slot.HasValue);
        var placed = slot.GetValueOrDefault();
        Assert.Equal(expectedWidth, placed.Width);
        Assert.True(placed.Left >= taskbar.Left);
        Assert.True(placed.Right <= taskbar.Right);
        Assert.False(placed.IntersectsWith(occupied));
    }

    [Fact]
    public void ReturnsNullForAVerticalTaskbarBecauseTheReadoutIsHorizontal()
    {
        var verticalTaskbar = new PixelRect(0, 0, 48, 1080);

        var slot = TaskbarLayout.FindHorizontalSlot(verticalTaskbar, [], 320, 32, 6);

        Assert.Null(slot);
    }
}
