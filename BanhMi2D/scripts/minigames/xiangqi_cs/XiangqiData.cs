using System;
using System.Collections.Generic;
using Godot;

namespace BanhMiExe.Minigames.Xiangqi
{
	public enum PieceType
	{
		General,   // Tướng
		Advisor,   // Sĩ
		Elephant,  // Tượng
		Horse,     // Mã
		Chariot,   // Xe
		Cannon,    // Pháo
		Soldier    // Tốt
	}

	public enum Faction
	{
		Red,
		Black
	}

	public class Piece
	{
		public PieceType Type { get; set; }
		public Faction Faction { get; set; }
		public int X { get; set; }
		public int Y { get; set; }
		
		// For visual association in the Board
		public Control Visual { get; set; }

		public Piece(PieceType type, Faction faction, int x, int y)
		{
			Type = type;
			Faction = faction;
			X = x;
			Y = y;
		}

		public Piece Clone()
		{
			return new Piece(Type, Faction, X, Y);
		}
	}

	public class BoardState
	{
		public const int COLS = 9;
		public const int ROWS = 10;

		public Piece[,] Grid { get; private set; }

		public BoardState()
		{
			Grid = new Piece[COLS, ROWS];
		}

		public void AddPiece(Piece piece)
		{
			if (IsInBounds(piece.X, piece.Y))
			{
				Grid[piece.X, piece.Y] = piece;
			}
		}

		public void RemovePiece(int x, int y)
		{
			if (IsInBounds(x, y))
			{
				Grid[x, y] = null;
			}
		}

		public Piece GetPiece(int x, int y)
		{
			if (IsInBounds(x, y)) return Grid[x, y];
			return null;
		}

		// Move a piece logically without checking rules. Returns the captured piece, if any.
		public Piece MovePiece(int fromX, int fromY, int toX, int toY)
		{
			if (!IsInBounds(fromX, fromY) || !IsInBounds(toX, toY)) return null;

			Piece mover = Grid[fromX, fromY];
			if (mover == null) return null;

			Piece captured = Grid[toX, toY];

			Grid[fromX, fromY] = null;
			Grid[toX, toY] = mover;
			mover.X = toX;
			mover.Y = toY;

			return captured;
		}

		public BoardState Clone()
		{
			var clone = new BoardState();
			for (int x = 0; x < COLS; x++)
			{
				for (int y = 0; y < ROWS; y++)
				{
					if (Grid[x, y] != null)
					{
						clone.Grid[x, y] = Grid[x, y].Clone();
					}
				}
			}
			return clone;
		}

		public static bool IsInBounds(int x, int y)
		{
			return x >= 0 && x < COLS && y >= 0 && y < ROWS;
		}

		public static bool IsInPalace(int x, int y, Faction faction)
		{
			if (x < 3 || x > 5) return false;
			if (faction == Faction.Black)
				return y >= 0 && y <= 2;
			else // Red
				return y >= 7 && y <= 9;
		}

		public static bool HasCrossedRiver(int y, Faction faction)
		{
			if (faction == Faction.Black)
				return y >= 5;
			else // Red
				return y <= 4;
		}
	}
}
