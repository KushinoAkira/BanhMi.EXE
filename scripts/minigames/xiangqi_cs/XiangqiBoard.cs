using Godot;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

namespace BanhMiExe.Minigames.Xiangqi
{
	public partial class XiangqiBoard : Control
	{
		[Signal] public delegate void MiniGameWonEventHandler(int levelIndex, int rewardAmount, int stars);
		[Signal] public delegate void MiniGameClosedEventHandler();

		[Export] public NodePath BoardContainerPath;
		[Export] public NodePath PiecesLayerPath;
		[Export] public NodePath HighlightLayerPath;
		[Export] public NodePath VictoryScreenPath;
		[Export] public NodePath LblMessagePath;
		[Export] public NodePath LblLevelPath;
		[Export] public NodePath BtnClosePath;
		[Export] public int StartLevel = 0;

		public const float CELL = 62f;
		public const float OFFSET_X = 40f;
		public const float OFFSET_Y = 40f;

		private XiangqiLevelManager _level;
		private BoardState _board;

		private Control _boardContainer;
		private Control _piecesLayer;
		private Control _highlightLayer;
		private Control _victoryScreen;
		private Label _lblMessage;
		private Label _lblLevel;
		private Label _lblTimer;
		private Label _lblScore;

		private Piece _selectedPiece;
		private bool _isDragging;
		private Vector2 _dragOffset;
		private Vector2 _originalPos;

		private List<Vector2I> _currentLegalMoves = new List<Vector2I>();
		private bool _inputLocked = false;
		private readonly Random _rng = new Random();

		private AudioStreamPlayer _sfxMove;
		private AudioStreamPlayer _sfxCapture;
		private AudioStreamPlayer _bgmPlayer;

		// Timer & Scoring
		private float _timeLimit;    // seconds
		private float _timeRemaining;
		private int _captureScore;   // points from capturing pieces
		private bool _timerRunning;

		// Threefold repetition tracking
		private List<string> _positionHistory = new List<string>();

		private static readonly Dictionary<PieceType, int> CapturePoints = new()
		{
			{ PieceType.General,  0 },
			{ PieceType.Chariot,  300 },
			{ PieceType.Cannon,   200 },
			{ PieceType.Horse,    200 },
			{ PieceType.Elephant, 50 },
			{ PieceType.Advisor,  50 },
			{ PieceType.Soldier,  30 },
		};

		private static readonly Dictionary<PieceType, string> PieceSymbols = new()
		{
			{ PieceType.General, "B" },
			{ PieceType.Advisor, "A" },
			{ PieceType.Elephant,"E" },
			{ PieceType.Horse,   "H" },
			{ PieceType.Chariot, "R" },
			{ PieceType.Cannon,  "C" },
			{ PieceType.Soldier, "P" }
		};

		public override void _Ready()
		{
			_boardContainer = GetNodeOrNull<Control>(BoardContainerPath);
			_piecesLayer = GetNodeOrNull<Control>(PiecesLayerPath);
			_highlightLayer = GetNodeOrNull<Control>(HighlightLayerPath);
			_victoryScreen = GetNodeOrNull<Control>(VictoryScreenPath);
			_lblMessage = GetNodeOrNull<Label>(LblMessagePath);
			_lblLevel = GetNodeOrNull<Label>(LblLevelPath);

			var btnClose = GetNodeOrNull<Button>(BtnClosePath);
			if (btnClose != null) btnClose.Pressed += OnClosePressed;

			var btnNextLevel = GetNodeOrNull<Button>("Overlay/VictoryScreen/VBox/BtnRow/BtnNextLevel");
			if (btnNextLevel != null) btnNextLevel.Pressed += OnNextLevelPressed;

			if (_victoryScreen != null) _victoryScreen.Visible = false;

			// Create timer and score labels dynamically
			CreateTimerScoreUI();

			_sfxMove = new AudioStreamPlayer();
			_sfxMove.Stream = GD.Load<AudioStream>("res://assets/Music/Wooden_Clack.mp3");
			AddChild(_sfxMove);

			_sfxCapture = new AudioStreamPlayer();
			_sfxCapture.Stream = GD.Load<AudioStream>("res://assets/Music/Purchase_SFX.mp3");
			AddChild(_sfxCapture);

			_bgmPlayer = new AudioStreamPlayer();
			_bgmPlayer.Stream = GD.Load<AudioStream>("res://assets/Music/Quiet Rooms Between Thoughts.mp3");
			AddChild(_bgmPlayer);
			_bgmPlayer.Play();

			LoadPieceTextures();
			_level = new XiangqiLevelManager(StartLevel);
			LoadLevel();
		}

