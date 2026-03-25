using Godot;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

// ============================================================
// CandyBoard.cs  — Full Match-3 with Special Items & Combos
// ============================================================
// Special item rules:
//   Match-4 horizontal → spawns LineBlastV at swap pos (clears COLUMN)
//   Match-4 vertical   → spawns LineBlastH at swap pos (clears ROW)
//   Match-5            → spawns ColorBomb at swap pos
//
// Combos (special+special swap):
//   LineBlast+LineBlast → CrossBlast (row + col)
//   ColorBomb+any       → destroy all of adjacent color (no match needed)
// ============================================================

public partial class CandyBoard : Control
{
	// ── Exports ───────────────────────────────────────────────
	[Export] public NodePath LblScorePath;
	[Export] public NodePath LblTargetPath;
	[Export] public NodePath LblMovesPath;
	[Export] public NodePath BoardContainerPath;
	[Export] public NodePath VictoryScreenPath;
	[Export] public NodePath LoseScreenPath;
	[Export] public NodePath LblVictoryStarsPath;
	[Export] public NodePath LblVictoryRewardPath;
	[Export] public NodePath BtnClosePath;
	[Export] public int StartLevel = 1;

	// ── Signals ──────────────────────────────────────────────
	[Signal] public delegate void MiniGameWonEventHandler(int levelIndex, int rewardAmount);
	[Signal] public delegate void MinigameClosedEventHandler();

	// ── Constants ────────────────────────────────────────────
	private const int COLS = 8;
	private const int ROWS = 8;
	private const int CELL = 60;

	private const float TWEEN_SWAP = 0.18f;
	private const float TWEEN_FALL = 0.22f;
	private const float TWEEN_POP  = 0.12f;

	// ── State ─────────────────────────────────────────────────
	private CandyItem[,]     _grid;
	private CandyLevelManager _level;
	private bool _inputLocked;
	private bool _isDragging;
	private CandyItem _selectedItem;
	private Vector2   _dragStart;

	// Chain-reaction guard: items already queued for destruction
	private HashSet<CandyItem> _destroying = new HashSet<CandyItem>();

	// UI refs
	private Label   _lblScore, _lblTarget, _lblMoves;
	private Control _boardContainer, _victoryScreen, _loseScreen;
	private Label   _lblVictoryStars, _lblVictoryReward;
	private Button  _btnClose;

	private AudioStreamPlayer _sfxSwap;
	private AudioStreamPlayer _sfxPop;
	private AudioStreamPlayer _bgmPlayer;

	private Random _rng = new Random();

	// ── Hints & Shuffle ───────────────────────────────────────
	private double _idleTime = 0;
	private const double HINT_DELAY = 5.0; // Seconds before showing a hint
	private bool _hintActive = false;

	// ─────────────────────────────────────────────────────────
	// GODOT ENTRY
	// ─────────────────────────────────────────────────────────
	public override void _Ready()
	{
		_lblScore         = GetNode<Label>(LblScorePath);
		_lblTarget        = GetNode<Label>(LblTargetPath);
		_lblMoves         = GetNode<Label>(LblMovesPath);
		_boardContainer   = GetNode<Control>(BoardContainerPath);
		_victoryScreen    = GetNode<Control>(VictoryScreenPath);
		_loseScreen       = GetNode<Control>(LoseScreenPath);
		_lblVictoryStars  = GetNode<Label>(LblVictoryStarsPath);
		_lblVictoryReward = GetNode<Label>(LblVictoryRewardPath);

		_sfxSwap = new AudioStreamPlayer();
		_sfxSwap.Stream = GD.Load<AudioStream>("res://assets/Music/text_boop.mp3");
		_sfxSwap.Bus = "SFX";
		AddChild(_sfxSwap);

		_sfxPop = new AudioStreamPlayer();
		_sfxPop.Stream = GD.Load<AudioStream>("res://assets/Music/Purchase_SFX.mp3");
		_sfxPop.Bus = "SFX";
		AddChild(_sfxPop);

		_bgmPlayer = new AudioStreamPlayer();
		_bgmPlayer.Stream = GD.Load<AudioStream>("res://assets/Music/Sugar Puzzle Carousel.mp3");
		_bgmPlayer.Bus = "Music";
		AddChild(_bgmPlayer);
		_bgmPlayer.Play();

		if (_victoryScreen != null) _victoryScreen.Visible = false;
		if (_loseScreen    != null) _loseScreen.Visible    = false;

		// Close / nav buttons
		WireButton(BtnClosePath.IsEmpty ? null : GetNodeOrNull<Button>(BtnClosePath),           OnClosePressed);
		WireButton(GetNodeOrNull<Button>("Overlay/Window/VBox/BtnClose2"),                      OnClosePressed);
		WireButton(GetNodeOrNull<Button>("Overlay/VictoryScreen/VBox/BtnRow/BtnNextLevel"),     OnNextLevelPressed);
		WireButton(GetNodeOrNull<Button>("Overlay/VictoryScreen/VBox/BtnRow/BtnExitWin"),       OnClosePressed);
		WireButton(GetNodeOrNull<Button>("Overlay/LoseScreen/VBox/LoseBtnRow/BtnRetry"),        OnRetryPressed);
		WireButton(GetNodeOrNull<Button>("Overlay/LoseScreen/VBox/LoseBtnRow/BtnExitLose"),     OnClosePressed);

		_level = new CandyLevelManager(StartLevel);
		InitBoard();
		UpdateUI();
		
		SetProcess(true);
		CheckNoMoves();
	}

