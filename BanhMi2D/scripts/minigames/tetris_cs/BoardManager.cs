using Godot;
using System;
using System.Collections.Generic;
using System.Linq;

public partial class BoardManager : Control
{
    private const int GRID_WIDTH = 10;
    private const int GRID_HEIGHT = 40;
    private const int VISIBLE_HEIGHT = 20;

    // References to UI
    [Export] public NodePath GridTilesPath;
    [Export] public NodePath GhostTilesPath;
    [Export] public NodePath NextPiecesPath;
    [Export] public NodePath HoldPiecePath;
    [Export] public NodePath LblScorePath;
    [Export] public NodePath LblLevelPath;
    [Export] public NodePath LblLinesPath;
    [Export] public NodePath GameOverScreenPath;

    private Node _gridTiles;
    private Node _ghostTiles;
    private Node _nextPiecesParent;
    private Node _holdPieceParent;
    private Label _lblScore;
    private Label _lblLevel;
    private Label _lblLines;
    private Control _gameOverScreen;

    // UI References
    [Export] public NodePath BtnClosePath;
    private Button _btnClose;

    // Tetr.io mechanics
    [Export] public float DAS = 0.15f; // Initial hold delay (sec)
    [Export] public float ARR = 0.03f; // Repeat delay (sec)

    [Signal] public delegate void MinigameClosedEventHandler();
    [Signal] public delegate void MiniGameWonEventHandler(int levelIndex, int rewardAmount);

    public int StartLevel { get; set; } = 1;

    private Color?[,] _grid = new Color?[GRID_WIDTH, GRID_HEIGHT];
    private Piece _activePiece;
    private Piece _holdPiece;
    private bool _canHold = true;
    
    private Queue<Piece> _pieceQueue = new Queue<Piece>();
    private List<TetrominoType> _bag = new List<TetrominoType>();
    
    private LevelManager _levelManager;
    private float _gravityTimer = 0f;
    private float _lockTimer = 0f;
    private int _lockResumes = 0;
    private const int MAX_LOCK_RESUMES = 15;
    
    private float _dasTimer = 0f;
    private float _arrTimer = 0f;
    private int _movementDir = 0;

    private int _score = 0;
    private bool _isGameOver = false;

    private float _garbageTimer = 0f;

    private AudioStreamPlayer _sfxMove;
    private AudioStreamPlayer _sfxClear;
    private AudioStreamPlayer _bgmPlayer;

    // VFX Shaders
    private ShaderMaterial _blockMat;
    private ShaderMaterial _ghostMat;

    public override void _Ready()
    {
        _gridTiles = GetNode<Node>(GridTilesPath);
        _ghostTiles = GetNode<Node>(GhostTilesPath);
        _nextPiecesParent = GetNode<Node>(NextPiecesPath);
        _holdPieceParent = GetNode<Node>(HoldPiecePath);
        _lblScore = GetNode<Label>(LblScorePath);
        _lblLevel = GetNode<Label>(LblLevelPath);
        _lblLines = GetNode<Label>(LblLinesPath);
        _gameOverScreen = GetNode<Control>(GameOverScreenPath);

        // Load Shaders
        var bShader = GD.Load<Shader>("res://assets/shaders/block_glow.gdshader");
        if (bShader != null) {
            _blockMat = new ShaderMaterial();
            _blockMat.Shader = bShader;
            _blockMat.SetShaderParameter("border_width", 0.08f);
            _blockMat.SetShaderParameter("inner_glow_strength", 1.2f);
        }

        var gShader = GD.Load<Shader>("res://assets/shaders/ghost_piece.gdshader");
        if (gShader != null) {
            _ghostMat = new ShaderMaterial();
            _ghostMat.Shader = gShader;
            _ghostMat.SetShaderParameter("line_frequency", 15.0f);
            _ghostMat.SetShaderParameter("line_speed", 2.0f);
            _ghostMat.SetShaderParameter("line_thickness", 0.3f);
        }
        
        if (BtnClosePath != null && !BtnClosePath.IsEmpty)
        {
            _btnClose = GetNode<Button>(BtnClosePath);
            _btnClose.Pressed += OnClosePressed;
        }

        if(_gameOverScreen != null) _gameOverScreen.Visible = false;

        _sfxMove = new AudioStreamPlayer();
        _sfxMove.Stream = GD.Load<AudioStream>("res://assets/Music/text_boop.mp3");
        _sfxMove.Bus = "SFX";
        AddChild(_sfxMove);

        _sfxClear = new AudioStreamPlayer();
        _sfxClear.Stream = GD.Load<AudioStream>("res://assets/Music/Purchase_SFX.mp3");
        _sfxClear.Bus = "SFX";
        AddChild(_sfxClear);

        _bgmPlayer = new AudioStreamPlayer();
        _bgmPlayer.Stream = GD.Load<AudioStream>("res://assets/Music/Aerial City, Chika - Main Menu Music, Extended.mp3");
        _bgmPlayer.Bus = "Music";
        AddChild(_bgmPlayer);
        _bgmPlayer.Play();

        _levelManager = new LevelManager(StartLevel);

        FillBag();
        FillBag(); // Fill enough for next 5
        SpawnNextPiece();
        UpdateUI();
    }

