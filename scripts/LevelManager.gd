extends Node

# === LEVEL MANAGEMENT SYSTEM ===
# Autoload singleton that manages level data, progression, and loading
# Handles dynamic level list population and level selection logic

## === EXPORTED CONFIGURATION ===
@export_group("Level System")
## Enable level progression (levels must be unlocked in order)
@export var enable_level_progression: bool = false
## Save file for level progression data
@export var progression_save_file: String = "user://level_progress.save"


@export_group("Debug Settings")
## Enable debug output for level loading
@export var debug_loading: bool = false
## Enable debug output for level progression
@export var debug_progression: bool = false
## Enable debug output for UI population
@export var debug_ui: bool = false

## === LEVEL DATA STRUCTURE ===
class LevelData:
	var id: String
	var display_name: String
	var scene_path: String
	var description: String
	var preview_texture: Texture2D
	var is_unlocked: bool = true
	var best_score: int = 0
	var best_time: float = 0.0
	var difficulty: int = 1
	
	func _init(level_id: String, name: String, path: String, desc: String = "", texture: Texture2D = null):
		id = level_id
		display_name = name
		scene_path = path
		description = desc
		preview_texture = texture

## === RUNTIME STATE ===
# Available levels (configured in _ready)
var available_levels: Array[LevelData] = []
# Currently selected level
var current_level: LevelData = null
# Level progression data
var progression_data: Dictionary = {}

# === SIGNALS ===
signal level_selected(level_data: LevelData)
signal level_unlocked(level_id: String)
signal progression_updated()

func _ready():
	# Initialize level data
	_setup_levels()
	
	# Load progression data
	_load_progression()
	
	if debug_loading:
		print("LevelManager initialized with ", available_levels.size(), " levels")

func _setup_levels():
	"""Initialize the available levels list."""
	available_levels.clear()
	
	# Define available levels (easily expandable)
	available_levels.append(LevelData.new(
		"arena",
		"Arena Survival", 
		"res://scenes/levels/Arena.tscn",
		"Survive waves of enemies in the arena. Test your movement and combat skills.",
		preload("res://assets/levels/icons/level-icon-test.png")
	))
	
	# Future levels can be added here:
	# available_levels.append(LevelData.new(
	#     "snipers_nest",
	#     "Sniper's Nest",
	#     "res://scenes/levels/SnipersNest.tscn",
	#     "Long-range combat in a sniper-focused environment.",
	#     null
	# ))
	
	if debug_loading:
		print("LevelManager: Configured ", available_levels.size(), " levels")
		for level in available_levels:
			print("  - ", level.display_name, " (", level.id, ")")

func populate_level_grid(grid_container: GridContainer, level_button_scene: PackedScene):
	"""Populate the level grid with level button scenes."""
	if not grid_container:
		if debug_ui:
			print("LevelManager: No grid container provided")
		return
	
	if not level_button_scene:
		if debug_ui:
			print("LevelManager: No level button scene provided")
		return
	
	# Clear existing children
	for child in grid_container.get_children():
		child.queue_free()
	
	if debug_ui:
		print("LevelManager: Populating level grid with ", available_levels.size(), " levels")
	
	# Create button scene for each level
	for level_data in available_levels:
		# Instantiate your level button scene
		var level_button_instance = level_button_scene.instantiate()
		grid_container.add_child(level_button_instance)
		
		# Setup the level button with data
		if level_button_instance.has_method("setup_level"):
			level_button_instance.setup_level(level_data)
		
		# Connect the level button's custom signal
		if level_button_instance.has_signal("level_button_pressed"):
			level_button_instance.level_button_pressed.connect(_on_level_button_pressed)
		
		if debug_ui:
			print("LevelManager: Added level button for: ", level_data.display_name)

func _on_level_button_pressed(level_data: LevelData):
	"""Called when a level button is pressed."""
	if not _is_level_unlocked(level_data.id):
		if debug_ui:
			print("LevelManager: Level ", level_data.display_name, " is locked")
		return
	
	current_level = level_data
	level_selected.emit(level_data)
	
	if debug_loading:
		print("LevelManager: Level selected: ", level_data.display_name, " (", level_data.scene_path, ")")

func load_selected_level():
	"""Load the currently selected level."""
	if not current_level:
		if debug_loading:
			print("LevelManager: No level selected")
		return false
	
	if debug_loading:
		print("LevelManager: Loading level: ", current_level.display_name)
	
	# Load the level scene first
	var error = get_tree().change_scene_to_file(current_level.scene_path)
	if error != OK:
		if debug_loading:
			print("LevelManager: Failed to load level: ", current_level.scene_path, " Error: ", error)
		return false
	
	# Wait for level to be fully loaded, then activate systems
	await get_tree().process_frame
	await get_tree().process_frame  # Wait extra frame to ensure everything is ready
	_activate_gameplay_systems()
	
	return true