	private void WireButton(Button btn, Action handler)
	{
		if (btn != null) btn.Pressed += handler;
	}

	// ─────────────────────────────────────────────────────────
	// BOARD INIT
	// ─────────────────────────────────────────────────────────
	private void InitBoard()
	{
		_grid = new CandyItem[COLS, ROWS];
		_destroying.Clear();
		for (int r = 0; r < ROWS; r++)
			for (int c = 0; c < COLS; c++)
				SpawnItem(c, r, PickTypeNoMatch(c, r), SpecialType.None, spawnFromTop: false);
	}

	private CandyType PickTypeNoMatch(int col, int row)
	{
		var forbidden = new HashSet<CandyType>();
		if (col >= 2 && _grid[col-1,row]?.Type == _grid[col-2,row]?.Type && _grid[col-1,row] != null)
			forbidden.Add(_grid[col-1,row].Type);
		if (row >= 2 && _grid[col,row-1]?.Type == _grid[col,row-2]?.Type && _grid[col,row-1] != null)
			forbidden.Add(_grid[col,row-1].Type);

		CandyType chosen; int tries = 0;
		do { chosen = (CandyType)_rng.Next(0, (int)CandyType.COUNT); }
		while (forbidden.Contains(chosen) && ++tries < 20);
		return chosen;
	}

	// ─────────────────────────────────────────────────────────
	// SPAWN ITEM
	// ─────────────────────────────────────────────────────────
	private CandyItem SpawnItem(int col, int row, CandyType type, SpecialType special, bool spawnFromTop)
	{
		var item = new CandyItem(type, col, row, special);

		float sz = CELL - 4f;
		Panel panel = new Panel();
		panel.Size            = new Vector2(sz, sz);
		panel.CustomMinimumSize = new Vector2(sz, sz);
		panel.Position = spawnFromTop
			? new Vector2(col * CELL + 2, -CELL)
			: new Vector2(col * CELL + 2, row * CELL + 2);

		StyleBoxFlat style = new StyleBoxFlat();
		style.BgColor = special == SpecialType.ColorBomb
			? new Color(0.15f, 0.15f, 0.15f)
			: item.GetColor();
		style.CornerRadiusTopLeft = style.CornerRadiusTopRight =
		style.CornerRadiusBottomLeft = style.CornerRadiusBottomRight = 12;
		style.BorderColor = item.GetBorderColor();
		style.BorderWidthLeft = style.BorderWidthTop =
		style.BorderWidthRight = style.BorderWidthBottom = special != SpecialType.None ? 5 : 3;
		panel.AddThemeStyleboxOverride("panel", style);

		Label lbl = new Label();
		lbl.Text = item.GetSymbol();
		lbl.HorizontalAlignment = HorizontalAlignment.Center;
		lbl.VerticalAlignment   = VerticalAlignment.Center;
		lbl.AddThemeFontSizeOverride("font_size", special == SpecialType.ColorBomb ? 26 : 28);
		lbl.AddThemeColorOverride("font_color",
			special != SpecialType.None ? new Color(1,1,1,1) : new Color(1,1,1,0.9f));
		lbl.SetAnchorsPreset(Control.LayoutPreset.FullRect);
		panel.AddChild(lbl);

		_boardContainer.AddChild(panel);
		item.Visual = panel;
		_grid[col, row] = item;

		if (spawnFromTop)
		{
			Tween t = panel.CreateTween();
			t.TweenProperty(panel, "position:y", row * CELL + 2, TWEEN_FALL)
			 .SetTrans(Tween.TransitionType.Quad).SetEase(Tween.EaseType.Out);
		}
		return item;
	}

	// ─────────────────────────────────────────────────────────
	// INPUT
	// ─────────────────────────────────────────────────────────
	public override void _Input(InputEvent ev)
	{
		if (_inputLocked) return;
		_idleTime = 0; StopHint();

		if (ev is InputEventMouseButton mb && mb.ButtonIndex == MouseButton.Left)
		{
			if (mb.Pressed)
			{
				_selectedItem = GetItemAtBoard();
				_isDragging   = _selectedItem != null;
				_dragStart    = mb.GlobalPosition;
			}
			else _isDragging = false;
		}
		else if (ev is InputEventMouseMotion mm && _isDragging && _selectedItem != null)
		{
			Vector2 delta = mm.GlobalPosition - _dragStart;
			if (delta.Length() > 25f)
			{
				int dc = 0, dr = 0;
				if (Mathf.Abs(delta.X) > Mathf.Abs(delta.Y)) dc = delta.X > 0 ? 1 : -1;
				else                                           dr = delta.Y > 0 ? 1 : -1;

				int nc = _selectedItem.Col + dc;
				int nr = _selectedItem.Row + dr;
				if (IsInBounds(nc, nr))
					_ = TrySwapAsync(_selectedItem, _grid[nc, nr]);

				_isDragging = false; _selectedItem = null;
			}
		}
	}

	private CandyItem GetItemAtBoard()
	{
		Vector2 local = _boardContainer.GetLocalMousePosition();
		int col = Mathf.Clamp((int)(local.X / CELL), 0, COLS - 1);
		int row = Mathf.Clamp((int)(local.Y / CELL), 0, ROWS - 1);
		// Verify the click is genuinely within the board area
		if (local.X < 0 || local.Y < 0 || local.X >= COLS * CELL || local.Y >= ROWS * CELL)
			return null;
		return _grid[col, row];
	}