		private void CreateTimerScoreUI()
		{
			// Timer label in the header area
			var header = GetNodeOrNull<Control>("Overlay/Window/VBoxRoot/Header");
			if (header != null)
			{
				_lblTimer = new Label();
				_lblTimer.Text = "";
				_lblTimer.AddThemeFontSizeOverride("font_size", 14);
				_lblTimer.AddThemeColorOverride("font_color", new Color(1f, 0.6f, 0.2f));
				_lblTimer.HorizontalAlignment = HorizontalAlignment.Right;
				_lblTimer.SizeFlagsHorizontal = SizeFlags.ExpandFill;
				header.AddChild(_lblTimer);

				_lblScore = new Label();
				_lblScore.Text = "";
				_lblScore.AddThemeFontSizeOverride("font_size", 14);
				_lblScore.AddThemeColorOverride("font_color", new Color(0.3f, 1f, 0.5f));
				_lblScore.HorizontalAlignment = HorizontalAlignment.Right;
				header.AddChild(_lblScore);
			}
		}

		public override void _Process(double delta)
		{
			if (!_timerRunning || _level.IsGameOver) return;
			_timeRemaining -= (float)delta;
			if (_timeRemaining <= 0)
			{
				_timeRemaining = 0;
				_timerRunning = false;
				_level.TriggerLose();
				if (_lblMessage != null) _lblMessage.Text = "Het thoi gian! Ban da thua!";
				if (_victoryScreen != null) _victoryScreen.Visible = true;
			}
			UpdateTimerDisplay();
		}

		private void UpdateTimerDisplay()
		{
			if (_lblTimer == null) return;
			int mins = (int)_timeRemaining / 60;
			int secs = (int)_timeRemaining % 60;
			_lblTimer.Text = $"{mins}:{secs:D2}";
			// Flash red when low
			if (_timeRemaining < 30)
				_lblTimer.AddThemeColorOverride("font_color", new Color(1f, 0.2f, 0.2f));
			else
				_lblTimer.AddThemeColorOverride("font_color", new Color(1f, 0.6f, 0.2f));
		}

		private float GetTimeLimitForLevel(int levelIndex)
		{
			if (levelIndex < 10) return 120f;  // 2 min for endgame puzzles
			if (levelIndex < 25) return 300f;  // 5 min
			if (levelIndex < 40) return 420f;  // 7 min
			return 600f;                       // 10 min for hardest levels
		}

		private int CalculateStars()
		{
			float timeUsed = _timeLimit - _timeRemaining;
			int timeBonus = (int)(_timeRemaining * 2f); // 2 points per second remaining
			int totalScore = _captureScore + timeBonus;

			// Star thresholds based on level type
			if (_level.CurrentLevelIndex < 10)
			{
				// Endgame: fast solve = 3 stars
				if (timeUsed < _timeLimit * 0.3f) return 3;
				if (timeUsed < _timeLimit * 0.6f) return 2;
				return 1;
			}
			else
			{
				// Full game: score based
				if (totalScore >= 600) return 3;
				if (totalScore >= 300) return 2;
				return 1;
			}
		}

		private void LoadLevel()
		{
			_inputLocked = false;
			_captureScore = 0;
			_positionHistory.Clear();
			if (_victoryScreen != null) _victoryScreen.Visible = false;
			if (_lblLevel != null) _lblLevel.Text = $"Level: {_level.CurrentLevelIndex + 1} - {_level.CurrentPuzzle?.Description}";
			if (_lblScore != null) _lblScore.Text = "0 diem";

			_timeLimit = GetTimeLimitForLevel(_level.CurrentLevelIndex);
			_timeRemaining = _timeLimit;
			_timerRunning = true;
			UpdateTimerDisplay();

			_board = _level.CreateBoardState();
			ClearVisuals();
			CreatePiecesVisuals();
		}

