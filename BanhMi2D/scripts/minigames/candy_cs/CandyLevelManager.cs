using Godot;
using System.Collections.Generic;

// ============================================================
// CandyLevelManager.cs
// Manages 50 difficulty levels for the Match-3 minigame.
// Defines TargetScore, MaxMoves, and reward amounts.
// ============================================================

public class CandyLevelData
{
    public int Level       { get; set; }
    public int TargetScore { get; set; }
    public int MaxMoves    { get; set; }
    public int Reward      { get; set; } // currency awarded on win (stars×amount)
}

public class CandyLevelManager
{
    public int  CurrentLevel  { get; private set; }
    public int  Score         { get; private set; }
    public int  MovesLeft     { get; private set; }
    public bool IsGameOver    => MovesLeft <= 0 && Score < CurrentData.TargetScore;
    public bool IsGameWon     => Score >= CurrentData.TargetScore;

    public CandyLevelData CurrentData => _levels[CurrentLevel - 1];

    private readonly List<CandyLevelData> _levels;

    // ── Constructor ──────────────────────────────────────────
    public CandyLevelManager(int startLevel = 1)
    {
        CurrentLevel = Mathf.Clamp(startLevel, 1, 50);
        _levels = BuildLevels();
        MovesLeft = CurrentData.MaxMoves;
    }

    // ── Scoring ──────────────────────────────────────────────
    public void AddScore(int points)
    {
        Score += points;
    }

    public void UseMove()
    {
        if (MovesLeft > 0) MovesLeft--;
    }

    // ── Reward ───────────────────────────────────────────────
    /// Returns how many stars (1-3) the player earned this level.
    public int GetStars()
    {
        float ratio = (float)Score / CurrentData.TargetScore;
        if (ratio >= 2.0f) return 3;
        if (ratio >= 1.4f) return 2;
        return 1;
    }

    /// Currency amount to award based on stars.
    public int GetRewardAmount()
    {
        return CurrentData.Reward * GetStars();
    }

    // ── Level Builder ─────────────────────────────────────────
    private List<CandyLevelData> BuildLevels()
    {
        var list = new List<CandyLevelData>();
        for (int i = 1; i <= 50; i++)
        {
            // Score and moves scale gradually with steeper curve
            float t = (i - 1) / 49f;
            int target = Mathf.RoundToInt(Mathf.Lerp(3000f,  250000f, Mathf.Pow(t, 1.6f)));
            int moves  = Mathf.RoundToInt(Mathf.Lerp(30f,    18f,     t));
            int reward = Mathf.RoundToInt(Mathf.Lerp(500f,   8000f,   t));

            list.Add(new CandyLevelData
            {
                Level       = i,
                TargetScore = target,
                MaxMoves    = moves,
                Reward      = reward,
            });
        }
        return list;
    }
}