	// ─────────────────────────────────────────────────────────
	// SWAP ENTRY
	// ─────────────────────────────────────────────────────────
	private async Task TrySwapAsync(CandyItem a, CandyItem b)
	{
		_inputLocked = true;
		_destroying.Clear();

		await AnimateSwap(a, b);
		DoGridSwap(a, b);

		bool handled = await CheckSpecialComboAsync(a, b);

		if (!handled)
		{
			// Build match groups from this swap
			var (toDestroy, specials) = FindMatchGroupsForSwap(a, b);

			if (toDestroy.Count > 0)
			{
				_level.UseMove();
				UpdateUI();

				// Spawn special items if applicable
				foreach (var si in specials)
					ReplaceWithSpecial(si.Col, si.Row, si.Special, si.BaseType);

				await DestroyAndRefillAsync(toDestroy);
			}
			else
			{
				// Invalid — snap back
				await AnimateSwap(a, b);
				DoGridSwap(a, b);
			}
		}

		_inputLocked = false;
		CheckGameState();
	}

	// ─────────────────────────────────────────────────────────
	// SPECIAL COMBO DETECTION
	// ─────────────────────────────────────────────────────────
	// ─────────────────────────────────────────────────────────
	/// Handles all swaps involving at least one special item.
	/// Returns true if a special activation was triggered (skip normal match flow).
	private async Task<bool> CheckSpecialComboAsync(CandyItem a, CandyItem b)
	{
		bool aSpec = a.IsSpecial, bSpec = b.IsSpecial;
		if (!aSpec && !bSpec) return false;

		// 1. ColorBomb combos
		if (a.Special == SpecialType.ColorBomb || b.Special == SpecialType.ColorBomb)
		{
			if (a.Special == SpecialType.ColorBomb && b.Special == SpecialType.ColorBomb)
			{
				// ColorBomb + ColorBomb = Clear whole board
				var all = new HashSet<CandyItem>();
				for (int r = 0; r < ROWS; r++)
					for (int c = 0; c < COLS; c++)
						if (_grid[c, r] != null) all.Add(_grid[c, r]);
				_level.UseMove(); UpdateUI();
				await DestroyAndRefillAsync(all);
				return true;
			}

			var bomb   = a.Special == SpecialType.ColorBomb ? a : b;
			var other  = bomb == a ? b : a;
			var toKill = new HashSet<CandyItem>();
			
			// Find all candies of 'other' type
			var targetCandies = new List<CandyItem>();
			for (int r = 0; r < ROWS; r++)
				for (int c = 0; c < COLS; c++)
					if (_grid[c,r] != null && _grid[c,r].Type == other.Type)
						targetCandies.Add(_grid[c,r]);

			// If other is NOT a normal candy, we transform all targets into that special type!
			if (other.IsSpecial)
			{
				foreach (var candy in targetCandies)
				{
					// For LineBlasts, alternate between H and V
					if (other.Special == SpecialType.LineBlastH || other.Special == SpecialType.LineBlastV) {
						ReplaceWithSpecial(candy.Col, candy.Row, _rng.Next(0, 2) == 0 ? SpecialType.LineBlastH : SpecialType.LineBlastV, candy.Type);
					}
					else {
						ReplaceWithSpecial(candy.Col, candy.Row, other.Special, candy.Type);
					}
				}
				
				// Wait for the transformation effect
				await ToSignal(GetTree().CreateTimer(0.5f), SceneTreeTimer.SignalName.Timeout);
				
				// Now trigger the explosion cascade!
				foreach (var candy in targetCandies)
				{
					if (_grid[candy.Col, candy.Row] != null) // It was replaced by a new instance
						toKill.Add(_grid[candy.Col, candy.Row]);
				}
			}
			else
			{
				// Normal candy color clear
				toKill.UnionWith(targetCandies);
			}

			toKill.Add(bomb);
			// Only add `other` if it wasn't already destroyed and replaced in the loop!
			if (!targetCandies.Contains(other)) 
			{
				var currentAtOther = _grid[other.Col, other.Row];
				toKill.Add(currentAtOther ?? other);
			}
			
			_level.UseMove(); UpdateUI();
			
			// Expand toKill by activating the newly placed specials (or the single special)
			var chained = new HashSet<CandyItem>();
			foreach(var k in toKill) {
				if (k.IsSpecial) chained.UnionWith(ActivateSpecial(k));
			}
			toKill.UnionWith(chained);
			
			await DestroyAndRefillAsync(toKill);
			return true;
		}

		// 2. Bomb + Bomb → 5x5 explosion
		if (a.Special == SpecialType.Bomb && b.Special == SpecialType.Bomb)
		{
			var toKill = new HashSet<CandyItem>();
			for (int r = a.Row - 2; r <= a.Row + 2; r++)
				for (int c = a.Col - 2; c <= a.Col + 2; c++)
					if (IsInBounds(c, r) && _grid[c, r] != null) toKill.Add(_grid[c, r]);
			_level.UseMove(); UpdateUI();
			await DestroyAndRefillAsync(toKill);
			return true;
		}

		// 3. Bomb + LineBlast → 3-wide cross
		bool isBombAndLine = (a.Special == SpecialType.Bomb && (b.Special == SpecialType.LineBlastH || b.Special == SpecialType.LineBlastV)) ||
							 (b.Special == SpecialType.Bomb && (a.Special == SpecialType.LineBlastH || a.Special == SpecialType.LineBlastV));
		if (isBombAndLine)
		{
			var toKill = new HashSet<CandyItem>();
			var bomb = a.Special == SpecialType.Bomb ? a : b;
			// 3 rows
			for (int r = bomb.Row - 1; r <= bomb.Row + 1; r++) toKill.UnionWith(CollectRow(r));
			// 3 columns
			for (int c = bomb.Col - 1; c <= bomb.Col + 1; c++) toKill.UnionWith(CollectCol(c));
			_level.UseMove(); UpdateUI();
			await DestroyAndRefillAsync(toKill);
			return true;
		}

		// 4. LineBlast + LineBlast → CrossBlast (1 row + 1 column)
		if ((a.Special == SpecialType.LineBlastH || a.Special == SpecialType.LineBlastV) &&
			(b.Special == SpecialType.LineBlastH || b.Special == SpecialType.LineBlastV))
		{
			int pivotCol = a.Col, pivotRow = a.Row;
			var toKill = CollectRow(pivotRow);
			toKill.UnionWith(CollectCol(pivotCol));
			toKill.Add(a); toKill.Add(b);
			_level.UseMove(); UpdateUI();
			await DestroyAndRefillAsync(toKill);
			return true;
		}

		// 5. Special + normal item → activate special immediately (no match-3 required)
		// The special activates at its current swapped position.
		_destroying.Clear();
		var toKillImmediate = new HashSet<CandyItem> { a, b };
		toKillImmediate.UnionWith(ActivateSpecial(a.IsSpecial ? a : b));
		_level.UseMove(); UpdateUI();
		await DestroyAndRefillAsync(toKillImmediate);
		return true;
	}