    public override void _Process(double delta)
    {
        if (_isGameOver) return;

        HandleInput((float)delta);
        ApplyGravity((float)delta);
        HandleGarbage((float)delta);
    }

    private void HandleInput(float delta)
    {
        // Directional Input (DAS & ARR)
        int currentDir = 0;
        if (Input.IsActionPressed("ui_right")) currentDir = 1;
        else if (Input.IsActionPressed("ui_left")) currentDir = -1;

        if (currentDir != 0)
        {
            if (_movementDir != currentDir)
            {
                // Initial press
                _movementDir = currentDir;
                _dasTimer = 0f;
                _arrTimer = 0f;
                TryMove(_movementDir, 0);
            }
            else
            {
                // Holding
                _dasTimer += delta;
                if (_dasTimer >= DAS)
                {
                    _arrTimer += delta;
                    if (ARR == 0f)
                    {
                        // Instant teleport to wall
                        while(TryMove(_movementDir, 0)) { }
                    }
                    else
                    {
                        while (_arrTimer >= ARR)
                        {
                            TryMove(_movementDir, 0);
                            _arrTimer -= ARR;
                        }
                    }
                }
            }
        }
        else
        {
            _movementDir = 0;
        }

        // Other Actions
        if (Input.IsActionJustPressed("ui_up") || Input.IsActionJustPressed("ui_accept"))
        {
            RotatePiece((int)_activePiece.CurrentRotation + 1); // Clockwise
        }
        if (Input.IsActionJustPressed("ui_focus_next")) // typically Z or Ctrl
        {
            RotatePiece((int)_activePiece.CurrentRotation - 1); // Counter-Clockwise
        }

        if (Input.IsActionJustPressed("ui_down"))
        {
            // Soft drop starts faster gravity
            TryMove(0, 1);
        }
        else if (Input.IsActionPressed("ui_down"))
        {
            // Continuous soft drop
            _gravityTimer += delta * 15f; // 15x gravity feeling
        }

        if (Input.IsActionJustPressed("ui_select")) // Space
        {
            HardDrop();
        }

        if (Input.IsKeyLabelPressed(Key.Shift) || Input.IsKeyLabelPressed(Key.C))
        {
            // Throttle hold input simply by using JustPressed logic equivalent
            if (Input.IsActionJustPressed("ui_shift") || Input.IsKeyLabelPressed(Key.C) || Input.IsKeyLabelPressed(Key.Shift))
            {
                HoldPiece();
            }
        }
    }

    private void ApplyGravity(float delta)
    {
        bool touchingGround = !IsValidPosition(_activePiece.ActiveBlocks, _activePiece.Position + new Vector2I(0, 1));

        if (touchingGround)
        {
            _lockTimer += delta;
            if (_lockTimer >= _levelManager.GetLockDelay())
            {
                LockPiece();
            }
        }
        else
        {
            _lockTimer = 0f; // Reset if falls
            _gravityTimer += delta;
            float fallSpeed = _levelManager.CurrentGravity;

            while (_gravityTimer >= fallSpeed)
            {
                if (TryMove(0, 1))
                {
                    _gravityTimer -= fallSpeed;
                }
                else
                {
                    _gravityTimer = 0f;
                    break;
                }
            }
        }
    }

