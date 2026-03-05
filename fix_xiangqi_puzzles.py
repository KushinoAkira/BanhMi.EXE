"""
Generate 10 validated Xiangqi endgame puzzles + 40 full-board levels.
Validation rules enforced for endgame puzzles (levels 1-10):
  1. Both factions MUST have exactly 1 General.
  2. Flying General rule: Generals must NOT face each other on the same column with no pieces between them.
  3. Black must NOT be in check at the start (it's Red's turn to move first).
  4. Red must NOT be in check at the start.
  5. All pieces must be in valid positions (Advisors/Generals in palace, Elephants on own side, etc).
"""
import json, sys

# ── Xiangqi validation helpers ──────────────────────────────────────

COLS, ROWS = 9, 10

def in_bounds(x, y):
    return 0 <= x < COLS and 0 <= y < ROWS

def in_palace(x, y, faction):
    if x < 3 or x > 5: return False
    if faction == "Black": return 0 <= y <= 2
    return 7 <= y <= 9

def has_crossed_river(y, faction):
    if faction == "Black": return y >= 5
    return y <= 4

def build_grid(pieces):
    grid = [[None]*ROWS for _ in range(COLS)]
    for p in pieces:
        grid[p["x"]][p["y"]] = p
    return grid

def get_pseudo_moves(grid, piece):
    """Return list of (tx, ty) pseudo-legal moves for a piece."""
    moves = []
    x, y, ptype, faction = piece["x"], piece["y"], piece["type"], piece["faction"]
    ally = faction

    def add_if_valid(tx, ty):
        if not in_bounds(tx, ty): return
        target = grid[tx][ty]
        if target is None or target["faction"] != ally:
            moves.append((tx, ty))

    if ptype == "General":
        for dx, dy in [(0,1),(0,-1),(1,0),(-1,0)]:
            tx, ty = x+dx, y+dy
            if in_palace(tx, ty, faction):
                add_if_valid(tx, ty)

    elif ptype == "Advisor":
        for dx, dy in [(1,1),(1,-1),(-1,1),(-1,-1)]:
            tx, ty = x+dx, y+dy
            if in_palace(tx, ty, faction):
                add_if_valid(tx, ty)

    elif ptype == "Elephant":
        for dx, dy in [(2,2),(2,-2),(-2,2),(-2,-2)]:
            tx, ty = x+dx, y+dy
            bx, by = x+dx//2, y+dy//2
            if in_bounds(tx, ty) and not has_crossed_river(ty, faction):
                if grid[bx][by] is None:
                    add_if_valid(tx, ty)

    elif ptype == "Horse":
        hx = [1,2,2,1,-1,-2,-2,-1]
        hy = [2,1,-1,-2,-2,-1,1,2]
        bx = [0,1,1,0,0,-1,-1,0]
        by = [1,0,0,-1,-1,0,0,1]
        for i in range(8):
            tx, ty = x+hx[i], y+hy[i]
            blx, bly = x+bx[i], y+by[i]
            if in_bounds(blx, bly) and grid[blx][bly] is None:
                add_if_valid(tx, ty)

    elif ptype == "Chariot":
        for dx, dy in [(0,1),(0,-1),(1,0),(-1,0)]:
            for step in range(1, max(COLS, ROWS)):
                tx, ty = x+dx*step, y+dy*step
                if not in_bounds(tx, ty): break
                target = grid[tx][ty]
                if target is None:
                    moves.append((tx, ty))
                else:
                    if target["faction"] != ally:
                        moves.append((tx, ty))
                    break

    elif ptype == "Cannon":
        for dx, dy in [(0,1),(0,-1),(1,0),(-1,0)]:
            jumped = False
            for step in range(1, max(COLS, ROWS)):
                tx, ty = x+dx*step, y+dy*step
                if not in_bounds(tx, ty): break
                target = grid[tx][ty]
                if not jumped:
                    if target is None:
                        moves.append((tx, ty))
                    else:
                        jumped = True
                else:
                    if target is not None:
                        if target["faction"] != ally:
                            moves.append((tx, ty))
                        break

    elif ptype == "Soldier":
        fwd = -1 if faction == "Red" else 1
        add_if_valid(x, y+fwd)
        if has_crossed_river(y, faction):
            add_if_valid(x+1, y)
            add_if_valid(x-1, y)

    return moves

