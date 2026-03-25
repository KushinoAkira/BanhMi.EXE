using Godot;
using System;

public class LevelManager
{
    public int CurrentLevel { get; private set; }
    public int TargetLines { get; private set; }
    public int LinesCleared { get; private set; }
    
    // Fall speeds (Gravity) -> Time in seconds per cell
    public float CurrentGravity { get; private set; }

    // Constants
    private const int MAX_LEVEL = 50;

    public LevelManager(int startLevel)
    {
        CurrentLevel = Math.Clamp(startLevel, 1, MAX_LEVEL);
        LinesCleared = 0;
        CalculateLevelStats();
    }

    public void AddLines(int lines)
    {
        LinesCleared += lines;
    }

    public bool IsLevelComplete()
    {
        return LinesCleared >= TargetLines;
    }

    public int GetGarbageAmount()
    {
        // To simulate Tetr.io battle garbage, from level 10 onwards we periodically add garbage.
        // Returns the number of garbage lines to spawn right now based on an internal condition if we wanted
        // Or BoardManager can call this periodically based on a timer.
        if (CurrentLevel < 10) return 0;
        
        // E.g., at level 10, 1 line per 10 seconds. At level 50, 1 line per 2 seconds.
        // Handled in BoardManager using a timer, this just gives the base rate.
        return 0; // BoardManager uses GetGarbageSpawnRate() instead
    }

    public float GetGarbageSpawnRate()
    {
        if (CurrentLevel < 10) return -1f; // No garbage
        // Level 10 = 10s, Level 50 = 2s
        float t = (CurrentLevel - 10) / 40f; 
        return Mathf.Lerp(10f, 2f, t);
    }

    public float GetLockDelay()
    {
        return 0.5f; // Standard Tetr.io lock delay
    }

    // Returns [Star1Score, Star2Score, Star3Score]
    public int[] GetStarTargets()
    {
        int avgTargetScore = TargetLines * 150;
        return new int[] { 
            (int)(avgTargetScore * 0.7f), 
            (int)(avgTargetScore * 1.1f), 
            (int)(avgTargetScore * 1.5f) 
        };
    }

    private void CalculateLevelStats()
    {
        if (CurrentLevel <= 10) TargetLines = 10;
        else if (CurrentLevel <= 20) TargetLines = 15;
        else if (CurrentLevel <= 30) TargetLines = 20;
        else if (CurrentLevel <= 40) TargetLines = 30;
        else TargetLines = 40;

        // Speed curve: Level 1 = 1.0s, Level 50 = 0.05s
        // Tetr.io gets extremely fast. At hyper speeds, it relies entirely on lock delay.
        float t = (CurrentLevel - 1) / 49f;
        CurrentGravity = Mathf.Lerp(1.0f, 0.03f, t);
    }
}