	// ─────────────────────────────────────────────────────────
	// MATCH DETECTION
	// ─────────────────────────────────────────────────────────
	private struct SpawnInfo
	{
		public int Col; public int Row;
		public SpecialType Special; public CandyType BaseType;
		public SpawnInfo(int c, int r, SpecialType s, CandyType t) { Col=c; Row=r; Special=s; BaseType=t; }
	}

	/// Find all matches; LineBlast specials participate in runs by base Type.
	/// swapA / swapB = player swap positions (for special spawn priority).
	private (HashSet<CandyItem>, List<SpawnInfo>) FindMatchGroupsForSwap(CandyItem swapA, CandyItem swapB)
	{
		var toDestroy = new HashSet<CandyItem>();
		var specials  = new List<SpawnInfo>();

		// Collect horizontal and vertical runs of 3+ simultaneously to detect intersections (L/T shapes).
		var hRuns = new List<List<CandyItem>>();
		var vRuns = new List<List<CandyItem>>();

		bool Scannable(int c, int r) =>
			IsInBounds(c, r) && _grid[c, r] != null &&
			_grid[c, r].Special != SpecialType.ColorBomb;

		bool SameRun(CandyType t, int c, int r) =>
			Scannable(c, r) && _grid[c, r].Type == t;

		// ── Horizontal scans ──
		for (int r = 0; r < ROWS; r++)
		{
			int c = 0;
			while (c < COLS)
			{
				if (!Scannable(c, r)) { c++; continue; }
				var anchor = _grid[c, r];
				int run = 1;
				while (SameRun(anchor.Type, c + run, r)) run++;

				if (run >= 3)
				{
					var runItems = new List<CandyItem>();
					for (int k = 0; k < run; k++) runItems.Add(_grid[c + k, r]);
					hRuns.Add(runItems);
				}
				c += run;
			}
		}

		// ── Vertical scans ──
		for (int col = 0; col < COLS; col++)
		{
			int r = 0;
			while (r < ROWS)
			{
				if (!Scannable(col, r)) { r++; continue; }
				var anchor = _grid[col, r];
				int run = 1;
				while (SameRun(anchor.Type, col, r + run)) run++;

				if (run >= 3)
				{
					var runItems = new List<CandyItem>();
					for (int k = 0; k < run; k++) runItems.Add(_grid[col, r + k]);
					vRuns.Add(runItems);
				}
				r += run;
			}
		}

		// ── Process runs and detect shapes ──
		var handledInIntersection = new HashSet<CandyItem>();

		void ProcessLine(List<CandyItem> runItems)
		{
			if (runItems.Count >= 5)
			{
				CandyItem sw = InRun(swapA, runItems) ? swapA : InRun(swapB, runItems) ? swapB : runItems[runItems.Count / 2];
				specials.Add(new SpawnInfo(sw.Col, sw.Row, SpecialType.ColorBomb, runItems[0].Type));
				runItems.RemoveAll(x => x == sw);
				handledInIntersection.UnionWith(runItems);
			}
		}
		foreach (var h in hRuns) ProcessLine(h);
		foreach (var v in vRuns) ProcessLine(v);

		// 2. Check for Intersections (L or T shapes) — match-3 horizontal AND match-3 vertical sharing an item
		foreach (var h in hRuns)
		{
			if (h.Count >= 5 || handledInIntersection.Contains(h[0])) continue;
			foreach (var v in vRuns)
			{
				if (v.Count >= 5 || handledInIntersection.Contains(v[0])) continue;

				// Find intersection (an item present in both h and v)
				CandyItem intersection = null;
				foreach (var item in h)
				{
					if (v.Contains(item)) { intersection = item; break; }
				}

				if (intersection != null)
				{
					// We have an L or T shape -> Wrapped Candy (Bomb)
					CandyItem sw = InRun(swapA, h) || InRun(swapA, v) ? swapA :
								  InRun(swapB, h) || InRun(swapB, v) ? swapB : intersection;
					
					// Wait, if sw isn't the intersection and was already used in an L shape, use intersection
					if (handledInIntersection.Contains(sw)) sw = intersection;

					specials.Add(new SpawnInfo(sw.Col, sw.Row, SpecialType.Bomb, intersection.Type));
					
					List<CandyItem> toRemove = new List<CandyItem> { sw };
					v.RemoveAll(x => toRemove.Contains(x));
					h.RemoveAll(x => toRemove.Contains(x));

					handledInIntersection.UnionWith(h);
					handledInIntersection.UnionWith(v);
					break; // An h-run can only intersect once to form one bomb
				}
			}
		}

		// 3. Process remaining 4-in-a-row (LineBlast)
		foreach (var h in hRuns)
		{
			if (h.Count == 4 && !h.Exists(x => handledInIntersection.Contains(x)) && !h.Exists(x => x.IsSpecial))
			{
				CandyItem sw = InRun(swapA, h) ? swapA : InRun(swapB, h) ? swapB : h[h.Count / 2];
				specials.Add(new SpawnInfo(sw.Col, sw.Row, SpecialType.LineBlastV, h[0].Type));
				h.RemoveAll(x => x == sw);
			}
		}
		foreach (var v in vRuns)
		{
			if (v.Count == 4 && !v.Exists(x => handledInIntersection.Contains(x)) && !v.Exists(x => x.IsSpecial))
			{
				CandyItem sw = InRun(swapA, v) ? swapA : InRun(swapB, v) ? swapB : v[v.Count / 2];
				specials.Add(new SpawnInfo(sw.Col, sw.Row, SpecialType.LineBlastH, v[0].Type));
				v.RemoveAll(x => x == sw);
			}
		}

		// 4. Add all items from all runs to toDestroy
		foreach (var h in hRuns)
		{
			foreach (var it in h)
			{
				toDestroy.Add(it);
				if (it.IsSpecial) toDestroy.UnionWith(ActivateSpecial(it));
			}
		}
		foreach (var v in vRuns)
		{
			foreach (var it in v)
			{
				toDestroy.Add(it);
				if (it.IsSpecial) toDestroy.UnionWith(ActivateSpecial(it));
			}
		}

		return (toDestroy, specials);
	}