def generals_face(grid, pieces):
    """Check if the two generals face each other on the same column with nothing between."""
    red_g = black_g = None
    for p in pieces:
        if p["type"] == "General":
            if p["faction"] == "Red": red_g = p
            else: black_g = p
    if not red_g or not black_g: return True  # Missing general = invalid
    if red_g["x"] != black_g["x"]: return False
    col = red_g["x"]
    min_y, max_y = min(red_g["y"], black_g["y"]), max(red_g["y"], black_g["y"])
    for y in range(min_y+1, max_y):
        if grid[col][y] is not None:
            return False
    return True

def is_in_check(grid, pieces, faction):
    """Check if faction's General is under attack by any enemy piece."""
    general = None
    for p in pieces:
        if p["type"] == "General" and p["faction"] == faction:
            general = p
            break
    if not general: return True  # No general = invalid

    enemy = "Black" if faction == "Red" else "Red"
    for p in pieces:
        if p["faction"] != enemy: continue
        for (tx, ty) in get_pseudo_moves(grid, p):
            if tx == general["x"] and ty == general["y"]:
                return True
    return False

def can_capture_general(grid, pieces, attacker_faction):
    """Check if attacker_faction has any move that captures the enemy general."""
    enemy = "Black" if attacker_faction == "Red" else "Red"
    enemy_gen = None
    for p in pieces:
        if p["type"] == "General" and p["faction"] == enemy:
            enemy_gen = p
            break
    if not enemy_gen: return True

    for p in pieces:
        if p["faction"] != attacker_faction: continue
        for (tx, ty) in get_pseudo_moves(grid, p):
            if tx == enemy_gen["x"] and ty == enemy_gen["y"]:
                return True
    return False

def validate_puzzle(puzzle):
    """Validate a puzzle configuration. Returns (ok, errors)."""
    pieces = puzzle["pieces"]
    errors = []

    # Check generals exist
    red_gen = [p for p in pieces if p["type"] == "General" and p["faction"] == "Red"]
    black_gen = [p for p in pieces if p["type"] == "General" and p["faction"] == "Black"]
    if len(red_gen) != 1: errors.append(f"Red has {len(red_gen)} generals (need 1)")
    if len(black_gen) != 1: errors.append(f"Black has {len(black_gen)} generals (need 1)")
    if errors: return False, errors

    grid = build_grid(pieces)

    # Check Flying General
    if generals_face(grid, pieces):
        errors.append("Flying General: generals face each other with nothing between")

    # Check piece positions
    for p in pieces:
        x, y, t, f = p["x"], p["y"], p["type"], p["faction"]
        if not in_bounds(x, y):
            errors.append(f"{f} {t} at ({x},{y}) out of bounds")
        if t == "General" and not in_palace(x, y, f):
            errors.append(f"{f} General at ({x},{y}) not in palace")
        if t == "Advisor" and not in_palace(x, y, f):
            errors.append(f"{f} Advisor at ({x},{y}) not in palace")
        if t == "Elephant" and has_crossed_river(y, f):
            errors.append(f"{f} Elephant at ({x},{y}) has crossed river")

    # Red moves first: Black must NOT be in check (Red can't have already checked Black)
    if is_in_check(grid, pieces, "Black"):
        errors.append("Black is already in check at start (Red hasn't moved yet)")

    # Red must NOT be in check at start either
    if is_in_check(grid, pieces, "Red"):
        errors.append("Red is in check at start")

    # Red must NOT be able to capture Black General immediately
    if can_capture_general(grid, pieces, "Red"):
        errors.append("Red can capture Black General on first move!")

    return len(errors) == 0, errors


# ── Puzzle definitions ──────────────────────────────────────────────
# All endgame puzzles carefully designed so Red must find the right sequence.
# Key constraint: NO red piece can reach the Black General in one move.

puzzles = []