    private void HandleGarbage(float delta)
    {
        float targetRate = _levelManager.GetGarbageSpawnRate();
        if (targetRate > 0)
        {
            _garbageTimer += delta;
            if (_garbageTimer >= targetRate)
            {
                _garbageTimer = 0f;
                InjectGarbage(1);
            }
        }
    }

    #region Movement & Collision

    private bool TryMove(int dx, int dy)
    {
        Vector2I newPos = _activePiece.Position + new Vector2I(dx, dy);
        if (IsValidPosition(_activePiece.ActiveBlocks, newPos))
        {
            if (dy == 0 && Mathf.Abs(dx) > 0) 
            {
                SpawnMoveTrail(); // Horizontal move trail
            }

            _activePiece.Position = newPos;
            
            if (dy == 0) // Horizontal move resets lock delay
            {
                ResetLockDelay();
            }

            DrawBoard();
            
            if (dx != 0 || dy != 0)
            {
                if (_sfxMove != null) { _sfxMove.PitchScale = (float)(new Random().NextDouble() * 0.2 + 0.9); _sfxMove.Play(); }
            }
            
            return true;
        }
        return false;
    }

    private void SpawnMoveTrail()
    {
        if (_gridTiles == null || _activePiece == null) return;
        
        int yOffset = GRID_HEIGHT - VISIBLE_HEIGHT;
        Color trailColor = _activePiece.PieceColor;
        trailColor.A = 0.15f; // Very faint

        foreach (var b in _activePiece.ActiveBlocks)
        {
            int drawY = _activePiece.Position.Y + b.Y - yOffset;
            if (drawY >= 0)
            {
                ColorRect rect = new ColorRect();
                rect.Color = trailColor;
                rect.CustomMinimumSize = new Vector2(32, 32);
                rect.Position = new Vector2((_activePiece.Position.X + b.X) * 32, drawY * 32);
                _gridTiles.AddChild(rect);
                
                // Fade out quickly
                Tween fade = CreateTween();
                fade.TweenProperty(rect, "modulate:a", 0f, 0.15f);
                fade.TweenCallback(Callable.From(rect.QueueFree));
            }
        }
    }

    private void HardDrop()
    {
        int dropDist = 0;
        while (IsValidPosition(_activePiece.ActiveBlocks, _activePiece.Position + new Vector2I(0, dropDist + 1)))
        {
            dropDist++;
        }
        
        SpawnHardDropDust(dropDist);

        _activePiece.Position += new Vector2I(0, dropDist);
        _score += dropDist * 2; // Hard drop bonus
        
        if (_sfxMove != null) { _sfxMove.PitchScale = 1.3f; _sfxMove.Play(); }
        
        ShakeBoard();
        LockPiece();
    }

    private void ShakeBoard()
    {
        Control gridC = _gridTiles as Control;
        Control ghostC = _ghostTiles as Control;
        if (gridC == null || ghostC == null) return;

        Tween shakeTween = CreateTween();
        // Set parallel so both grid and ghost move together
        shakeTween.SetParallel(true);
        
        shakeTween.TweenProperty(gridC, "position:y", 10f, 0.05f);
        shakeTween.TweenProperty(ghostC, "position:y", 10f, 0.05f);
        
        shakeTween.Chain().TweenProperty(gridC, "position:y", 0f, 0.05f);
        shakeTween.TweenProperty(ghostC, "position:y", 0f, 0.05f);
        
        shakeTween.Chain().TweenProperty(gridC, "position:y", 4f, 0.04f);
        shakeTween.TweenProperty(ghostC, "position:y", 4f, 0.04f);
        
        shakeTween.Chain().TweenProperty(gridC, "position:y", 0f, 0.04f);
        shakeTween.TweenProperty(ghostC, "position:y", 0f, 0.04f);
    }

