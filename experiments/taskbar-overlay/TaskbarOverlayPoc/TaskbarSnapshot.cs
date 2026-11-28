using BaboJUPulse.TaskbarOverlayPoc.Core;

namespace BaboJUPulse.TaskbarOverlayPoc;

internal sealed record TaskbarSnapshot(
    nint Handle,
    PixelRect Bounds,
    PixelRect MonitorBounds,
    uint Dpi,
    bool IsVertical,
    bool IsAutoHide);