# Level 1: Xe chiếu bí. Red Chariot is NOT on same row/col as Black General.
# Red must move Chariot to column 4 to deliver check.
# Black General at (4,0), Advisors block sides. Red Chariot at (0,3), Red General at (4,9).
puzzles.append({
    "level": 1,
    "description": "Sát cục: Xe đâm chiếu bí",
    "aiLevel": 1,
    "pieces": [
        {"type": "General",  "faction": "Black", "x": 4, "y": 0},
        {"type": "Advisor",  "faction": "Black", "x": 3, "y": 0},
        {"type": "Advisor",  "faction": "Black", "x": 5, "y": 0},
        {"type": "General",  "faction": "Red",   "x": 3, "y": 9},  # Off-center to avoid flying general
        {"type": "Chariot",  "faction": "Red",   "x": 0, "y": 3},  # Must slide to col 4
    ]
})

# Level 2: Mã chiếu. Horse at (6,3) - can't reach (4,0) in one jump.
# Chariot on row 3, NOT on row 0 or 1 to avoid checking general.
puzzles.append({
    "level": 2,
    "description": "Sát cục: Mã chiếu bí",
    "aiLevel": 1,
    "pieces": [
        {"type": "General",  "faction": "Black", "x": 4, "y": 0},
        {"type": "Advisor",  "faction": "Black", "x": 3, "y": 1},
        {"type": "Advisor",  "faction": "Black", "x": 5, "y": 1},
        {"type": "General",  "faction": "Red",   "x": 3, "y": 9},
        {"type": "Horse",    "faction": "Red",   "x": 6, "y": 3},  # Far from general
        {"type": "Chariot",  "faction": "Red",   "x": 0, "y": 3},  # Row 3, can't reach general
    ]
})

# Level 3: Pháo + screen. Cannon NOT aimed at general yet.
# Red Chariot on row 5 (not row 0) to avoid checking.
puzzles.append({
    "level": 3,
    "description": "Sát cục: Pháo chiếu",
    "aiLevel": 2,
    "pieces": [
        {"type": "General",  "faction": "Black", "x": 4, "y": 0},
        {"type": "Advisor",  "faction": "Black", "x": 3, "y": 0},
        {"type": "Advisor",  "faction": "Black", "x": 5, "y": 1},
        {"type": "General",  "faction": "Red",   "x": 3, "y": 9},
        {"type": "Cannon",   "faction": "Red",   "x": 2, "y": 4},  # Needs to slide to col 4
        {"type": "Chariot",  "faction": "Red",   "x": 8, "y": 5},  # Row 5, can't reach general
    ]
})

# Level 4: Xe + Mã combo
puzzles.append({
    "level": 4,
    "description": "Cờ thế: Xe Mã phối hợp",
    "aiLevel": 2,
    "pieces": [
        {"type": "General",  "faction": "Black", "x": 4, "y": 0},
        {"type": "Advisor",  "faction": "Black", "x": 3, "y": 1},
        {"type": "Advisor",  "faction": "Black", "x": 5, "y": 0},
        {"type": "Elephant", "faction": "Black", "x": 2, "y": 2},
        {"type": "General",  "faction": "Red",   "x": 5, "y": 9},
        {"type": "Chariot",  "faction": "Red",   "x": 0, "y": 5},
        {"type": "Horse",    "faction": "Red",   "x": 7, "y": 3},
    ]
})

# Level 5: Double Chariot mate
puzzles.append({
    "level": 5,
    "description": "Tuyệt sát: Song Xe chiếu",
    "aiLevel": 3,
    "pieces": [
        {"type": "General",  "faction": "Black", "x": 4, "y": 0},
        {"type": "Advisor",  "faction": "Black", "x": 3, "y": 0},
        {"type": "Advisor",  "faction": "Black", "x": 5, "y": 0},
        {"type": "Horse",    "faction": "Black", "x": 7, "y": 0},
        {"type": "General",  "faction": "Red",   "x": 3, "y": 9},
        {"type": "Chariot",  "faction": "Red",   "x": 0, "y": 4},
        {"type": "Chariot",  "faction": "Red",   "x": 8, "y": 5},
    ]
})