    private void SpawnHardDropDust(int dropDist)
    {
        if (dropDist < 2 || _gridTiles == null) return;
        
        int yOffset = GRID_HEIGHT - VISIBLE_HEIGHT;
        foreach (var b in _activePiece.ActiveBlocks)
        {
            int blockX = _activePiece.Position.X + b.X;
            int blockY = _activePiece.Position.Y + dropDist + b.Y - yOffset;
            
            if (blockY < 0) continue;

            CpuParticles2D dust = new CpuParticles2D();
            dust.Emitting = false;
            dust.OneShot = true;
            dust.Explosiveness = 1.0f;
            dust.Amount = 8;
            dust.Lifetime = 0.4f;
            dust.EmissionShape = CpuParticles2D.EmissionShapeEnum.Rectangle;
            dust.EmissionRectExtents = new Vector2(12, 2);
            dust.Direction = new Vector2(0, -1);
            dust.Spread = 60f;
            dust.Gravity = new Vector2(0, 400f);
            dust.InitialVelocityMin = 50f;
            dust.InitialVelocityMax = 150f;
            dust.ScaleAmountMin = 2f;
            dust.ScaleAmountMax = 6f;
            dust.Color = new Color(1f, 1f, 1f, 0.6f);
            
            int cellSize = 32;
            dust.Position = new Vector2(blockX * cellSize + (cellSize/2f), blockY * cellSize + cellSize);
            
            _gridTiles.AddChild(dust);
            dust.Emitting = true;
            
            SceneTreeTimer timer = GetTree().CreateTimer(0.6f);
            timer.Timeout += () => {
                if (IsInstanceValid(dust)) dust.QueueFree();
            };
        }
    }

    private void RotatePiece(int newRotInt)
    {
        if (_activePiece.Type == TetrominoType.O) return;

        // Wrap around 0-3
        newRotInt = (newRotInt % 4 + 4) % 4;
        RotationState newState = (RotationState)newRotInt;
        RotationState oldState = _activePiece.CurrentRotation;

        _activePiece.SetRotation(newState);

        if (IsValidPosition(_activePiece.ActiveBlocks, _activePiece.Position))
        {
            ResetLockDelay();
            DrawBoard();
            if (_sfxMove != null) { _sfxMove.PitchScale = (float)(new Random().NextDouble() * 0.2 + 1.1); _sfxMove.Play(); }
            return;
        }

        // SRS Wall Kicks
        Vector2I[] kicks = _activePiece.GetKickOffsets(oldState, newState);
        foreach (var kick in kicks)
        {
            Vector2I testPos = _activePiece.Position + kick;
            if (IsValidPosition(_activePiece.ActiveBlocks, testPos))
            {
                _activePiece.Position = testPos;
                ResetLockDelay();
                DrawBoard();
                if (_sfxMove != null) { _sfxMove.PitchScale = (float)(new Random().NextDouble() * 0.2 + 1.1); _sfxMove.Play(); }
                return;
            }
        }

        // Fail to rotate, revert
        _activePiece.SetRotation(oldState);
    }

    private void ResetLockDelay()
    {
        bool touchingGround = !IsValidPosition(_activePiece.ActiveBlocks, _activePiece.Position + new Vector2I(0, 1));
        if (touchingGround && _lockResumes < MAX_LOCK_RESUMES)
        {
            _lockTimer = 0f;
            _lockResumes++;
        }
    }

    private bool IsValidPosition(Vector2I[] blocks, Vector2I center)
    {
        foreach (var b in blocks)
        {
            int checkX = center.X + b.X;
            int checkY = center.Y + b.Y;

            if (checkX < 0 || checkX >= GRID_WIDTH || checkY >= GRID_HEIGHT)
                return false;

            if (checkY >= 0 && _grid[checkX, checkY].HasValue)
                return false;
        }
        return true;
    }

    #endregion

    #region Board Mechanics

    private void LockPiece()
    {
        Vector2I[] absPos = _activePiece.GetAbsolutePositions(_activePiece.Position, _activePiece.CurrentRotation);
        foreach (var pos in absPos)
        {
            if (pos.Y < 0)
            {
                TriggerGameOver();
                return;
            }
            _grid[pos.X, pos.Y] = _activePiece.PieceColor;
        }

        ClearLines();
        SpawnNextPiece();
    }

