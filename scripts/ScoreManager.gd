extends Node

# === SCORE MANAGER ===
# Autoload singleton that manages scoring for the horde survival game

## === EXPORTED CONFIGURATION ===
@export_group("Enemy Score Values")
## Score for killing Grunt enemies
@export var grunt_score: int = 10
## Score for killing Sniper enemies
@export var sniper_score: int = 25
## Score for killing Flanker enemies
@export var flanker_score: int = 15
## Score for killing Rusher enemies
@export var rusher_score: int = 20
## Score for killing Artillery enemies
@export var artillery_score: int = 50
## Default score for unknown enemy types
@export var default_enemy_score: int = 10

@export_group("Save System")
## Filename for high score save file
@export var save_filename: String = "user://highscore.save"

@export_group("Debug Settings")
## Enable debug output for score events
@export var debug_scoring: bool = false
## Enable debug output for high score system
@export var debug_high_score: bool = false
## Enable debug output for save/load operations
@export var debug_save_load: bool = false
## Enable debug output for system initialization
@export var debug_initialization: bool = false

## === RUNTIME STATE ===
# Score values dictionary (built from exports)
var enemy_scores: Dictionary = {}
# Current game state
var current_score: int = 0
var high_score: int = 0

# === SIGNALS ===
signal score_changed(new_score: int)
signal high_score_updated(new_high_score: int)

func _ready():
	# Build enemy scores dictionary from exported values
	enemy_scores = {
		"Grunt": grunt_score,
		"Sniper": sniper_score,
		"Flanker": flanker_score,
		"Rusher": rusher_score,
		"Artillery": artillery_score
	}
	
	if debug_initialization:
		print("ScoreManager initialized")
	
	# Load high score from save file
	_load_high_score()
	
	# Connect to GameManager for restart events
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.game_restart_requested.connect(_on_game_restart_requested)
		if debug_initialization:
			print("ScoreManager connected to GameManager")
	else:
		if debug_initialization:
			print("WARNING: ScoreManager can't find GameManager")

func add_score(enemy_type: String):
	"""Add score for killing an enemy of the specified type."""
	var score_to_add = enemy_scores.get(enemy_type, default_enemy_score)
	current_score += score_to_add
	
	if debug_scoring:
		print("ScoreManager: Added ", score_to_add, " points for killing ", enemy_type, " (Total: ", current_score, ")")
	
	# Check if this is a new high score
	if current_score > high_score:
		high_score = current_score
		_save_high_score()
		high_score_updated.emit(high_score)
		if debug_high_score:
			print("ScoreManager: New high score! ", high_score)
	
	score_changed.emit(current_score)

func reset_score():
	"""Reset current score to 0 (called when player dies)."""
	current_score = 0
	score_changed.emit(current_score)
	if debug_scoring:
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
	var save_file = FileAccess.open(save_filename, FileAccess.WRITE)
	if save_file:
		save_file.store_var(high_score)
		save_file.close()
		if debug_save_load:
			print("ScoreManager: High score saved: ", high_score)

func _load_high_score():
	"""Load high score from file."""
	if FileAccess.file_exists(save_filename):
		var save_file = FileAccess.open(save_filename, FileAccess.READ)
		if save_file:
			high_score = save_file.get_var()
			save_file.close()
			if debug_save_load:
				print("ScoreManager: High score loaded: ", high_score)
		else:
			if debug_save_load:
				print("ScoreManager: Failed to load high score file")
	else:
		if debug_save_load:
			print("ScoreManager: No high score file found, starting fresh")
