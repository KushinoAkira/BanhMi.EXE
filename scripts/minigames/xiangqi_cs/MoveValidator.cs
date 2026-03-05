using System;
using System.Collections.Generic;
using Godot;

namespace BanhMiExe.Minigames.Xiangqi
{
	public static class MoveValidator
	{
		/// <summary>
		/// Returns all strictly legal moves for a piece, ensuring the move doesn't place own general in check
		/// and doesn't violate the "Flying General" rule.
		/// </summary>
		public static List<Vector2I> GetLegalMoves(BoardState board, Piece piece)
		{
			var legalMoves = new List<Vector2I>();
			var pseudoMoves = GetPseudoLegalMoves(board, piece);

			foreach (var move in pseudoMoves)
			{
				if (!WouldBeInCheck(board, piece, move.X, move.Y))
				{
					legalMoves.Add(move);
				}
			}

			return legalMoves;
		}

		public static bool IsCheck(BoardState board, Faction faction)
		{
			// Find the General
			Piece general = null;
			for (int x = 0; x < BoardState.COLS; x++)
			{
				for (int y = 0; y < BoardState.ROWS; y++)
				{
					var p = board.GetPiece(x, y);
					if (p != null && p.Type == PieceType.General && p.Faction == faction)
					{
						general = p;
						break;
					}
				}
				if (general != null) break;
			}

			if (general == null) return false; // Should never happen in a valid game

			// Check if any enemy piece can attack the General's position
			Faction enemyFaction = faction == Faction.Red ? Faction.Black : Faction.Red;
			for (int x = 0; x < BoardState.COLS; x++)
			{
				for (int y = 0; y < BoardState.ROWS; y++)
				{
					var p = board.GetPiece(x, y);
					if (p != null && p.Faction == enemyFaction)
					{
						var enemyMoves = GetPseudoLegalMoves(board, p);
						foreach (var move in enemyMoves)
						{
							if (move.X == general.X && move.Y == general.Y) return true;
						}
					}
				}
			}

			return false;
		}

		public static bool HasNoLegalMoves(BoardState board, Faction faction)
		{
			for (int x = 0; x < BoardState.COLS; x++)
			{
				for (int y = 0; y < BoardState.ROWS; y++)
				{
					var p = board.GetPiece(x, y);
					if (p != null && p.Faction == faction)
					{
						var legalMoves = GetLegalMoves(board, p);
						if (legalMoves.Count > 0) return false;
					}
				}
			}
			return true;
		}

		public static bool IsCheckmate(BoardState board, Faction faction)
		{
			if (!IsCheck(board, faction)) return false;
			return HasNoLegalMoves(board, faction);
		}

		private static bool WouldBeInCheck(BoardState board, Piece mover, int toX, int toY)
		{
			// Simulate the move
			BoardState clone = board.Clone();
			clone.MovePiece(mover.X, mover.Y, toX, toY);

			// Check if own general is in check
			if (IsCheck(clone, mover.Faction)) return true;

			// Check the Flying General rule (Generals facing each other)
			if (GeneralsFaceEachOther(clone)) return true;

			return false;
		}

		private static bool GeneralsFaceEachOther(BoardState board)
		{
			Piece redG = null, blackG = null;
			for (int x = 3; x <= 5; x++)
			{
				for (int y = 0; y <= 9; y++)
				{
					var p = board.GetPiece(x, y);
					if (p != null && p.Type == PieceType.General)
					{
						if (p.Faction == Faction.Red) redG = p;
						else blackG = p;
					}
				}
			}

			if (redG == null || blackG == null) return false;
			if (redG.X != blackG.X) return false;

			int col = redG.X;
			int minY = Math.Min(redG.Y, blackG.Y);
			int maxY = Math.Max(redG.Y, blackG.Y);
			int piecesBetween = 0;

			for (int y = minY + 1; y < maxY; y++)
			{
				if (board.GetPiece(col, y) != null) piecesBetween++;
			}

			return piecesBetween == 0;
		}