    private void ClearLines()
    {
        List<int> fullRows = new List<int>();
        for (int y = 0; y < GRID_HEIGHT; y++)
        {
            bool full = true;
            for (int x = 0; x < GRID_WIDTH; x++)
            {
                if (!_grid[x, y].HasValue)
                {
                    full = false;
                    break;
                }
            }
            if (full) fullRows.Add(y);
        }

        if (fullRows.Count > 0)
        {
            int lines = fullRows.Count;
            // Visual feedback before logical shift
            AnimateLineClear(fullRows, lines);
        }
        else
        {
            SpawnNextPiece();
        }
    }

    private void AnimateLineClear(List<int> fullRows, int lines)
    {
        if (_sfxClear != null) { _sfxClear.PitchScale = (float)(new Random().NextDouble() * 0.2 + 0.9); _sfxClear.Play(); }

        int yOffset = GRID_HEIGHT - VISIBLE_HEIGHT;
        Tween clearTween = CreateTween();
        clearTween.SetParallel(true);

        // Flash lines white & Spawn horizontal explosion particles
        foreach (int y in fullRows)
        {
            int canvasY = y - yOffset;
            if (canvasY >= 0)
            {
                for (int x = 0; x < GRID_WIDTH; x++)
                {
                    if (_grid[x, y].HasValue)
                    {
                        SpawnLineClearParticles(x, canvasY, _grid[x, y].Value);
                    }
                }
            }
        }

        // Wait a tiny bit (Line Clear Delay)
        clearTween.Chain().SetParallel(false).TweenInterval(0.15f);
        
        // Execute the shift logic after delay
        clearTween.TweenCallback(Callable.From(() => {
            ExecuteLineShift(fullRows, lines);
        }));
    }

    private void SpawnLineClearParticles(int gridX, int canvasY, Color blockColor)
    {
        if (_gridTiles == null) return;

        Vector2 center = new Vector2(gridX * 32 + 16, canvasY * 32 + 16);

        // Primary dust burst (color-matched, big outward spray)
        CpuParticles2D dust = new CpuParticles2D();
        dust.Emitting = false;
        dust.OneShot = true;
        dust.Explosiveness = 0.97f;
        dust.Amount = 18;
        dust.Lifetime = 0.55f;
        dust.EmissionShape = CpuParticles2D.EmissionShapeEnum.Rectangle;
        dust.EmissionRectExtents = new Vector2(14f, 14f);
        dust.Direction = Vector2.Zero;
        dust.Spread = 180f;
        dust.Gravity = new Vector2(0f, 260f);
        dust.InitialVelocityMin = 100f;
        dust.InitialVelocityMax = 320f;
        dust.ScaleAmountMin = 3f;
        dust.ScaleAmountMax = 8f;
        dust.Color = new Color(blockColor.R, blockColor.G, blockColor.B, 1f);
        dust.Position = center;
        _gridTiles.AddChild(dust);
        dust.Emitting = true;

        // Secondary flash burst (bright white/light, tiny fast fragments)
        CpuParticles2D flash = new CpuParticles2D();
        flash.Emitting = false;
        flash.OneShot = true;
        flash.Explosiveness = 1f;
        flash.Amount = 10;
        flash.Lifetime = 0.3f;
        flash.EmissionShape = CpuParticles2D.EmissionShapeEnum.Point;
        flash.Direction = Vector2.Zero;
        flash.Spread = 180f;
        flash.Gravity = new Vector2(0f, 120f);
        flash.InitialVelocityMin = 150f;
        flash.InitialVelocityMax = 400f;
        flash.ScaleAmountMin = 2f;
        flash.ScaleAmountMax = 5f;
        flash.Color = blockColor.Lightened(0.65f);
        flash.Position = center;
        _gridTiles.AddChild(flash);
        flash.Emitting = true;

        var timer = GetTree().CreateTimer(0.9f);
        timer.Timeout += () => 
        {
            if (IsInstanceValid(dust)) dust.QueueFree();
            if (IsInstanceValid(flash)) flash.QueueFree();
        };
    }