		private void ClearVisuals()
		{
			if (_piecesLayer == null || _highlightLayer == null) return;
			foreach (Node child in _piecesLayer.GetChildren()) child.QueueFree();
			foreach (Node child in _highlightLayer.GetChildren()) child.QueueFree();
			_selectedPiece = null;
			_isDragging = false;
			_currentLegalMoves.Clear();
		}

		private void CreatePiecesVisuals()
		{
			if (_piecesLayer == null) return;

			for (int x = 0; x < BoardState.COLS; x++)
			{
				for (int y = 0; y < BoardState.ROWS; y++)
				{
					Piece p = _board.GetPiece(x, y);
					if (p != null)
					{
						p.Visual = CreatePieceVisual(p);
						p.Visual.Position = GetPixelCoord(x, y);
						_piecesLayer.AddChild(p.Visual);
					}
				}
			}
		}

		private Vector2 GetPixelCoord(int gridX, int gridY)
		{
			return new Vector2(gridX * CELL + OFFSET_X, gridY * CELL + OFFSET_Y);
		}

		// Individual piece texture cache — key: "red_general", "black_soldier", etc.
		private readonly Dictionary<string, Texture2D> _pieceTextures = new();

		private static readonly Dictionary<PieceType, string> PieceNames = new()
		{
			{ PieceType.General,  "general"  },
			{ PieceType.Advisor,  "advisor"  },
			{ PieceType.Elephant, "elephant" },
			{ PieceType.Horse,    "horse"    },
			{ PieceType.Chariot,  "chariot"  },
			{ PieceType.Cannon,   "cannon"   },
			{ PieceType.Soldier,  "soldier"  },
		};

		private void LoadPieceTextures()
		{
			foreach (var faction in new[] { "red", "black" })
			{
				foreach (var (_, name) in PieceNames)
				{
					string path = $"res://assets/textures/xiangqi/{faction}_{name}.png";
					if (ResourceLoader.Exists(path))
						_pieceTextures[$"{faction}_{name}"] = GD.Load<Texture2D>(path);
				}
			}
		}

		private Control CreatePieceVisual(Piece p)
		{
			float pieceSize = CELL - 4f;
			Control wrapper = new Control();

			// Try individual piece texture
			string factionKey = p.Faction == Faction.Red ? "red" : "black";
			string key = $"{factionKey}_{PieceNames.GetValueOrDefault(p.Type, "")}";
			if (_pieceTextures.TryGetValue(key, out Texture2D tex))
			{
				TextureRect tr = new TextureRect();
				tr.Texture     = tex;
				tr.ExpandMode  = TextureRect.ExpandModeEnum.IgnoreSize;
				tr.StretchMode = TextureRect.StretchModeEnum.KeepAspectCentered;
				tr.Size     = new Vector2(pieceSize, pieceSize);
				tr.Position = new Vector2(-pieceSize / 2f, -pieceSize / 2f);
				wrapper.AddChild(tr);
				return wrapper;
			}

			// Fallback: letter circle
			Panel panel = new Panel();
			panel.Size        = new Vector2(pieceSize, pieceSize);
			panel.PivotOffset = panel.Size / 2f;
			panel.Position    = new Vector2(-panel.PivotOffset.X, -panel.PivotOffset.Y);
			Color textColor = p.Faction == Faction.Red ? new Color(0.8f, 0.1f, 0.1f) : new Color(0.1f, 0.1f, 0.1f);
			StyleBoxFlat style = new StyleBoxFlat();
			style.BgColor = new Color(0.9f, 0.8f, 0.6f);
			style.CornerRadiusTopLeft = style.CornerRadiusTopRight =
			style.CornerRadiusBottomLeft = style.CornerRadiusBottomRight = (int)(CELL / 2);
			style.BorderWidthBottom = style.BorderWidthTop =
			style.BorderWidthLeft   = style.BorderWidthRight = 2;
			style.BorderColor = textColor;
			panel.AddThemeStyleboxOverride("panel", style);
			Label lbl = new Label();
			lbl.Text = PieceSymbols.GetValueOrDefault(p.Type, "?");
			lbl.HorizontalAlignment = HorizontalAlignment.Center;
			lbl.VerticalAlignment   = VerticalAlignment.Center;
			lbl.SetAnchorsPreset(LayoutPreset.FullRect);
			lbl.AddThemeColorOverride("font_color", textColor);
			lbl.AddThemeFontSizeOverride("font_size", 22);
			panel.AddChild(lbl);
			wrapper.AddChild(panel);
			return wrapper;
		}