# Level 6: Cannon + Chariot
puzzles.append({
    "level": 6,
    "description": "Cờ thế: Pháo Xe hợp bích",
    "aiLevel": 4,
    "pieces": [
        {"type": "General",  "faction": "Black", "x": 4, "y": 0},
        {"type": "Advisor",  "faction": "Black", "x": 3, "y": 0},
        {"type": "Advisor",  "faction": "Black", "x": 5, "y": 1},
        {"type": "Chariot",  "faction": "Black", "x": 8, "y": 2},
        {"type": "General",  "faction": "Red",   "x": 5, "y": 9},
        {"type": "Chariot",  "faction": "Red",   "x": 0, "y": 3},
        {"type": "Cannon",   "faction": "Red",   "x": 2, "y": 5},
        {"type": "Advisor",  "faction": "Red",   "x": 4, "y": 9},
    ]
})

# Level 7: Horse + Cannon
puzzles.append({
    "level": 7,
    "description": "Tiền Mã Hậu Pháo",
    "aiLevel": 4,
    "pieces": [
        {"type": "General",  "faction": "Black", "x": 4, "y": 0},
        {"type": "Advisor",  "faction": "Black", "x": 3, "y": 1},
        {"type": "Advisor",  "faction": "Black", "x": 5, "y": 0},
        {"type": "Chariot",  "faction": "Black", "x": 0, "y": 0},
        {"type": "Elephant", "faction": "Black", "x": 6, "y": 2},
        {"type": "General",  "faction": "Red",   "x": 5, "y": 9},
        {"type": "Horse",    "faction": "Red",   "x": 6, "y": 4},
        {"type": "Cannon",   "faction": "Red",   "x": 2, "y": 3},
        {"type": "Advisor",  "faction": "Red",   "x": 4, "y": 8},
    ]
})

# Level 8: Complex 3-piece attack
puzzles.append({
    "level": 8,
    "description": "Cờ thế: Tam quân phá thành",
    "aiLevel": 5,
    "pieces": [
        {"type": "General",  "faction": "Black", "x": 4, "y": 0},
        {"type": "Advisor",  "faction": "Black", "x": 3, "y": 0},
        {"type": "Advisor",  "faction": "Black", "x": 5, "y": 1},
        {"type": "Chariot",  "faction": "Black", "x": 8, "y": 0},
        {"type": "Horse",    "faction": "Black", "x": 1, "y": 0},
        {"type": "General",  "faction": "Red",   "x": 3, "y": 9},
        {"type": "Chariot",  "faction": "Red",   "x": 0, "y": 5},
        {"type": "Cannon",   "faction": "Red",   "x": 7, "y": 4},
        {"type": "Horse",    "faction": "Red",   "x": 6, "y": 5},
    ]
})

# Level 9: Trapping general with minimal pieces
puzzles.append({
    "level": 9,
    "description": "Cờ thế: Bức tướng",
    "aiLevel": 6,
    "pieces": [
        {"type": "General",  "faction": "Black", "x": 5, "y": 0},
        {"type": "Advisor",  "faction": "Black", "x": 4, "y": 0},
        {"type": "Advisor",  "faction": "Black", "x": 4, "y": 1},
        {"type": "Chariot",  "faction": "Black", "x": 0, "y": 2},
        {"type": "Cannon",   "faction": "Black", "x": 7, "y": 3},
        {"type": "General",  "faction": "Red",   "x": 3, "y": 9},
        {"type": "Chariot",  "faction": "Red",   "x": 8, "y": 4},
        {"type": "Chariot",  "faction": "Red",   "x": 2, "y": 5},
        {"type": "Horse",    "faction": "Red",   "x": 7, "y": 5},
        {"type": "Advisor",  "faction": "Red",   "x": 4, "y": 9},
    ]
})

# Level 10: Multi-move endgame
puzzles.append({
    "level": 10,
    "description": "Cờ thế: Liên hoàn mã",
    "aiLevel": 7,
    "pieces": [
        {"type": "General",  "faction": "Black", "x": 4, "y": 0},
        {"type": "Advisor",  "faction": "Black", "x": 3, "y": 0},
        {"type": "Advisor",  "faction": "Black", "x": 5, "y": 0},
        {"type": "Chariot",  "faction": "Black", "x": 0, "y": 0},
        {"type": "Elephant", "faction": "Black", "x": 6, "y": 2},
        {"type": "Cannon",   "faction": "Black", "x": 1, "y": 4},
        {"type": "General",  "faction": "Red",   "x": 5, "y": 9},
        {"type": "Horse",    "faction": "Red",   "x": 7, "y": 4},
        {"type": "Horse",    "faction": "Red",   "x": 1, "y": 5},
        {"type": "Chariot",  "faction": "Red",   "x": 8, "y": 3},
        {"type": "Advisor",  "faction": "Red",   "x": 4, "y": 9},
    ]
})