    private void ExecuteLineShift(List<int> fullRows, int lines)
    {
        // Actually shift the grid array
        foreach (int y in fullRows)
        {
            for (int moveY = y; moveY > 0; moveY--)
            {
                for (int x = 0; x < GRID_WIDTH; x++)
                {
                    _grid[x, moveY] = _grid[x, moveY - 1];
                }
            }
            for (int x = 0; x < GRID_WIDTH; x++) _grid[x, 0] = null;
        }

        // Scoring
        _levelManager.AddLines(lines);
        
        int reward = 0;
        switch(lines) {
            case 1: reward = 100 * _levelManager.CurrentLevel; break;
            case 2: reward = 300 * _levelManager.CurrentLevel; break;
            case 3: reward = 500 * _levelManager.CurrentLevel; break;
            case 4: reward = 800 * _levelManager.CurrentLevel; break; // Tetris
        }
        _score += reward;

        // Cấp năng lượng Boost cho Shop chính ngoài game (10 energy / hàng)
        Node gameManager = GetNode("/root/GameManager");
        gameManager.Call("add_boost_energy", 10.0f * lines);

        UpdateUI();
        DrawBoard(); // Redraw with shifted positions

        if (_levelManager.IsLevelComplete())
        {
            TriggerVictory();
        }
        else
        {
            SpawnNextPiece();
        }
    }

    private void HoldPiece()
    {
        if (!_canHold) return;

        Piece temp = _activePiece;
        if (_holdPiece != null)
        {
            _activePiece = _holdPiece;
            _activePiece.SetRotation(RotationState.Spawn);
            _activePiece.Position = new Vector2I(GRID_WIDTH / 2 - 1, VISIBLE_HEIGHT - 1); // Reset near spawn
            // We use standard 20 height visible, actual grid is 40. We spawn at Y = 19
            _activePiece.Position = new Vector2I(GRID_WIDTH / 2 - 1, GRID_HEIGHT - VISIBLE_HEIGHT - 1);
        }
        else
        {
            PopQueue();
        }

        _holdPiece = temp;
        _canHold = false;
        
        DrawBoard();
        DrawQueueUI();
    }

    private void InjectGarbage(int lines)
    {
        // Shift everything up
        for (int y = 0; y < GRID_HEIGHT - lines; y++)
        {
            for (int x = 0; x < GRID_WIDTH; x++)
            {
                _grid[x, y] = _grid[x, y + lines];
            }
        }
        // Fill bottom with gray blocks, one random hole
        Random rand = new Random();
        for (int l = 0; l < lines; l++)
        {
            int y = GRID_HEIGHT - 1 - l;
            int hole = rand.Next(GRID_WIDTH);
            for (int x = 0; x < GRID_WIDTH; x++)
            {
                _grid[x, y] = (x == hole) ? null : new Color(0.4f, 0.4f, 0.4f);
            }
        }
        DrawBoard();
    }

    #endregion

    #region Generation & State

    private void FillBag()
    {
        TetrominoType[] types = (TetrominoType[])Enum.GetValues(typeof(TetrominoType));
        List<TetrominoType> newBag = types.ToList();
        
        // Shuffle
        Random r = new Random();
        for (int i = newBag.Count - 1; i > 0; i--)
        {
            int j = r.Next(i + 1);
            var temp = newBag[i];
            newBag[i] = newBag[j];
            newBag[j] = temp;
        }

        _bag.AddRange(newBag);
        
        while (_pieceQueue.Count < 5)
        {
            _pieceQueue.Enqueue(new Piece(_bag[0]));
            _bag.RemoveAt(0);
        }
    }

    private void SpawnNextPiece()
    {
        _canHold = true;
        _gravityTimer = 0f;
        _lockTimer = 0f;
        _lockResumes = 0;

        PopQueue();

        if (!IsValidPosition(_activePiece.ActiveBlocks, _activePiece.Position))
        {
            TriggerGameOver();
        }
        else
        {
            DrawBoard();
            DrawQueueUI();
        }
    }