		public override void _Input(InputEvent ev)
		{
			if (_inputLocked || _level.IsGameOver || _piecesLayer == null) return;

			if (ev is InputEventMouseButton mb && mb.ButtonIndex == MouseButton.Left)
			{
				if (mb.Pressed)
				{
					Vector2 localMouse = _piecesLayer.GetLocalMousePosition();
					int clickX = Mathf.RoundToInt((localMouse.X - OFFSET_X) / CELL);
					int clickY = Mathf.RoundToInt((localMouse.Y - OFFSET_Y) / CELL);

					if (BoardState.IsInBounds(clickX, clickY))
					{
						// Check if we are clicking on a valid move
						if (_selectedPiece != null && _currentLegalMoves.Contains(new Vector2I(clickX, clickY)))
						{
							_ = ExecuteMoveAsync(_selectedPiece, clickX, clickY);
							ClearHighlights();
							_selectedPiece = null;
							_isDragging = false;
							return;
						}

						// Otherwise, try to select a piece
						Piece clicked = _board.GetPiece(clickX, clickY);
						if (clicked != null && clicked.Faction == Faction.Red) // Player is always Red
						{
							_selectedPiece = clicked;
							_isDragging = true;
							_originalPos = clicked.Visual.Position;
							
							// Offset to hold piece by its center when dragging
							_dragOffset = Vector2.Zero;
							ShowHighlights(_selectedPiece);
							
							// Bring to front
							clicked.Visual.MoveToFront();
						}
						else
						{
							ClearHighlights();
							_selectedPiece = null;
						}
					}
					else
					{
						ClearHighlights();
						_selectedPiece = null;
					}
				}
				else // Released
				{
					if (_isDragging && _selectedPiece != null)
					{
						_isDragging = false;
						Vector2 localMouse = _piecesLayer.GetLocalMousePosition();
						int dropX = Mathf.RoundToInt((localMouse.X - OFFSET_X) / CELL);
						int dropY = Mathf.RoundToInt((localMouse.Y - OFFSET_Y) / CELL);

						if (_currentLegalMoves.Contains(new Vector2I(dropX, dropY)))
						{
							_ = ExecuteMoveAsync(_selectedPiece, dropX, dropY);
						}
						else
						{
							// Snap back
							Tween t = CreateTween();
							t.TweenProperty(_selectedPiece.Visual, "position", _originalPos, 0.2f).SetTrans(Tween.TransitionType.Quad);
						}
						ClearHighlights();
					}
				}
			}
			else if (ev is InputEventMouseMotion mm && _isDragging && _selectedPiece != null)
			{
				_selectedPiece.Visual.Position = _piecesLayer.GetLocalMousePosition() - _dragOffset;
			}
		}

		private void ShowHighlights(Piece piece)
		{
			ClearHighlights();
			_currentLegalMoves = MoveValidator.GetLegalMoves(_board, piece);

			foreach (var move in _currentLegalMoves)
			{
				ColorRect dot = new ColorRect();
				dot.Color = new Color(0.2f, 0.8f, 0.2f, 0.6f);
				dot.Size = new Vector2(CELL / 3f, CELL / 3f);
				dot.Position = GetPixelCoord(move.X, move.Y) - dot.Size / 2f;
				// Make it roundish
				dot.MouseFilter = MouseFilterEnum.Ignore;
				_highlightLayer.AddChild(dot);
			}
		}

		private void ClearHighlights()
		{
			if (_highlightLayer == null) return;
			foreach (Node child in _highlightLayer.GetChildren()) child.QueueFree();
			_currentLegalMoves.Clear();
		}

		private string GetPositionHash(BoardState board)
		{
			var sb = new System.Text.StringBuilder(180);
			for (int y = 0; y < BoardState.ROWS; y++)
				for (int x = 0; x < BoardState.COLS; x++)
				{
					var p = board.GetPiece(x, y);
					if (p == null) sb.Append('.');
					else
					{
						char c = p.Type switch
						{
							PieceType.General  => 'K',
							PieceType.Advisor  => 'A',
							PieceType.Elephant => 'E',
							PieceType.Horse    => 'H',
							PieceType.Chariot  => 'R',
							PieceType.Cannon   => 'C',
							PieceType.Soldier  => 'S',
							_ => '?'
						};
						sb.Append(p.Faction == Faction.Red ? char.ToUpper(c) : char.ToLower(c));
					}
				}
			return sb.ToString();
		}

