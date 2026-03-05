using Godot;
using System;
using System.Collections.Generic;
using System.Text.Json;
using System.Text.Json.Serialization;

namespace BanhMiExe.Minigames.Xiangqi
{
	public class PuzzleConfig
	{
		[JsonPropertyName("level")] public int Level { get; set; }
		[JsonPropertyName("description")] public string Description { get; set; }
		[JsonPropertyName("aiLevel")] public int AiLevel { get; set; }
		[JsonPropertyName("pieces")] public List<PieceConfig> Pieces { get; set; }
	}

	public class PieceConfig
	{
		[JsonPropertyName("type")] public string Type { get; set; }
		[JsonPropertyName("faction")] public string Faction { get; set; }
		[JsonPropertyName("x")] public int X { get; set; }
		[JsonPropertyName("y")] public int Y { get; set; }
	}

	public class XiangqiLevelManager
	{
		private List<PuzzleConfig> _puzzles = new List<PuzzleConfig>();
		public int CurrentLevelIndex { get; private set; }
		public PuzzleConfig CurrentPuzzle => _puzzles.Count > 0 ? _puzzles[CurrentLevelIndex] : null;

		public bool IsGameOver { get; private set; }
		public bool IsGameWon { get; private set; }

		public XiangqiLevelManager(int mapIndex = 0)
		{
			LoadPuzzles();
			CurrentLevelIndex = Math.Clamp(mapIndex, 0, Math.Max(0, _puzzles.Count - 1));
			ResetState();
		}

		private void LoadPuzzles()
		{
			string path = "res://data/xiangqi_puzzles.json";
			if (!FileAccess.FileExists(path))
			{
				GD.PrintErr($"Xiangqi Puzzle file not found at {path}");
				return;
			}

			try
			{
				using var file = FileAccess.Open(path, FileAccess.ModeFlags.Read);
				string jsonStr = file.GetAsText();
				var options = new JsonSerializerOptions { PropertyNameCaseInsensitive = true };
				_puzzles = JsonSerializer.Deserialize<List<PuzzleConfig>>(jsonStr, options);
				GD.Print($"Loaded {_puzzles.Count} Xiangqi puzzles.");
			}
			catch (Exception e)
			{
				GD.PrintErr($"Failed to parse Xiangqi puzzles: {e.Message}");
			}
		}

		public void ResetState()
		{
			IsGameOver = false;
			IsGameWon = false;
		}

		public BoardState CreateBoardState()
		{
			var state = new BoardState();
			var config = CurrentPuzzle;
			if (config == null) return state;

			foreach (var pc in config.Pieces)
			{
				if (Enum.TryParse(pc.Type, true, out PieceType type) && 
					Enum.TryParse(pc.Faction, true, out Faction faction))
				{
					state.AddPiece(new Piece(type, faction, pc.X, pc.Y));
				}
				else
				{
					GD.PrintErr($"Invalid Enum in Puzzle Data: {pc.Type} or {pc.Faction}");
				}
			}

			return state;
		}

		public void TriggerWin()
		{
			IsGameWon = true;
			IsGameOver = true;
		}

		public void TriggerLose()
		{
			IsGameOver = true;
		}

		public int GetRewardForCurrentLevel()
		{
			// Give a fixed reward or base it on level index
			return 100 + (CurrentLevelIndex * 20);
		}
	}
}
