import json

def make_endgame(level, description, pieces_config, ai_level):
    return {"level": level, "description": description, "aiLevel": ai_level, "pieces": pieces_config}

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

def make_full(level, description, ai_level):
    return {"level": level, "description": description, "aiLevel": ai_level, "pieces": FULL_BLACK + FULL_RED}

puzzles = []

# Levels 1-5: Endgame mate-in-1
puzzles.append(make_endgame(1, "Mate in 1 – Xe chiếu bí", [
    {"type": "General",  "faction": "Red",   "x": 4, "y": 9},
    {"type": "Chariot",  "faction": "Red",   "x": 5, "y": 7},
    {"type": "General",  "faction": "Black", "x": 4, "y": 0},
    {"type": "Advisor",  "faction": "Black", "x": 3, "y": 0},
    {"type": "Advisor",  "faction": "Black", "x": 5, "y": 0},
], 1))
puzzles.append(make_endgame(2, "Mate in 1 – Mã chiếu bí", [
    {"type": "General",  "faction": "Red",   "x": 4, "y": 9},
    {"type": "Horse",    "faction": "Red",   "x": 3, "y": 2},
    {"type": "Chariot",  "faction": "Red",   "x": 2, "y": 0},
    {"type": "General",  "faction": "Black", "x": 4, "y": 0},
    {"type": "Advisor",  "faction": "Black", "x": 4, "y": 1},
], 1))
puzzles.append(make_endgame(3, "Mate in 1 – Pháo đôi", [
    {"type": "General",  "faction": "Red",   "x": 4, "y": 9},
    {"type": "Cannon",   "faction": "Red",   "x": 4, "y": 5},
    {"type": "Cannon",   "faction": "Red",   "x": 0, "y": 2},
    {"type": "General",  "faction": "Black", "x": 4, "y": 0},
    {"type": "Chariot",  "faction": "Black", "x": 3, "y": 0},
    {"type": "Advisor",  "faction": "Black", "x": 4, "y": 1},
    {"type": "Advisor",  "faction": "Black", "x": 5, "y": 0},
], 2))
puzzles.append(make_endgame(4, "Xe xọc tướng", [
    {"type": "General",  "faction": "Red",   "x": 4, "y": 9},
    {"type": "Chariot",  "faction": "Red",   "x": 4, "y": 5},
    {"type": "Horse",    "faction": "Red",   "x": 3, "y": 4},
    {"type": "General",  "faction": "Black", "x": 4, "y": 0},
    {"type": "Advisor",  "faction": "Black", "x": 3, "y": 1},
    {"type": "Chariot",  "faction": "Black", "x": 8, "y": 0},
], 2))
puzzles.append(make_endgame(5, "Mã nhảy chiếu", [
    {"type": "General",  "faction": "Red",   "x": 4, "y": 9},
    {"type": "Horse",    "faction": "Red",   "x": 4, "y": 3},
    {"type": "Chariot",  "faction": "Red",   "x": 3, "y": 0},
    {"type": "Cannon",   "faction": "Red",   "x": 4, "y": 7},
    {"type": "General",  "faction": "Black", "x": 4, "y": 0},
    {"type": "Advisor",  "faction": "Black", "x": 3, "y": 0},
    {"type": "Soldier",  "faction": "Black", "x": 5, "y": 1},
], 3))

