extends Node

## tetris_data.gd
## Contains configuration for the 50 Tetris levels.

const MAX_LEVELS = 50

# Returns dictionary with level info
func get_level_data(level_id: int) -> Dictionary:
	# Calculate speed (max drop interval). Lower is faster.
	# Starts at 1.0s, drops 0.015s per level.
	var start_speed = clampf(1.0 - ((level_id - 1) * 0.018), 0.1, 1.0)
	
	# Lines to clear to finish the level:
	# Level 1-10: 10 lines
	# Level 11-20: 15 lines
	# Level 21-30: 20 lines
	# Level 31-40: 30 lines
	# Level 41-50: 40 lines
	var target_lines := 10
	if level_id > 40: target_lines = 40
	elif level_id > 30: target_lines = 30
	elif level_id > 20: target_lines = 20
	elif level_id > 10: target_lines = 15
	
	# Score targets for 1, 2, and 3 stars
	# Base scoring: 1 line = 100, 2 lines = 300, 3 lines = 500, 4 lines (Tetris) = 800
	var avg_score_per_line = 150 # Assuming a mix of singles and doubles
	var base_expected_score = target_lines * avg_score_per_line
	
	return {
		"speed": start_speed,
		"target_lines": target_lines,
		"star_1_score": int(base_expected_score * 0.7),
		"star_2_score": int(base_expected_score * 1.1),
		"star_3_score": int(base_expected_score * 1.5)
	}