func _activate_gameplay_systems():
	"""Activate all gameplay systems when entering a level."""
	if debug_loading:
		print("LevelManager: Activating gameplay systems")
	
	# First activate TimeManager (so it finds the player)
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager and time_manager.has_method("activate_for_gameplay"):
		time_manager.activate_for_gameplay()
	
	# Wait a frame for TimeManager to find player
	await get_tree().process_frame
	
	# Then activate gameplay UI (so UI can find player that TimeManager found)
	var ui_manager = get_node_or_null("/root/GameplayUIManager")
	if ui_manager and ui_manager.has_method("activate_gameplay_ui"):
		ui_manager.activate_gameplay_ui()
	
	# Reset ArenaSpawnManager for new level
	var arena_spawn_manager = get_node_or_null("/root/ArenaSpawnManager")
	if arena_spawn_manager and arena_spawn_manager.has_method("reset_for_level"):
		arena_spawn_manager.reset_for_level()

func deactivate_gameplay_systems():
	"""Deactivate gameplay systems when returning to menus."""
	if debug_loading:
		print("LevelManager: Deactivating gameplay systems")
	
	# Deactivate gameplay UI
	var ui_manager = get_node_or_null("/root/GameplayUIManager")
	if ui_manager and ui_manager.has_method("deactivate_gameplay_ui"):
		ui_manager.deactivate_gameplay_ui()
	
	# Deactivate TimeManager
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager and time_manager.has_method("deactivate_for_menus"):
		time_manager.deactivate_for_menus()
	
	# Stop ArenaSpawnManager
	var arena_spawn_manager = get_node_or_null("/root/ArenaSpawnManager")
	if arena_spawn_manager and arena_spawn_manager.has_method("stop_spawning"):
		arena_spawn_manager.stop_spawning()

func _is_level_unlocked(level_id: String) -> bool:
	"""Check if a level is unlocked."""
	if not enable_level_progression:
		return true  # All levels unlocked if progression disabled
	
	return progression_data.get(level_id + "_unlocked", level_id == "arena")  # Arena always unlocked

func unlock_level(level_id: String):
	"""Unlock a specific level."""
	if progression_data.get(level_id + "_unlocked", false):
		return  # Already unlocked
	
	progression_data[level_id + "_unlocked"] = true
	_save_progression()
	level_unlocked.emit(level_id)
	
	if debug_progression:
		print("LevelManager: Unlocked level: ", level_id)

func update_level_score(level_id: String, score: int):
	"""Update best score for a level."""
	var current_best = progression_data.get(level_id + "_best_score", 0)
	if score > current_best:
		progression_data[level_id + "_best_score"] = score
		_save_progression()
		progression_updated.emit()
		
		if debug_progression:
			print("LevelManager: New best score for ", level_id, ": ", score)

func update_level_time(level_id: String, time: float):
	"""Update best time for a level."""
	var current_best = progression_data.get(level_id + "_best_time", 999999.0)
	if time < current_best:
		progression_data[level_id + "_best_time"] = time
		_save_progression()
		progression_updated.emit()
		
		if debug_progression:
			print("LevelManager: New best time for ", level_id, ": ", "%.1f" % time, "s")

func _save_progression():
	"""Save level progression data."""
	var save_file = FileAccess.open(progression_save_file, FileAccess.WRITE)
	if save_file:
		save_file.store_var(progression_data)
		save_file.close()
		if debug_progression:
			print("LevelManager: Progression saved")

func _load_progression():
	"""Load level progression data."""
	if FileAccess.file_exists(progression_save_file):
		var save_file = FileAccess.open(progression_save_file, FileAccess.READ)
		if save_file:
			progression_data = save_file.get_var()
			save_file.close()
			if debug_progression:
				print("LevelManager: Progression loaded")
		else:
			if debug_progression:
				print("LevelManager: Failed to load progression file")
	else:
		if debug_progression:
			print("LevelManager: No progression file found, starting fresh")

# === PUBLIC API ===

func get_available_levels() -> Array[LevelData]:
	"""Get list of all available levels."""
	return available_levels

func get_level_by_id(level_id: String) -> LevelData:
	"""Get level data by ID."""
	for level in available_levels:
		if level.id == level_id:
			return level
	return null

func get_current_level() -> LevelData:
	"""Get currently selected level."""
	return current_level

func add_level(level_data: LevelData):
	"""Add a new level to the available levels list."""
	available_levels.append(level_data)
	if debug_loading:
		print("LevelManager: Added level: ", level_data.display_name)

func remove_level(level_id: String):
	"""Remove a level from the available levels list."""
	for i in range(available_levels.size()):
		if available_levels[i].id == level_id:
			available_levels.remove_at(i)
			if debug_loading:
				print("LevelManager: Removed level: ", level_id)
			break

func get_level_stats(level_id: String) -> Dictionary:
	"""Get stats for a specific level."""
	return {
		"unlocked": _is_level_unlocked(level_id),
		"best_score": progression_data.get(level_id + "_best_score", 0),
		"best_time": progression_data.get(level_id + "_best_time", 0.0)
	}

# === DEBUG ===

func print_level_status():
	"""Debug function to print all level information."""
	print("\n=== LEVEL MANAGER STATUS ===")
	print("Available levels: ", available_levels.size())
	print("Current level: ", current_level.display_name if current_level else "None")
	print("Progression enabled: ", enable_level_progression)
	print("\nLevel Details:")
	for level in available_levels:
		var stats = get_level_stats(level.id)
		print("  ", level.display_name, " (", level.id, ")")
		print("    Unlocked: ", stats.unlocked)
		print("    Best Score: ", stats.best_score)
		print("    Best Time: ", "%.1f" % stats.best_time, "s")
	print("============================\n")