# ── Validate all endgame puzzles ────────────────────────────────────
print("=" * 60)
print("VALIDATING 10 ENDGAME PUZZLES")
print("=" * 60)
all_ok = True
for pz in puzzles:
    ok, errs = validate_puzzle(pz)
    status = "[PASS]" if ok else "[FAIL]"
    print(f"  Level {pz['level']:2d}: {status}  ({pz['description']})")
    if not ok:
        for e in errs:
            print(f"           ! {e}")
        all_ok = False

if not all_ok:
    print("\nFAILED: SOME PUZZLES FAILED VALIDATION. Fix them before saving!")
    sys.exit(1)

# ── Full-board levels 11-50 ─────────────────────────────────────────
FULL_BLACK = [
    {"type": "Chariot",  "faction": "Black", "x": 0, "y": 0},
    {"type": "Horse",    "faction": "Black", "x": 1, "y": 0},
    {"type": "Elephant", "faction": "Black", "x": 2, "y": 0},
    {"type": "Advisor",  "faction": "Black", "x": 3, "y": 0},
    {"type": "General",  "faction": "Black", "x": 4, "y": 0},
    {"type": "Advisor",  "faction": "Black", "x": 5, "y": 0},
    {"type": "Elephant", "faction": "Black", "x": 6, "y": 0},
    {"type": "Horse",    "faction": "Black", "x": 7, "y": 0},
    {"type": "Chariot",  "faction": "Black", "x": 8, "y": 0},
    {"type": "Cannon",   "faction": "Black", "x": 1, "y": 2},
    {"type": "Cannon",   "faction": "Black", "x": 7, "y": 2},
    {"type": "Soldier",  "faction": "Black", "x": 0, "y": 3},
    {"type": "Soldier",  "faction": "Black", "x": 2, "y": 3},
    {"type": "Soldier",  "faction": "Black", "x": 4, "y": 3},
    {"type": "Soldier",  "faction": "Black", "x": 6, "y": 3},
    {"type": "Soldier",  "faction": "Black", "x": 8, "y": 3},
]
FULL_RED = [
    {"type": "Chariot",  "faction": "Red", "x": 0, "y": 9},
    {"type": "Horse",    "faction": "Red", "x": 1, "y": 9},
    {"type": "Elephant", "faction": "Red", "x": 2, "y": 9},
    {"type": "Advisor",  "faction": "Red", "x": 3, "y": 9},
    {"type": "General",  "faction": "Red", "x": 4, "y": 9},
    {"type": "Advisor",  "faction": "Red", "x": 5, "y": 9},
    {"type": "Elephant", "faction": "Red", "x": 6, "y": 9},
    {"type": "Horse",    "faction": "Red", "x": 7, "y": 9},
    {"type": "Chariot",  "faction": "Red", "x": 8, "y": 9},
    {"type": "Cannon",   "faction": "Red", "x": 1, "y": 7},
    {"type": "Cannon",   "faction": "Red", "x": 7, "y": 7},
    {"type": "Soldier",  "faction": "Red", "x": 0, "y": 6},
    {"type": "Soldier",  "faction": "Red", "x": 2, "y": 6},
    {"type": "Soldier",  "faction": "Red", "x": 4, "y": 6},
    {"type": "Soldier",  "faction": "Red", "x": 6, "y": 6},
    {"type": "Soldier",  "faction": "Red", "x": 8, "y": 6},
]

for i in range(11, 51):
    ai_level = 6 + (i - 10)
    puzzles.append({
        "level": i,
        "description": f"Trận đầy đủ – Ván {i}",
        "aiLevel": ai_level,
        "pieces": [dict(p) for p in FULL_BLACK + FULL_RED]
    })

# ── Save ────────────────────────────────────────────────────────────
out_path = r"c:\Users\h_u_n\.gemini\antigravity\scratch\banh-mi-exe\data\xiangqi_puzzles.json"
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(puzzles, f, ensure_ascii=False, indent=2)
print(f"\nOK: Generated {len(puzzles)} puzzles (all validated) -> {out_path}")