    private void PopQueue()
    {
        if (_bag.Count < 5) FillBag();
        
        _activePiece = _pieceQueue.Dequeue();
        _pieceQueue.Enqueue(new Piece(_bag[0]));
        _bag.RemoveAt(0);

        // Spawn high up in the vanish zone
        _activePiece.Position = new Vector2I(GRID_WIDTH / 2 - 1, GRID_HEIGHT - VISIBLE_HEIGHT - 1);
    }

    private void TriggerGameOver()
    {
        _isGameOver = true;
        if (_gameOverScreen != null) _gameOverScreen.Visible = true;
        GD.Print("TETRIS: Game Over");
    }

    private void TriggerVictory()
    {
        _isGameOver = true;
        
        // Communicate with GameManager.gd
        int[] starsTarget = _levelManager.GetStarTargets();
        int stars = 1;
        if (_score >= starsTarget[2]) stars = 3;
        else if (_score >= starsTarget[1]) stars = 2;

        int moneyReward = (stars * 50) + _score / 10;
        
        // Save progress to GameManager
        Node gameManager = GetNode("/root/GameManager");
        if (gameManager != null)
        {
            if (gameManager.HasMethod("add_money"))
            {
                gameManager.Call("add_money", moneyReward);
            }
            // Add stars to dictionary
            var prog = (Godot.Collections.Dictionary)gameManager.Get("tetris_progress");
            if (prog != null)
            {
                int prevStars = prog.ContainsKey(StartLevel) ? (int)prog[StartLevel] : 0;
                if (stars > prevStars)
                {
                    prog[StartLevel] = stars;
                    gameManager.Set("tetris_progress", prog);
                }
            }
        }

        // Emit Custom Signal as requested
        EmitSignal(SignalName.MiniGameWon, StartLevel, moneyReward);
        EmitSignal(SignalName.MinigameClosed);
        QueueFree(); // Close immediately, or you could show a UI first.
    }

    private void OnClosePressed()
    {
        EmitSignal(SignalName.MinigameClosed);
        QueueFree();
    }

    #endregion

    #region Rendering

    private void DrawBoard()
    {
        if (_gridTiles == null || _activePiece == null) return;

        // Clear only ColorRects (leave particles alone!)
        foreach (Node child in _gridTiles.GetChildren()) 
        {
            if (child is ColorRect) child.QueueFree();
        }
        foreach (Node child in _ghostTiles.GetChildren()) child.QueueFree();

        // Constants for drawing visually. The top 20 rows are "invisible".
        // Rendering row visibleY = logicalY - (GRID_HEIGHT - VISIBLE_HEIGHT)
        int yOffset = GRID_HEIGHT - VISIBLE_HEIGHT;

        // Draw locked blocks
        for (int y = yOffset; y < GRID_HEIGHT; y++)
        {
            for (int x = 0; x < GRID_WIDTH; x++)
            {
                if (_grid[x, y].HasValue)
                {
                    CreateBlockRect(_gridTiles, x, y - yOffset, _grid[x, y].Value);
                }
            }
        }

        if (!_isGameOver)
        {
            // Draw Ghost
            int ghostY = _activePiece.Position.Y;
            while (IsValidPosition(_activePiece.ActiveBlocks, new Vector2I(_activePiece.Position.X, ghostY + 1)))
            {
                ghostY++;
            }

            Color ghostColor = _activePiece.PieceColor;
            ghostColor.A = 0.3f;
            foreach (var b in _activePiece.ActiveBlocks)
            {
                int drawY = ghostY + b.Y - yOffset;
                if (drawY >= 0) CreateBlockRect(_ghostTiles, _activePiece.Position.X + b.X, drawY, ghostColor, 32, true);
            }

            // Draw Active Piece
            foreach (var b in _activePiece.ActiveBlocks)
            {
                int drawY = _activePiece.Position.Y + b.Y - yOffset;
                if (drawY >= 0) CreateBlockRect(_gridTiles, _activePiece.Position.X + b.X, drawY, _activePiece.PieceColor);
            }
        }
    }

