extends Node

# === SCORE MANAGER ===
# Autoload singleton that manages scoring for the horde survival game

# === SCORE VALUES ===
# Different enemy types yield different scores
var enemy_scores: Dictionary = {
	"Grunt": 10,
	"Sniper": 25,
	"Flanker": 15,
	"Rusher": 20,
	"Artillery": 50
}

# === STATE ===
var current_score: int = 0
var high_score: int = 0

# === SIGNALS ===
signal score_changed(new_score: int)
signal high_score_updated(new_high_score: int)

func _ready():
	print("ScoreManager initialized")
	
	# Load high score from save file
	_load_high_score()
	
	# Connect to GameManager for restart events
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.game_restart_requested.connect(_on_game_restart_requested)
		print("ScoreManager connected to GameManager")
	else:
		print("WARNING: ScoreManager can't find GameManager")

func add_score(enemy_type: String):
	"""Add score for killing an enemy of the specified type."""
	var score_to_add = enemy_scores.get(enemy_type, 10)  # Default to 10 if enemy type not found
	current_score += score_to_add
	
	print("ScoreManager: Added ", score_to_add, " points for killing ", enemy_type, " (Total: ", current_score, ")")
	
	# Check if this is a new high score
	if current_score > high_score:
		high_score = current_score
		_save_high_score()
		high_score_updated.emit(high_score)
		print("ScoreManager: New high score! ", high_score)
	
	score_changed.emit(current_score)

func reset_score():
	"""Reset current score to 0 (called when player dies)."""
	current_score = 0
	score_changed.emit(current_score)
	print("ScoreManager: Score reset to 0")

func get_current_score() -> int:
	"""Get the current score."""
	return current_score

func get_high_score() -> int:
	"""Get the high score."""
	return high_score

func _on_game_restart_requested():
	"""Called when game is restarting - reset current score."""
	reset_score()

func _save_high_score():
	"""Save high score to a file."""
	var save_file = FileAccess.open("user://highscore.save", FileAccess.WRITE)
	if save_file:
		save_file.store_var(high_score)
		save_file.close()
		print("ScoreManager: High score saved: ", high_score)

func _load_high_score():
	"""Load high score from file."""
	if FileAccess.file_exists("user://highscore.save"):
		var save_file = FileAccess.open("user://highscore.save", FileAccess.READ)
		if save_file:
			high_score = save_file.get_var()
			save_file.close()
			print("ScoreManager: High score loaded: ", high_score)
		else:
			print("ScoreManager: Failed to load high score file")
	else:
		print("ScoreManager: No high score file found, starting fresh")
