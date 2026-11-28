namespace BaboJUPulse.TaskbarOverlayPoc.Core;

/// <summary>
/// A rectangle in physical pixels. The overlay experiment deliberately keeps
/// this type free of WPF and Win32 so the placement rules can be tested off
/// Windows.
/// </summary>
public readonly record struct PixelRect(int Left, int Top, int Right, int Bottom)
{
    public int Width => Right - Left;

    public int Height => Bottom - Top;

    public bool IsEmpty => Width <= 0 || Height <= 0;

    public static PixelRect FromSize(int left, int top, int width, int height) =>
        new(left, top, left + width, top + height);

    public PixelRect Inflate(int amount) =>
        new(Left - amount, Top - amount, Right + amount, Bottom + amount);

    public PixelRect Deflate(int amount) => Inflate(-amount);

    public PixelRect Intersect(PixelRect other) =>
        new(
            Math.Max(Left, other.Left),
            Math.Max(Top, other.Top),
            Math.Min(Right, other.Right),
            Math.Min(Bottom, other.Bottom));

    public bool IntersectsWith(PixelRect other) =>
        Left < other.Right
        && Right > other.Left
        && Top < other.Bottom
        && Bottom > other.Top;

    public PixelRect Offset(int dx, int dy) =>
        new(Left + dx, Top + dy, Right + dx, Bottom + dy);

    public override string ToString() =>
        $"({Left},{Top})-({Right},{Bottom}) [{Width}x{Height}]";
}