		/// <summary>
		/// Returns all raw movement rules, ignoring "being in check" logic.
		/// </summary>
		public static List<Vector2I> GetPseudoLegalMoves(BoardState board, Piece piece)
		{
			var moves = new List<Vector2I>();
			int x = piece.X;
			int y = piece.Y;
			Faction ally = piece.Faction;

			// Helper to add moves that don't capture allies
			void AddIfValid(int tx, int ty)
			{
				if (!BoardState.IsInBounds(tx, ty)) return;
				Piece target = board.GetPiece(tx, ty);
				if (target == null || target.Faction != ally)
				{
					moves.Add(new Vector2I(tx, ty));
				}
			}

			switch (piece.Type)
			{
				case PieceType.General:
					int[] gx = { 0, 0, 1, -1 };
					int[] gy = { 1, -1, 0, 0 };
					for (int i = 0; i < 4; i++)
					{
						int tx = x + gx[i];
						int ty = y + gy[i];
						if (BoardState.IsInPalace(tx, ty, ally)) AddIfValid(tx, ty);
					}
					break;

				case PieceType.Advisor:
					int[] ax = { 1, 1, -1, -1 };
					int[] ay = { 1, -1, 1, -1 };
					for (int i = 0; i < 4; i++)
					{
						int tx = x + ax[i];
						int ty = y + ay[i];
						if (BoardState.IsInPalace(tx, ty, ally)) AddIfValid(tx, ty);
					}
					break;

				case PieceType.Elephant:
					int[] ex = { 2, 2, -2, -2 };
					int[] ey = { 2, -2, 2, -2 };
					for (int i = 0; i < 4; i++)
					{
						int tx = x + ex[i];
						int ty = y + ey[i];
						int blockX = x + ex[i] / 2;
						int blockY = y + ey[i] / 2;

						if (BoardState.IsInBounds(tx, ty) && !BoardState.HasCrossedRiver(ty, ally))
						{
							if (board.GetPiece(blockX, blockY) == null) AddIfValid(tx, ty); // Not blocked
						}
					}
					break;

				case PieceType.Horse:
					int[] hx = { 1, 2, 2, 1, -1, -2, -2, -1 };
					int[] hy = { 2, 1, -1, -2, -2, -1, 1, 2 };
					int[] bx = { 0, 1, 1, 0, 0, -1, -1, 0 }; // Orthogonal block points matching the 8 moves
					int[] by = { 1, 0, 0, -1, -1, 0, 0, 1 };
					for (int i = 0; i < 8; i++)
					{
						int tx = x + hx[i];
						int ty = y + hy[i];
						int blockX = x + bx[i];
						int blockY = y + by[i];

						if (BoardState.IsInBounds(blockX, blockY) && board.GetPiece(blockX, blockY) == null)
						{
							AddIfValid(tx, ty);
						}
					}
					break;

				case PieceType.Chariot:
					int[] cx = { 0, 0, 1, -1 };
					int[] cy = { 1, -1, 0, 0 };
					for (int i = 0; i < 4; i++)
					{
						for (int step = 1; step < Math.Max(BoardState.COLS, BoardState.ROWS); step++)
						{
							int tx = x + cx[i] * step;
							int ty = y + cy[i] * step;
							if (!BoardState.IsInBounds(tx, ty)) break;

							Piece target = board.GetPiece(tx, ty);
							if (target == null)
							{
								moves.Add(new Vector2I(tx, ty));
							}
							else
							{
								if (target.Faction != ally) moves.Add(new Vector2I(tx, ty));
								break; // Blocked by piece (ally or enemy)
							}
						}
					}
					break;

				case PieceType.Cannon:
					int[] nx = { 0, 0, 1, -1 };
					int[] ny = { 1, -1, 0, 0 };
					for (int i = 0; i < 4; i++)
					{
						bool jumped = false;
						for (int step = 1; step < Math.Max(BoardState.COLS, BoardState.ROWS); step++)
						{
							int tx = x + nx[i] * step;
							int ty = y + ny[i] * step;
							if (!BoardState.IsInBounds(tx, ty)) break;

							Piece target = board.GetPiece(tx, ty);
							if (!jumped)
							{
								if (target == null)
								{
									moves.Add(new Vector2I(tx, ty)); // Can move to empty
								}
								else
								{
									jumped = true; // Found the screen (ngòi)
								}
							}
							else
							{
								if (target != null)
								{
									if (target.Faction != ally) moves.Add(new Vector2I(tx, ty)); // Can capture
									break; // Blocked after one jump
								}
							}
						}
					}
					break;

				case PieceType.Soldier:
					int fwdY = ally == Faction.Red ? -1 : 1; // Red moves up (Y decreases), Black moves down (Y increases)
					AddIfValid(x, y + fwdY); // Forward move always allowed

					if (BoardState.HasCrossedRiver(y, ally))
					{
						AddIfValid(x + 1, y);
						AddIfValid(x - 1, y);
					}
					break;
			}

			return moves;
		}
	}
}