# Levels 6-10: Tàn cục (endgame with more pieces)
puzzles.append(make_endgame(6, "Tàn cục – Xe Mã thắng", [
    {"type": "General",  "faction": "Red",   "x": 4, "y": 9},
    {"type": "Advisor",  "faction": "Red",   "x": 3, "y": 9},
    {"type": "Chariot",  "faction": "Red",   "x": 0, "y": 5},
    {"type": "Horse",    "faction": "Red",   "x": 5, "y": 4},
    {"type": "General",  "faction": "Black", "x": 4, "y": 0},
    {"type": "Advisor",  "faction": "Black", "x": 3, "y": 0},
    {"type": "Advisor",  "faction": "Black", "x": 5, "y": 0},
    {"type": "Chariot",  "faction": "Black", "x": 8, "y": 3},
    {"type": "Cannon",   "faction": "Black", "x": 2, "y": 4},
], 4))
puzzles.append(make_endgame(7, "Pháo Xe vây hãm", [
    {"type": "General",  "faction": "Red",   "x": 4, "y": 9},
    {"type": "Cannon",   "faction": "Red",   "x": 4, "y": 4},
    {"type": "Chariot",  "faction": "Red",   "x": 7, "y": 6},
    {"type": "Advisor",  "faction": "Red",   "x": 5, "y": 9},
    {"type": "General",  "faction": "Black", "x": 4, "y": 0},
    {"type": "Advisor",  "faction": "Black", "x": 3, "y": 1},
    {"type": "Advisor",  "faction": "Black", "x": 5, "y": 1},
    {"type": "Chariot",  "faction": "Black", "x": 1, "y": 0},
    {"type": "Cannon",   "faction": "Black", "x": 7, "y": 2},
    {"type": "Soldier",  "faction": "Black", "x": 4, "y": 5},
], 4))
puzzles.append(make_endgame(8, "Đơn Xe chiếu bí", [
    {"type": "General",  "faction": "Red",   "x": 3, "y": 9},
    {"type": "Advisor",  "faction": "Red",   "x": 3, "y": 8},
    {"type": "Advisor",  "faction": "Red",   "x": 4, "y": 9},
    {"type": "Chariot",  "faction": "Red",   "x": 4, "y": 2},
    {"type": "Cannon",   "faction": "Red",   "x": 4, "y": 5},
    {"type": "General",  "faction": "Black", "x": 4, "y": 0},
    {"type": "Advisor",  "faction": "Black", "x": 3, "y": 0},
    {"type": "Advisor",  "faction": "Black", "x": 5, "y": 0},
    {"type": "Chariot",  "faction": "Black", "x": 0, "y": 0},
    {"type": "Horse",    "faction": "Black", "x": 1, "y": 2},
], 5))
puzzles.append(make_endgame(9, "Mã kế song phi", [
    {"type": "General",  "faction": "Red",   "x": 4, "y": 9},
    {"type": "Horse",    "faction": "Red",   "x": 3, "y": 4},
    {"type": "Horse",    "faction": "Red",   "x": 5, "y": 4},
    {"type": "Chariot",  "faction": "Red",   "x": 4, "y": 5},
    {"type": "Advisor",  "faction": "Red",   "x": 5, "y": 8},
    {"type": "General",  "faction": "Black", "x": 4, "y": 0},
    {"type": "Advisor",  "faction": "Black", "x": 3, "y": 0},
    {"type": "Advisor",  "faction": "Black", "x": 5, "y": 0},
    {"type": "Chariot",  "faction": "Black", "x": 0, "y": 0},
    {"type": "Chariot",  "faction": "Black", "x": 8, "y": 0},
    {"type": "Cannon",   "faction": "Black", "x": 1, "y": 2},
], 6))
puzzles.append(make_endgame(10, "Ba Xe vây hãm", [
    {"type": "General",  "faction": "Red",   "x": 4, "y": 9},
    {"type": "Chariot",  "faction": "Red",   "x": 3, "y": 5},
    {"type": "Chariot",  "faction": "Red",   "x": 5, "y": 5},
    {"type": "Cannon",   "faction": "Red",   "x": 4, "y": 7},
    {"type": "Advisor",  "faction": "Red",   "x": 3, "y": 9},
    {"type": "General",  "faction": "Black", "x": 4, "y": 0},
    {"type": "Advisor",  "faction": "Black", "x": 3, "y": 1},
    {"type": "Advisor",  "faction": "Black", "x": 5, "y": 1},
    {"type": "Elephant", "faction": "Black", "x": 4, "y": 2},
    {"type": "Chariot",  "faction": "Black", "x": 2, "y": 0},
], 7))

# Levels 11-50: Full game, AI scales from 7 to 47
for i in range(11, 51):
    ai_level = 6 + (i - 10)
    desc = f"Ván cờ đầy đủ – Level {i}"
    puzzles.append(make_full(i, desc, ai_level))

out_path = r"c:\Users\h_u_n\.gemini\antigravity\scratch\banh-mi-exe\data\xiangqi_puzzles.json"
with open(out_path, "w", encoding="utf-8") as f:
    json.dump(puzzles, f, ensure_ascii=False, indent=2)
print(f"OK: Generated {len(puzzles)} puzzles to {out_path}")
