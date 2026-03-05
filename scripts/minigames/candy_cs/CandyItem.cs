using Godot;

// ============================================================
// CandyItem.cs
// Represents a single cell item on the Match-3 board.
// Now tracks SpecialType in addition to base CandyType.
// ============================================================

public enum CandyType    { Red = 0, Blue, Green, Yellow, Purple, Orange, COUNT }
public enum SpecialType  { None = 0, LineBlastH, LineBlastV, ColorBomb, Bomb }

public class CandyItem
{
    // ── Identity ──────────────────────────────────────────────
    public CandyType   Type    { get; private set; }
    public SpecialType Special { get; set; } = SpecialType.None;

    // The actual Godot node shown on screen
    public Control Visual { get; set; }

    // Current logical grid position (col, row)
    public int Col { get; set; }
    public int Row { get; set; }

    // ── Colors (indexed by CandyType) ────────────────────────
    public static readonly Color[] TypeColors = new Color[]
    {
        new Color(0.95f, 0.2f,  0.2f,  1f), // Red
        new Color(0.2f,  0.45f, 0.95f, 1f), // Blue
        new Color(0.2f,  0.80f, 0.3f,  1f), // Green
        new Color(0.95f, 0.85f, 0.1f,  1f), // Yellow
        new Color(0.70f, 0.2f,  0.90f, 1f), // Purple
        new Color(0.95f, 0.50f, 0.1f,  1f), // Orange
    };

    // Base symbols (normal candy)
    private static readonly string[] TypeSymbols = new string[]
    {
        "❤", "✦", "♣", "★", "◆", "●"
    };

    // ── Constructor ──────────────────────────────────────────
    public CandyItem(CandyType type, int col, int row, SpecialType special = SpecialType.None)
    {
        Type    = type;
        Col     = col;
        Row     = row;
        Special = special;
    }

    // ── Helpers ──────────────────────────────────────────────
    public Color GetColor() => TypeColors[(int)Type];

    public string GetSymbol()
    {
        return Special switch
        {
            SpecialType.LineBlastH => "↔",   // Horizontal blaster
            SpecialType.LineBlastV => "↕",   // Vertical blaster
            SpecialType.ColorBomb  => "💥",   // Color bomb
            SpecialType.Bomb       => "🎁",   // 3x3 Bomb (Wrapped Candy)
            _                     => TypeSymbols[(int)Type],
        };
    }

    /// Tint used to decorate the special item visual on top of base color
    public Color GetBorderColor()
    {
        return Special switch
        {
            SpecialType.LineBlastH => new Color(1f, 1f, 0.2f, 1f),  // bright yellow stripe
            SpecialType.LineBlastV => new Color(0.2f, 1f, 1f, 1f),  // bright cyan stripe
            SpecialType.ColorBomb  => new Color(1f, 1f, 1f, 1f),    // white
            SpecialType.Bomb       => new Color(1f, 0.2f, 0.8f, 1f), // Magenta border
            _                     => GetColor().Darkened(0.3f),
        };
    }

    public bool IsSpecial => Special != SpecialType.None;
}