		private bool CheckThreefoldRepetition(Faction whoJustMoved)
		{
			string hash = GetPositionHash(_board);
			_positionHistory.Add(hash);
			int count = 0;
			foreach (var h in _positionHistory)
				if (h == hash) count++;

			if (count >= 3)
			{
				_timerRunning = false;
				_level.TriggerLose(); // Draw counts as not-winning
				if (_lblMessage != null) _lblMessage.Text = "Hoa co! The co lap lai 3 lan.";
				if (_victoryScreen != null) _victoryScreen.Visible = true;
				return true;
			}
			return false;
		}

		private async Task ExecuteMoveAsync(Piece mover, int toX, int toY)
		{
			_inputLocked = true;
			
			Piece captured = _board.MovePiece(mover.X, mover.Y, toX, toY);

			// Score for capturing
			if (captured != null && captured.Faction == Faction.Black)
			{
				_captureScore += CapturePoints.GetValueOrDefault(captured.Type, 0);
				if (_lblScore != null) _lblScore.Text = $"{_captureScore} diem";
			}

			if (captured != null)
			{
				if (_sfxCapture != null && !_sfxCapture.Playing) { _sfxCapture.PitchScale = (float)(_rng.NextDouble() * 0.2 + 0.9); _sfxCapture.Play(); }
			}
			else
			{
				if (_sfxMove != null) { _sfxMove.PitchScale = (float)(_rng.NextDouble() * 0.2 + 0.9); _sfxMove.Play(); }
			}

			Vector2 targetPos = GetPixelCoord(toX, toY);
			Tween t = CreateTween();
			t.TweenProperty(mover.Visual, "position", targetPos, 0.15f).SetTrans(Tween.TransitionType.Sine);
			await ToSignal(t, Tween.SignalName.Finished);

			if (captured != null && captured.Visual != null && IsInstanceValid(captured.Visual))
				captured.Visual.QueueFree();

			// Check threefold repetition (Red just moved)
			if (CheckThreefoldRepetition(Faction.Red))
			{
				if (_level.IsGameWon) ShowVictory();
				_inputLocked = false;
				return;
			}

			if (MoveValidator.HasNoLegalMoves(_board, Faction.Black))
			{
				_timerRunning = false;
				_level.TriggerWin();
				ShowVictory();
				_inputLocked = false;
				return;
			}

			await PlayBlackAIAsync();

			if (MoveValidator.HasNoLegalMoves(_board, Faction.Red))
			{
				_timerRunning = false;
				_level.TriggerLose();
				if (_lblMessage != null) _lblMessage.Text = MoveValidator.IsCheck(_board, Faction.Red) ? "Tuong cua ban da bi chieu bi!" : "Het nuoc di. Ban da thua!";
				if (_victoryScreen != null) _victoryScreen.Visible = true;
			}

			_inputLocked = false;
		}