	// ─────────────────────────────────────────────────────────
	// SPECIAL ITEM ACTIVATION (returns extra items to destroy)
	// ─────────────────────────────────────────────────────────
	// ─────────────────────────────────────────────────────────
	// SPECIAL ITEM ACTIVATION (returns extra items to destroy)
	// ─────────────────────────────────────────────────────────
	private HashSet<CandyItem> ActivateSpecial(CandyItem item)
	{
		if (_destroying.Contains(item)) return new HashSet<CandyItem>();
		_destroying.Add(item);

		var extra = new HashSet<CandyItem>();
		switch (item.Special)
		{
			case SpecialType.LineBlastH:
				extra.UnionWith(CollectRow(item.Row));
				break;
			case SpecialType.LineBlastV:
				extra.UnionWith(CollectCol(item.Col));
				break;
			case SpecialType.Bomb:
				// Clear 3x3 area
				for (int r = item.Row - 1; r <= item.Row + 1; r++)
				{
					for (int c = item.Col - 1; c <= item.Col + 1; c++)
					{
						if (IsInBounds(c, r) && _grid[c, r] != null) extra.Add(_grid[c, r]);
					}
				}
				break;
		}

		// Chain reaction
		var chained = new HashSet<CandyItem>();
		foreach (var e in extra)
		{
			if (e != item && e.IsSpecial && !_destroying.Contains(e))
			{
				chained.UnionWith(ActivateSpecial(e));
			}
		}
		extra.UnionWith(chained);
		return extra;
	}

	private HashSet<CandyItem> CollectRow(int row)
	{
		var set = new HashSet<CandyItem>();
		for (int c = 0; c < COLS; c++)
			if (_grid[c, row] != null) set.Add(_grid[c, row]);
		return set;
	}

	private HashSet<CandyItem> CollectCol(int col)
	{
		var set = new HashSet<CandyItem>();
		for (int r = 0; r < ROWS; r++)
			if (_grid[col, r] != null) set.Add(_grid[col, r]);
		return set;
	}

	private bool InRun(CandyItem item, List<CandyItem> run) => run.Contains(item);

