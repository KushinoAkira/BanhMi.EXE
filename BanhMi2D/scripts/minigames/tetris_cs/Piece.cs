using Godot;
using System;
using System.Collections.Generic;

public enum TetrominoType { I, J, L, O, S, T, Z }
public enum RotationState { Spawn, Right, Two, Left } // 0, R, 2, L in SRS

public class Piece
{
    public TetrominoType Type { get; private set; }
    public RotationState CurrentRotation { get; set; } = RotationState.Spawn;
    public Vector2I Position { get; set; } // Center position in grid coordinates (X, Y)
    
    // The relative block positions based on current rotation (4 blocks)
    public Vector2I[] ActiveBlocks { get; private set; }
    public Color PieceColor { get; private set; }

    // Dictionary defining the 4 blocks relative to center for each rotation state [RotationState][BlockIndex]
    private Dictionary<RotationState, Vector2I[]> _blocksData;
    
    // SRS Kick tables. J,L,S,T,Z use one table, I uses another, O does not kick.
    private static readonly Dictionary<string, Vector2I[]> SRS_JLSTZ = new Dictionary<string, Vector2I[]>
    {
        { "Spawn->Right", new[] { new Vector2I(0,0), new Vector2I(-1,0), new Vector2I(-1,-1), new Vector2I(0,2), new Vector2I(-1,2) } },
        { "Right->Spawn", new[] { new Vector2I(0,0), new Vector2I(1,0), new Vector2I(1,1), new Vector2I(0,-2), new Vector2I(1,-2) } },
        { "Right->Two",   new[] { new Vector2I(0,0), new Vector2I(1,0), new Vector2I(1,1), new Vector2I(0,-2), new Vector2I(1,-2) } },
        { "Two->Right",   new[] { new Vector2I(0,0), new Vector2I(-1,0), new Vector2I(-1,-1), new Vector2I(0,2), new Vector2I(-1,2) } },
        { "Two->Left",    new[] { new Vector2I(0,0), new Vector2I(1,0), new Vector2I(1,-1), new Vector2I(0,2), new Vector2I(1,2) } },
        { "Left->Two",    new[] { new Vector2I(0,0), new Vector2I(-1,0), new Vector2I(-1,1), new Vector2I(0,-2), new Vector2I(-1,-2) } },
        { "Left->Spawn",  new[] { new Vector2I(0,0), new Vector2I(-1,0), new Vector2I(-1,1), new Vector2I(0,-2), new Vector2I(-1,-2) } },
        { "Spawn->Left",  new[] { new Vector2I(0,0), new Vector2I(1,0), new Vector2I(1,-1), new Vector2I(0,2), new Vector2I(1,2) } },
    };

    private static readonly Dictionary<string, Vector2I[]> SRS_I = new Dictionary<string, Vector2I[]>
    {
        { "Spawn->Right", new[] { new Vector2I(0,0), new Vector2I(-2,0), new Vector2I(1,0), new Vector2I(-2,1), new Vector2I(1,-2) } },
        { "Right->Spawn", new[] { new Vector2I(0,0), new Vector2I(2,0), new Vector2I(-1,0), new Vector2I(2,-1), new Vector2I(-1,2) } },
        { "Right->Two",   new[] { new Vector2I(0,0), new Vector2I(-1,0), new Vector2I(2,0), new Vector2I(-1,-2), new Vector2I(2,1) } },
        { "Two->Right",   new[] { new Vector2I(0,0), new Vector2I(1,0), new Vector2I(-2,0), new Vector2I(1,2), new Vector2I(-2,-1) } },
        { "Two->Left",    new[] { new Vector2I(0,0), new Vector2I(2,0), new Vector2I(-1,0), new Vector2I(2,-1), new Vector2I(-1,2) } },
        { "Left->Two",    new[] { new Vector2I(0,0), new Vector2I(-2,0), new Vector2I(1,0), new Vector2I(-2,1), new Vector2I(1,-2) } },
        { "Left->Spawn",  new[] { new Vector2I(0,0), new Vector2I(1,0), new Vector2I(-2,0), new Vector2I(1,2), new Vector2I(-2,-1) } },
        { "Spawn->Left",  new[] { new Vector2I(0,0), new Vector2I(-1,0), new Vector2I(2,0), new Vector2I(-1,-2), new Vector2I(2,1) } },
    };

    public Piece(TetrominoType type)
    {
        Type = type;
        _blocksData = new Dictionary<RotationState, Vector2I[]>();
        InitializeShape();
        SetRotation(RotationState.Spawn);
    }

    public void SetRotation(RotationState state)
    {
        CurrentRotation = state;
        ActiveBlocks = _blocksData[state];
    }
    
    // Returns the grid coordinates of the piece's blocks
    public Vector2I[] GetAbsolutePositions(Vector2I pos, RotationState state)
    {
        var localBlocks = _blocksData[state];
        var result = new Vector2I[4];
        for(int i = 0; i < 4; i++) result[i] = pos + localBlocks[i];
        return result;
    }

    public Vector2I[] GetKickOffsets(RotationState from, RotationState to)
    {
        if (Type == TetrominoType.O)
            return new[] { new Vector2I(0, 0) };

        string key = $"{from}->{to}";
        if (Type == TetrominoType.I)
            return SRS_I.ContainsKey(key) ? SRS_I[key] : new[] { new Vector2I(0, 0) };
        else
            return SRS_JLSTZ.ContainsKey(key) ? SRS_JLSTZ[key] : new[] { new Vector2I(0, 0) };
    }

