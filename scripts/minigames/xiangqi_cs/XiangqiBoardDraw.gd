## XiangqiBoardDraw.gd
## Draws the Xiangqi board (9x10 grid, palace, river) procedurally in _draw().
## Attach this to the "Board" Control node (child of BoardContainer).
extends Control

const COLS := 9
const ROWS := 10
const MARGIN := 40.0
const CELL := 62.0

const LINE_W := 1.5
const LINE_COLOR := Color(0.22, 0.13, 0.04, 1.0)
const BG_COLOR   := Color(0.91, 0.76, 0.45, 1.0)
const RIVER_COLOR := Color(0.85, 0.71, 0.40, 1.0)

func _draw() -> void:
	# Background
	draw_rect(Rect2(Vector2.ZERO, size), BG_COLOR, true)

	# Outer border
	var bx := MARGIN - 10
	var by := MARGIN - 10
	var bw := (COLS - 1) * CELL + 20
	var bh := (ROWS - 1) * CELL + 20
	draw_rect(Rect2(bx, by, bw, bh), LINE_COLOR, false, 3)

	# River shading
	var ry := MARGIN + 4 * CELL
	draw_rect(Rect2(MARGIN, ry + 2, (COLS - 1) * CELL, CELL - 4), RIVER_COLOR, true)

	# Horizontal grid lines
	for row in range(ROWS):
		var y := MARGIN + row * CELL
		if row == 5:
			continue  # Skip split river row
		draw_line(Vector2(MARGIN, y), Vector2(MARGIN + (COLS - 1) * CELL, y), LINE_COLOR, LINE_W)

	# Vertical grid lines — inner columns stop at river boundary; edge cols go full length
	for col in range(COLS):
		var x := MARGIN + col * CELL
		if col == 0 or col == COLS - 1:
			draw_line(Vector2(x, MARGIN), Vector2(x, MARGIN + (ROWS - 1) * CELL), LINE_COLOR, LINE_W)
		else:
			draw_line(Vector2(x, MARGIN), Vector2(x, MARGIN + 4 * CELL), LINE_COLOR, LINE_W)
			draw_line(Vector2(x, MARGIN + 5 * CELL), Vector2(x, MARGIN + (ROWS - 1) * CELL), LINE_COLOR, LINE_W)

	# Draw river top and bottom border lines
	draw_line(Vector2(MARGIN, MARGIN + 4 * CELL), Vector2(MARGIN + (COLS-1) * CELL, MARGIN + 4 * CELL), LINE_COLOR, LINE_W)
	draw_line(Vector2(MARGIN, MARGIN + 5 * CELL), Vector2(MARGIN + (COLS-1) * CELL, MARGIN + 5 * CELL), LINE_COLOR, LINE_W)

	# Palace diagonals — Black (rows 0-2, cols 3-5)
	_draw_palace(3, 0)
	# Palace diagonals — Red (rows 7-9, cols 3-5)
	_draw_palace(3, 7)

func _draw_palace(col_start: int, row_start: int) -> void:
	var x1 := MARGIN + col_start * CELL
	var y1 := MARGIN + row_start * CELL
	var x2 := MARGIN + (col_start + 2) * CELL
	var y2 := MARGIN + (row_start + 2) * CELL
	draw_line(Vector2(x1, y1), Vector2(x2, y2), LINE_COLOR, LINE_W)
	draw_line(Vector2(x2, y1), Vector2(x1, y2), LINE_COLOR, LINE_W)