		// ─── BLACK AI ───────────────────────────────────────────────────────────────
		private async Task PlayBlackAIAsync()
		{
			int aiLevel = _level.CurrentPuzzle?.AiLevel ?? 1;

			// Small delay to feel natural
			await ToSignal(GetTree().CreateTimer(0.4f), SceneTreeTimer.SignalName.Timeout);

			// Gather all legal Black moves
			var allMoves = new List<(Piece piece, Vector2I target)>();
			for (int x = 0; x < BoardState.COLS; x++)
			{
				for (int y = 0; y < BoardState.ROWS; y++)
				{
					var p = _board.GetPiece(x, y);
					if (p != null && p.Faction == Faction.Black)
					{
						var legal = MoveValidator.GetLegalMoves(_board, p);
						foreach (var m in legal) allMoves.Add((p, m));
					}
				}
			}

			if (allMoves.Count == 0) return; // Stalemate or already mated

			(Piece bestPiece, Vector2I bestTarget) = ChooseBestMove(allMoves, aiLevel);

			Piece cap = _board.MovePiece(bestPiece.X, bestPiece.Y, bestTarget.X, bestTarget.Y);

			if (cap != null)
			{
				if (_sfxCapture != null && !_sfxCapture.Playing) { _sfxCapture.PitchScale = (float)(_rng.NextDouble() * 0.2 + 0.9); _sfxCapture.Play(); }
			}
			else
			{
				if (_sfxMove != null) { _sfxMove.PitchScale = (float)(_rng.NextDouble() * 0.2 + 0.9); _sfxMove.Play(); }
			}

			Vector2 tp = GetPixelCoord(bestTarget.X, bestTarget.Y);
			Tween tw = CreateTween();
			tw.TweenProperty(bestPiece.Visual, "position", tp, 0.18f).SetTrans(Tween.TransitionType.Sine);
			await ToSignal(tw, Tween.SignalName.Finished);

			if (cap != null && cap.Visual != null && IsInstanceValid(cap.Visual))
				cap.Visual.QueueFree();

			// Check threefold repetition (Black just moved)
			if (CheckThreefoldRepetition(Faction.Black))
			{
				if (_level.IsGameWon) ShowVictory();
				return;
			}

			// Check if Red has no legal moves (stalemate or checkmate) -> Red loses
			if (MoveValidator.HasNoLegalMoves(_board, Faction.Red))
			{
				_level.TriggerLose();
				if (_lblMessage != null) _lblMessage.Text = MoveValidator.IsCheck(_board, Faction.Red) ? "Tuong cua ban da bi chieu bi!" : "Het nuoc di. Ban da thua!";
				if (_victoryScreen != null) _victoryScreen.Visible = true;
			}
		}

		private (Piece, Vector2I) ChooseBestMove(List<(Piece, Vector2I)> moves, int aiLevel)
		{
			// Easy (aiLevel 1-5): pure random
			if (aiLevel <= 5)
				return moves[_rng.Next(moves.Count)];

			// Medium (aiLevel 6-15): minimax depth 1
			if (aiLevel <= 15)
			{
				return MinimaxRoot(moves, 1);
			}

			// Hard (aiLevel 16-30): minimax depth 2
			if (aiLevel <= 30)
			{
				return MinimaxRoot(moves, 2);
			}

			// Expert (aiLevel 31+): minimax depth 3 with alpha-beta
			return MinimaxRoot(moves, 3);
		}

		private (Piece, Vector2I) MinimaxRoot(List<(Piece, Vector2I)> moves, int depth)
		{
			(Piece, Vector2I) bestMove = moves[0];
			int bestScore = int.MinValue;

			foreach (var (p, m) in moves)
			{
				var clone = _board.Clone();
				clone.MovePiece(p.X, p.Y, m.X, m.Y);
				int score = -AlphaBeta(clone, depth - 1, int.MinValue + 1, int.MaxValue - 1, Faction.Red);
				if (score > bestScore)
				{
					bestScore = score;
					bestMove = (p, m);
				}
			}
			return bestMove;
		}

		// NegaMax with alpha-beta pruning
		private int AlphaBeta(BoardState board, int depth, int alpha, int beta, Faction side)
		{
			// Check if enemy general is captured (instant win for the other side)
			Faction enemy = side == Faction.Red ? Faction.Black : Faction.Red;
			bool enemyHasGeneral = false;
			for (int x = 3; x <= 5; x++)
				for (int y = 0; y < BoardState.ROWS; y++)
				{
					var pp = board.GetPiece(x, y);
					if (pp != null && pp.Type == PieceType.General && pp.Faction == enemy)
						enemyHasGeneral = true;
				}
			if (!enemyHasGeneral) return 50000 + depth * 100; // Win!

			if (depth <= 0)
				return EvaluateBoard(board, side);

			var moves = new List<(int fx, int fy, int tx, int ty)>();
			for (int x = 0; x < BoardState.COLS; x++)
				for (int y = 0; y < BoardState.ROWS; y++)
				{
					var p = board.GetPiece(x, y);
					if (p != null && p.Faction == side)
					{
						var legal = MoveValidator.GetLegalMoves(board, p);
						foreach (var m in legal)
							moves.Add((x, y, m.X, m.Y));
					}
				}

			if (moves.Count == 0)
				return -50000 - depth * 100; // Lose (stalemate or checkmate)

			// Move ordering: prioritize captures for better pruning
			moves.Sort((a, b) =>
			{
				var ta = board.GetPiece(a.tx, a.ty);
				var tb = board.GetPiece(b.tx, b.ty);
				int va = ta != null ? PieceValues.GetValueOrDefault(ta.Type, 0) : 0;
				int vb = tb != null ? PieceValues.GetValueOrDefault(tb.Type, 0) : 0;
				return vb.CompareTo(va);
			});

			foreach (var (fx, fy, tx, ty) in moves)
			{
				var clone = board.Clone();
				clone.MovePiece(fx, fy, tx, ty);
				int score = -AlphaBeta(clone, depth - 1, -beta, -alpha, enemy);
				if (score >= beta) return beta; // Beta cutoff
				if (score > alpha) alpha = score;
			}
			return alpha;
		}