    private void InitializeShape()
    {
        switch (Type)
        {
            case TetrominoType.I:
                PieceColor = Colors.Cyan;
                _blocksData[RotationState.Spawn] = new[] { new Vector2I(-1, 0), new Vector2I(0, 0), new Vector2I(1, 0), new Vector2I(2, 0) };
                _blocksData[RotationState.Right] = new[] { new Vector2I(1, -1), new Vector2I(1, 0), new Vector2I(1, 1), new Vector2I(1, 2) };
                _blocksData[RotationState.Two]   = new[] { new Vector2I(-1, 1), new Vector2I(0, 1), new Vector2I(1, 1), new Vector2I(2, 1) };
                _blocksData[RotationState.Left]  = new[] { new Vector2I(0, -1), new Vector2I(0, 0), new Vector2I(0, 1), new Vector2I(0, 2) };
                break;
            case TetrominoType.J:
                PieceColor = Colors.Blue;
                _blocksData[RotationState.Spawn] = new[] { new Vector2I(-1, -1), new Vector2I(-1, 0), new Vector2I(0, 0), new Vector2I(1, 0) };
                _blocksData[RotationState.Right] = new[] { new Vector2I(1, -1), new Vector2I(0, -1), new Vector2I(0, 0), new Vector2I(0, 1) };
                _blocksData[RotationState.Two]   = new[] { new Vector2I(1, 1), new Vector2I(1, 0), new Vector2I(0, 0), new Vector2I(-1, 0) };
                _blocksData[RotationState.Left]  = new[] { new Vector2I(-1, 1), new Vector2I(0, 1), new Vector2I(0, 0), new Vector2I(0, -1) };
                break;
            case TetrominoType.L:
                PieceColor = Colors.DarkOrange;
                _blocksData[RotationState.Spawn] = new[] { new Vector2I(1, -1), new Vector2I(-1, 0), new Vector2I(0, 0), new Vector2I(1, 0) };
                _blocksData[RotationState.Right] = new[] { new Vector2I(1, 1), new Vector2I(0, -1), new Vector2I(0, 0), new Vector2I(0, 1) };
                _blocksData[RotationState.Two]   = new[] { new Vector2I(-1, 1), new Vector2I(1, 0), new Vector2I(0, 0), new Vector2I(-1, 0) };
                _blocksData[RotationState.Left]  = new[] { new Vector2I(-1, -1), new Vector2I(0, 1), new Vector2I(0, 0), new Vector2I(0, -1) };
                break;
            case TetrominoType.O:
                PieceColor = Colors.Yellow;
                var oBlocks = new[] { new Vector2I(0, -1), new Vector2I(1, -1), new Vector2I(0, 0), new Vector2I(1, 0) };
                _blocksData[RotationState.Spawn] = oBlocks;
                _blocksData[RotationState.Right] = oBlocks;
                _blocksData[RotationState.Two] = oBlocks;
                _blocksData[RotationState.Left] = oBlocks;
                break;
            case TetrominoType.S:
                PieceColor = Colors.Green;
                _blocksData[RotationState.Spawn] = new[] { new Vector2I(0, -1), new Vector2I(1, -1), new Vector2I(-1, 0), new Vector2I(0, 0) };
                _blocksData[RotationState.Right] = new[] { new Vector2I(0, -1), new Vector2I(0, 0), new Vector2I(1, 0), new Vector2I(1, 1) };
                _blocksData[RotationState.Two]   = new[] { new Vector2I(0, 1), new Vector2I(-1, 1), new Vector2I(1, 0), new Vector2I(0, 0) };
                _blocksData[RotationState.Left]  = new[] { new Vector2I(-1, -1), new Vector2I(-1, 0), new Vector2I(0, 0), new Vector2I(0, 1) };
                break;
            case TetrominoType.T:
                PieceColor = Colors.Purple;
                _blocksData[RotationState.Spawn] = new[] { new Vector2I(0, -1), new Vector2I(-1, 0), new Vector2I(0, 0), new Vector2I(1, 0) };
                _blocksData[RotationState.Right] = new[] { new Vector2I(1, 0), new Vector2I(0, -1), new Vector2I(0, 0), new Vector2I(0, 1) };
                _blocksData[RotationState.Two]   = new[] { new Vector2I(0, 1), new Vector2I(1, 0), new Vector2I(0, 0), new Vector2I(-1, 0) };
                _blocksData[RotationState.Left]  = new[] { new Vector2I(-1, 0), new Vector2I(0, 1), new Vector2I(0, 0), new Vector2I(0, -1) };
                break;
            case TetrominoType.Z:
                PieceColor = Colors.Red;
                _blocksData[RotationState.Spawn] = new[] { new Vector2I(-1, -1), new Vector2I(0, -1), new Vector2I(0, 0), new Vector2I(1, 0) };
                _blocksData[RotationState.Right] = new[] { new Vector2I(1, -1), new Vector2I(1, 0), new Vector2I(0, 0), new Vector2I(0, 1) };
                _blocksData[RotationState.Two]   = new[] { new Vector2I(1, 1), new Vector2I(0, 1), new Vector2I(0, 0), new Vector2I(-1, 0) };
                _blocksData[RotationState.Left]  = new[] { new Vector2I(-1, 1), new Vector2I(-1, 0), new Vector2I(0, 0), new Vector2I(0, -1) };
                break;
        }
    }
}