    private void DrawQueueUI()
    {
        if (_nextPiecesParent == null) return;

        // Implementation to draw miniature pieces in VBox
        foreach (Node child in _nextPiecesParent.GetChildren()) child.QueueFree();

        foreach (Piece p in _pieceQueue)
        {
            Control container = new Control();
            container.CustomMinimumSize = new Vector2(80, 80);
            
            foreach (var b in p.ActiveBlocks)
            {
                CreateBlockRect(container, 1 + b.X, 1 + b.Y, p.PieceColor, 20);
            }
            _nextPiecesParent.AddChild(container);
        }

        // Draw Hold
        if (_holdPieceParent != null)
        {
            foreach (Node child in _holdPieceParent.GetChildren()) child.QueueFree();
            if (_holdPiece != null)
            {
                foreach (var b in _holdPiece.ActiveBlocks)
                {
                    CreateBlockRect(_holdPieceParent, 1 + b.X, 1 + b.Y, _holdPiece.PieceColor, 20);
                }
            }
        }
    }

    private void CreateBlockRect(Node parent, int x, int y, Color color, int size = 32, bool isGhost = false)
    {
        ColorRect rect = new ColorRect();
        rect.Color = color;
        rect.CustomMinimumSize = new Vector2(size, size);
        rect.Position = new Vector2(x * size, y * size);
        parent.AddChild(rect);

        if (isGhost)
        {
            if (_ghostMat != null)
            {
                rect.Material = _ghostMat;
                ((ShaderMaterial)rect.Material).SetShaderParameter("out_color", color);
            }
            else
            {
                rect.Color = new Color(color.R, color.G, color.B, 0.3f);
            }
        }
        else
        {
            // Create the classic thick border look. 
            // The outer part is the base 'color'. 
            // The inner border is darkened significantly.
            ColorRect innerRect = new ColorRect();
            innerRect.Color = color.Darkened(0.5f);
            
            // For a 32x32 block, a 4px inset on all sides leaves a 24x24 inner square.
            // When scaled down for the queue (e.g. size=20), the inset should scale proportionally.
            int inset = Mathf.RoundToInt(size * 0.125f); 
            innerRect.CustomMinimumSize = new Vector2(size - (inset * 2), size - (inset * 2));
            innerRect.Position = new Vector2(inset, inset);
            rect.AddChild(innerRect);
            
            // The very center is exactly the original base color again
            ColorRect centerRect = new ColorRect();
            centerRect.Color = color;
            int centerInset = Mathf.RoundToInt(size * 0.25f);
            centerRect.CustomMinimumSize = new Vector2(size - (centerInset * 2), size - (centerInset * 2));
            centerRect.Position = new Vector2(centerInset, centerInset);
            rect.AddChild(centerRect);
        }
    }

    private int _displayScore = 0;
    private int _displayLines = 0;
    private Tween _uiTween;

    private void UpdateUI()
    {
        if (_lblLevel != null) _lblLevel.Text = $"Level: {_levelManager.CurrentLevel}";

        if (_uiTween != null && _uiTween.IsValid())
        {
            _uiTween.Kill();
        }
        
        _uiTween = CreateTween();
        _uiTween.SetParallel(true);
        
        // Tween properties need a setter. We tween a dummy property and use a callback to update texts.
        _uiTween.TweenMethod(Callable.From<int>(SetDisplayScore), _displayScore, _score, 0.4f).SetTrans(Tween.TransitionType.Circ).SetEase(Tween.EaseType.Out);
        _uiTween.TweenMethod(Callable.From<int>(SetDisplayLines), _displayLines, _levelManager.LinesCleared, 0.4f).SetTrans(Tween.TransitionType.Circ).SetEase(Tween.EaseType.Out);
    }

    private void SetDisplayScore(int val)
    {
        _displayScore = val;
        if (_lblScore != null) _lblScore.Text = $"Score: {_displayScore}";
    }

    private void SetDisplayLines(int val)
    {
        _displayLines = val;
        if (_lblLines != null) _lblLines.Text = $"Lines: {_displayLines} / {_levelManager.TargetLines}";
    }

    #endregion
}