		// Piece base values
		private static readonly Dictionary<PieceType, int> PieceValues = new()
		{
			{ PieceType.General,  10000 },
			{ PieceType.Chariot,  900 },
			{ PieceType.Cannon,   450 },
			{ PieceType.Horse,    400 },
			{ PieceType.Elephant, 200 },
			{ PieceType.Advisor,  200 },
			{ PieceType.Soldier,  100 },
		};

		private static int EvaluateBoard(BoardState board, Faction faction)
		{
			Faction enemy = faction == Faction.Red ? Faction.Black : Faction.Red;
			int score = 0;

			for (int x = 0; x < BoardState.COLS; x++)
				for (int y = 0; y < BoardState.ROWS; y++)
				{
					var p = board.GetPiece(x, y);
					if (p == null) continue;
					int v = PieceValues.GetValueOrDefault(p.Type, 0);

					// Positional bonuses
					v += GetPositionalBonus(p);

					score += p.Faction == faction ? v : -v;
				}

			// Mobility bonus: more legal moves = better position
			int myMobility = 0, enemyMobility = 0;
			for (int x = 0; x < BoardState.COLS; x++)
				for (int y = 0; y < BoardState.ROWS; y++)
				{
					var p = board.GetPiece(x, y);
					if (p == null) continue;
					int moveCount = MoveValidator.GetPseudoLegalMoves(board, p).Count;
					if (p.Faction == faction) myMobility += moveCount;
					else enemyMobility += moveCount;
				}
			score += (myMobility - enemyMobility) * 3;

			// Check bonus
			if (MoveValidator.IsCheck(board, enemy)) score += 80;

			return score;
		}

		private static int GetPositionalBonus(Piece p)
		{
			switch (p.Type)
			{
				case PieceType.Soldier:
					// Soldiers are much more valuable after crossing the river
					if (BoardState.HasCrossedRiver(p.Y, p.Faction)) return 80;
					// reward advancing
					int distFromStart = p.Faction == Faction.Red ? 9 - p.Y : p.Y;
					return distFromStart * 5;

				case PieceType.Horse:
					// Center control bonus
					int cx = Math.Abs(p.X - 4);
					return (4 - cx) * 10;

				case PieceType.Chariot:
					// Rooks on open files / advanced position
					int advanceR = p.Faction == Faction.Red ? 9 - p.Y : p.Y;
					return advanceR * 5;

				case PieceType.Cannon:
					// Cannons slightly prefer staying back with screens
					return 0;

				case PieceType.Advisor:
				case PieceType.Elephant:
					// Defensive pieces: bonus for being in defensive formation
					return 10;

				default:
					return 0;
			}
		}

		private void ShowVictory()
		{
			_timerRunning = false;
			int stars = CalculateStars();
			int timeBonus = (int)(_timeRemaining * 2f);
			int totalScore = _captureScore + timeBonus;
			string starStr = new string('*', stars);
			for (int i = stars; i < 3; i++) starStr += "-";

			if (_victoryScreen != null) _victoryScreen.Visible = true;
			if (_lblMessage != null)
				_lblMessage.Text = $"Chien thang! {starStr}\nDiem: {totalScore} (An quan: {_captureScore} + Thoi gian: {timeBonus})";

			EmitSignal(SignalName.MiniGameWon, _level.CurrentLevelIndex, _level.GetRewardForCurrentLevel(), stars);
		}

		private void OnNextLevelPressed()
		{
			// Load next puzzle
			_level = new XiangqiLevelManager(_level.CurrentLevelIndex + 1);
			LoadLevel();
		}

		private void OnClosePressed()
		{
			EmitSignal(SignalName.MiniGameClosed);
			QueueFree();
		}
	}
}