	// ─────────────────────────────────────────────────────────
	// REPLACE WITH SPECIAL (keep same visual slot, change appearance)
	// ─────────────────────────────────────────────────────────
	private void ReplaceWithSpecial(int col, int row, SpecialType special, CandyType baseType)
	{
		var existing = _grid[col, row];
		if (existing != null && existing.Visual != null && IsInstanceValid(existing.Visual))
			existing.Visual.QueueFree();

		SpawnItem(col, row, baseType, special, spawnFromTop: false);

		// Animate a quick "birth" pop
		var vis = _grid[col, row].Visual;
		if (vis != null)
		{
			vis.Scale = Vector2.Zero;
			Tween t = vis.CreateTween();
			t.TweenProperty(vis, "scale", new Vector2(1.15f, 1.15f), 0.12f)
			 .SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.Out);
			t.TweenProperty(vis, "scale", Vector2.One, 0.08f)
			 .SetTrans(Tween.TransitionType.Quad).SetEase(Tween.EaseType.In);
		}
	}

	// ─────────────────────────────────────────────────────────
	// CASCADE RESOLVE
	// ─────────────────────────────────────────────────────────
	private async Task DestroyAndRefillAsync(HashSet<CandyItem> toDestroy)
	{
		while (toDestroy.Count > 0)
		{
			int pts = toDestroy.Count * 50;
			_level.AddScore(pts);
			
			// Cộng Boost Energy cho Fever Mode (mỗi viên nổ tính 1.0 energy)
			Node gameManager = GetNode("/root/GameManager");
			gameManager.Call("add_boost_energy", (float)toDestroy.Count * 1.0f);
			
			UpdateUI();

			foreach (var item in toDestroy)
			{
				SpawnParticleBurst(item);
				_ = PopAndRemove(item);
			}
			await ToSignal(GetTree().CreateTimer(TWEEN_POP + 0.05f), SceneTreeTimer.SignalName.Timeout);

			FillGaps();
			await ToSignal(GetTree().CreateTimer(TWEEN_FALL + 0.08f), SceneTreeTimer.SignalName.Timeout);

			// Cascade: find new matches from gravity
			_destroying.Clear();
			var (cascade, newSpecials) = FindCascadeMatches();
			foreach (var si in newSpecials)
				ReplaceWithSpecial(si.Col, si.Row, si.Special, si.BaseType);
			toDestroy = cascade;
		}
	}

	/// Find matches after a refill (no swap position — spawn specials at run centre)
	private (HashSet<CandyItem>, List<SpawnInfo>) FindCascadeMatches()
	{
		var dummy = new CandyItem(CandyType.Red, -1, -1);
		return FindMatchGroupsForSwap(dummy, dummy);
	}

	// ─────────────────────────────────────────────────────────
	// SWAP ANIMATION & GRID
	// ─────────────────────────────────────────────────────────
	private async Task AnimateSwap(CandyItem a, CandyItem b)
	{
		if (_sfxSwap != null) { _sfxSwap.PitchScale = (float)(_rng.NextDouble() * 0.2 + 0.9); _sfxSwap.Play(); }
		Vector2 posA = a.Visual.Position, posB = b.Visual.Position;
		Tween tA = a.Visual.CreateTween();
		Tween tB = b.Visual.CreateTween();
		tA.TweenProperty(a.Visual, "position", posB, TWEEN_SWAP)
		  .SetTrans(Tween.TransitionType.Quad).SetEase(Tween.EaseType.InOut);
		tB.TweenProperty(b.Visual, "position", posA, TWEEN_SWAP)
		  .SetTrans(Tween.TransitionType.Quad).SetEase(Tween.EaseType.InOut);
		await ToSignal(tA, Tween.SignalName.Finished);
	}

	private void DoGridSwap(CandyItem a, CandyItem b)
	{
		_grid[a.Col, a.Row] = b;
		_grid[b.Col, b.Row] = a;
		(a.Col, b.Col) = (b.Col, a.Col);
		(a.Row, b.Row) = (b.Row, a.Row);
	}

	// ─────────────────────────────────────────────────────────
	// POP & REMOVE
	// ─────────────────────────────────────────────────────────
	private async Task PopAndRemove(CandyItem item)
	{
		if (_grid[item.Col, item.Row] == item) _grid[item.Col, item.Row] = null;
		var vis = item.Visual; item.Visual = null;
		if (vis == null || !IsInstanceValid(vis)) return;

		if (_sfxPop != null && !_sfxPop.Playing) { _sfxPop.PitchScale = (float)(_rng.NextDouble() * 0.2 + 0.9); _sfxPop.Play(); }

		Tween t = vis.CreateTween();
		t.TweenProperty(vis, "scale", new Vector2(1.3f, 1.3f), TWEEN_POP * 0.4f)
		 .SetTrans(Tween.TransitionType.Quad).SetEase(Tween.EaseType.Out);
		t.TweenProperty(vis, "scale", Vector2.Zero, TWEEN_POP * 0.6f)
		 .SetTrans(Tween.TransitionType.Quad).SetEase(Tween.EaseType.In);
		await ToSignal(t, Tween.SignalName.Finished);
		vis.QueueFree();
	}

	// ─────────────────────────────────────────────────────────
	// GRAVITY / FILL GAPS
	// ─────────────────────────────────────────────────────────
	private void FillGaps()
	{
		for (int c = 0; c < COLS; c++)
		{
			int empty = ROWS - 1;
			for (int r = ROWS - 1; r >= 0; r--)
			{
				if (_grid[c, r] != null)
				{
					if (r != empty)
					{
						_grid[c, empty] = _grid[c, r];
						_grid[c, r]     = null;
						_grid[c, empty].Row = empty;
						Tween t = _grid[c, empty].Visual.CreateTween();
						t.TweenProperty(_grid[c, empty].Visual, "position:y", empty * CELL + 2, TWEEN_FALL)
						 .SetTrans(Tween.TransitionType.Quad).SetEase(Tween.EaseType.Out);
					}
					empty--;
				}
			}
			for (int r = empty; r >= 0; r--)
				SpawnItem(c, r, (CandyType)_rng.Next(0, (int)CandyType.COUNT), SpecialType.None, spawnFromTop: true);
		}
	}

	// ─────────────────────────────────────────────────────────
	// PARTICLES
	// ─────────────────────────────────────────────────────────
	private void SpawnParticleBurst(CandyItem item)
	{
		CpuParticles2D burst = new CpuParticles2D();
		burst.OneShot = true; burst.Emitting = false;
		burst.Amount  = item.IsSpecial ? 28 : 16;
		burst.Lifetime = 0.55f; burst.Explosiveness = 0.92f;
		burst.Spread = 180f; burst.Gravity = new Vector2(0, 350f);
		burst.InitialVelocityMin = 80f; burst.InitialVelocityMax = 220f;
		burst.ScaleAmountMin = 3f; burst.ScaleAmountMax = 8f;
		burst.Color  = item.Special == SpecialType.ColorBomb ? new Color(1,1,0.3f) : item.GetColor();
		burst.Direction = Vector2.Zero;
		
		Vector2 pos = new Vector2(item.Col * CELL + 2 + CELL / 2f, item.Row * CELL + 2 + CELL / 2f);
		if (item.Visual != null && IsInstanceValid(item.Visual))
			pos = item.Visual.Position + new Vector2(CELL / 2f, CELL / 2f);
			
		burst.Position  = pos;
		_boardContainer.AddChild(burst);
		burst.Emitting = true;
		GetTree().CreateTimer(1f).Timeout += () => { if (IsInstanceValid(burst)) burst.QueueFree(); };
	}

	// ─────────────────────────────────────────────────────────
	// UI
	// ─────────────────────────────────────────────────────────
	private void UpdateUI()
	{
		if (_lblScore  != null) _lblScore.Text  = $"Điểm: {_level.Score:N0}";
		if (_lblTarget != null) _lblTarget.Text = $"Mục tiêu: {_level.CurrentData.TargetScore:N0}";
		if (_lblMoves  != null) _lblMoves.Text  = $"Lượt: {_level.MovesLeft}";
	}

	private void CheckGameState()
	{
		if (_level.IsGameWon)    ShowVictory(_level.GetStars(), _level.GetRewardAmount());
		else if (_level.IsGameOver) ShowLose();
	}

	private void ShowVictory(int stars, int reward)
	{
		if (_victoryScreen != null) _victoryScreen.Visible = true;
		if (_lblVictoryStars  != null) _lblVictoryStars.Text  = new string('★', stars) + new string('☆', 3 - stars);
		if (_lblVictoryReward != null) _lblVictoryReward.Text = $"+{reward:N0}đ";

		var gm = GetNodeOrNull("/root/GameManager");
		if (gm != null)
		{
			gm.Call("add_money", reward);
			var prog = gm.Get("candy_progress").AsGodotDictionary();
			if (!prog.ContainsKey(StartLevel) || (int)prog[StartLevel] < stars)
				prog[StartLevel] = stars;
		}
		EmitSignal(SignalName.MiniGameWon, StartLevel, reward);
	}

	private void ShowLose() { if (_loseScreen != null) _loseScreen.Visible = true; }

	private void OnClosePressed()  { EmitSignal(SignalName.MinigameClosed); QueueFree(); }

	private void OnNextLevelPressed()
	{
		if (_victoryScreen != null) _victoryScreen.Visible = false;
		StartLevel = Mathf.Min(StartLevel + 1, 50);
		RestartBoard();
	}

	private void OnRetryPressed()
	{
		if (_loseScreen != null) _loseScreen.Visible = false;
		RestartBoard();
	}

	private void RestartBoard()
	{
		foreach (Node child in _boardContainer.GetChildren()) child.QueueFree();
		_level = new CandyLevelManager(StartLevel);
		InitBoard();
		UpdateUI();
		_inputLocked = false;
	}

	// ─────────────────────────────────────────────────────────
	// HELPERS
	// ─────────────────────────────────────────────────────────
	private bool IsInBounds(int col, int row) =>
		col >= 0 && col < COLS && row >= 0 && row < ROWS;

	// ─────────────────────────────────────────────────────────
	// HINTS & SHUFFLE
	// ─────────────────────────────────────────────────────────
	public override void _Process(double delta)
	{
		if (_inputLocked || _level.IsGameOver || _level.IsGameWon) return;
		_idleTime += delta;
		if (_idleTime >= HINT_DELAY && !_hintActive)
		{
			ShowHint();
		}
	}

	private void StopHint()
	{
		_hintActive = false;
		for (int r = 0; r < ROWS; r++)
			for (int c = 0; c < COLS; c++)
				if (_grid[c, r] != null && _grid[c, r].Visual != null && IsInstanceValid(_grid[c, r].Visual))
				{
					_grid[c, r].Visual.Scale = Vector2.One;
				}
	}

	private async void ShowHint()
	{
		_hintActive = true;
		var moves = FindPossibleMoves();
		if (moves.Count == 0)
		{
			CheckNoMoves();
			return;
		}
		
		var move = moves[_rng.Next(moves.Count)];
		var a = move.Item1;
		var b = move.Item2;
		
		while (_hintActive && a.Visual != null && b.Visual != null && IsInstanceValid(a.Visual) && IsInstanceValid(b.Visual))
		{
			Tween tA = a.Visual.CreateTween();
			Tween tB = b.Visual.CreateTween();
			tA.TweenProperty(a.Visual, "scale", new Vector2(1.15f, 1.15f), 0.4f).SetTrans(Tween.TransitionType.Sine);
			tB.TweenProperty(b.Visual, "scale", new Vector2(1.15f, 1.15f), 0.4f).SetTrans(Tween.TransitionType.Sine);
			tA.TweenProperty(a.Visual, "scale", Vector2.One, 0.4f).SetTrans(Tween.TransitionType.Sine);
			tB.TweenProperty(b.Visual, "scale", Vector2.One, 0.4f).SetTrans(Tween.TransitionType.Sine);
			
			// Wait for the animation to finish, plus a tiny delay before pulsing again
			await ToSignal(tA, Tween.SignalName.Finished);
			if (!_hintActive) break;
			await ToSignal(GetTree().CreateTimer(0.2f), SceneTreeTimer.SignalName.Timeout);
		}
	}

	private void CheckNoMoves()
	{
		if (FindPossibleMoves().Count == 0)
			ShuffleBoard();
	}

	private List<(CandyItem, CandyItem)> FindPossibleMoves()
	{
		var moves = new List<(CandyItem, CandyItem)>();
		for (int r = 0; r < ROWS; r++)
		{
			for (int c = 0; c < COLS; c++)
			{
				if (c < COLS - 1 && SimulateSwapMatch(c, r, c + 1, r)) moves.Add((_grid[c, r], _grid[c + 1, r]));
				if (r < ROWS - 1 && SimulateSwapMatch(c, r, c, r + 1)) moves.Add((_grid[c, r], _grid[c, r + 1]));
			}
		}
		return moves;
	}

	private bool SimulateSwapMatch(int c1, int r1, int c2, int r2)
	{
		var a = _grid[c1, r1];
		var b = _grid[c2, r2];
		if (a == null || b == null) return false;
		if (a.IsSpecial || b.IsSpecial) return true;
		
		_grid[c1, r1] = b; _grid[c2, r2] = a;
		bool matchFound = CheckSimpleMatch(c1, r1) || CheckSimpleMatch(c2, r2);
		_grid[c1, r1] = a; _grid[c2, r2] = b;
		return matchFound;
	}

	private bool CheckSimpleMatch(int c, int r)
	{
		var anchor = _grid[c, r];
		if (anchor == null || anchor.Special == SpecialType.ColorBomb) return false;
		
		int hCount = 1;
		for (int i = c - 1; i >= 0 && _grid[i, r] != null && _grid[i, r].Type == anchor.Type && _grid[i, r].Special != SpecialType.ColorBomb; i--) hCount++;
		for (int i = c + 1; i < COLS && _grid[i, r] != null && _grid[i, r].Type == anchor.Type && _grid[i, r].Special != SpecialType.ColorBomb; i++) hCount++;
		if (hCount >= 3) return true;
		
		int vCount = 1;
		for (int i = r - 1; i >= 0 && _grid[c, i] != null && _grid[c, i].Type == anchor.Type && _grid[c, i].Special != SpecialType.ColorBomb; i--) vCount++;
		for (int i = r + 1; i < ROWS && _grid[c, i] != null && _grid[c, i].Type == anchor.Type && _grid[c, i].Special != SpecialType.ColorBomb; i++) vCount++;
		if (vCount >= 3) return true;
		
		return false;
	}

	private void ShuffleBoard()
	{
		_inputLocked = true;
		GD.Print("No moves left! Shuffling board...");
		
		var items = new List<CandyItem>();
		for (int r = 0; r < ROWS; r++)
			for (int c = 0; c < COLS; c++)
				if (_grid[c, r] != null) items.Add(_grid[c, r]);
		
		bool validShuffle = false; int attempts = 0;
		while (!validShuffle && attempts < 100)
		{
			attempts++;
			int n = items.Count;
			while (n > 1) {
				n--; int k = _rng.Next(n + 1);
				var value = items[k]; items[k] = items[n]; items[n] = value;
			}
			
			int idx = 0;
			for (int r = 0; r < ROWS; r++)
				for (int c = 0; c < COLS; c++)
					_grid[c, r] = items[idx++];
			
			bool hasMatches = false;
			for (int r = 0; r < ROWS; r++) {
				for (int c = 0; c < COLS; c++) {
					if (CheckSimpleMatch(c, r)) { hasMatches = true; break; }
				}
				if (hasMatches) break;
			}
			if (!hasMatches && FindPossibleMoves().Count > 0) validShuffle = true;
		}
		
		for (int r = 0; r < ROWS; r++)
		{
			for (int c = 0; c < COLS; c++)
			{
				var item = _grid[c, r];
				item.Col = c; item.Row = r;
				if (item.Visual != null && IsInstanceValid(item.Visual))
				{
					Tween t = item.Visual.CreateTween();
					t.TweenProperty(item.Visual, "position", new Vector2(c * CELL + 2, r * CELL + 2), 0.5f)
					 .SetTrans(Tween.TransitionType.Back).SetEase(Tween.EaseType.Out);
				}
			}
		}
		
		GetTree().CreateTimer(0.6f).Timeout += () => {
			_inputLocked = false;
			_idleTime = 0;
		};
	}
}
