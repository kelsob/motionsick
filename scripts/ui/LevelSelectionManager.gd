extends Control

# === LEVEL SELECTION MENU MANAGER ===
# Handles level selection UI and integrates with LevelManager

## === EXPORTED CONFIGURATION ===
@export_group("Scene References")
## Level button scene to instantiate for each level
@export var level_button_scene: PackedScene = preload("res://scenes/UI/LevelButton.tscn")
## Path to main menu scene
@export var main_menu_scene: String = "res://scenes/ui/MainMenu.tscn"

@export_group("Animation Settings")
## Enable level selection animations
@export var enable_animations: bool = true
## Fade transition duration
@export var fade_duration: float = 0.3

@export_group("Debug Settings")
## Enable debug output for level selection events
@export var debug_selection: bool = false
## Enable debug output for UI population
@export var debug_ui_population: bool = false
## Enable debug output for scene transitions
@export var debug_transitions: bool = false

## === RUNTIME STATE ===
# UI references
@onready var level_grid: GridContainer = $VBoxContainer/LevelGrid
@onready var back_button: Button = $VBoxContainer/BackButton

# Level data singleton reference
var level_data_manager: Node = null

func _ready():
	# Get LevelManager autoload singleton reference
	level_data_manager = get_node_or_null("/root/LevelManager")
	if not level_data_manager:
		if debug_selection:
			print("LevelSelectionManager: WARNING - LevelManager autoload not found!")
		return
	
	# Setup UI
	_setup_ui()
	
	# Populate level grid
	_populate_levels()
	
	# Setup mouse mode
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if debug_selection:
		print("LevelSelectionManager: Level selection menu ready")

func _setup_ui():
	"""Find and connect UI elements."""
	back_button.pressed.connect(_on_back_pressed)

func _populate_levels():
	"""Populate the level grid with available levels."""
	if not level_data_manager or not level_grid or not level_button_scene:
		print("level,", level_data_manager, level_grid, level_button_scene )
		if debug_ui_population:
			print("LevelSelectionManager: Missing required components for level population")
		return
	
	if debug_ui_population:
		print("LevelSelectionManager: Populating level grid")
	
	# Let LevelManager autoload populate the grid with your level button scene
	level_data_manager.populate_level_grid(level_grid, level_button_scene)
	
	# Connect to level selection signal
	if not level_data_manager.level_selected.is_connected(_on_level_selected):
		level_data_manager.level_selected.connect(_on_level_selected)

func _on_level_selected(level_data):
	"""Handle level selection."""
	if debug_selection:
		print("LevelSelectionManager: Level selected: ", level_data.display_name)
	
	# Load the selected level immediately - no fade animations
	var load_success = await level_data_manager.load_selected_level()
	if load_success:
		if debug_transitions:
			print("LevelSelectionManager: Successfully loaded level")
	else:
		if debug_transitions:
			print("LevelSelectionManager: Failed to load level")

func _on_back_pressed():
	"""Handle back button press."""
	if debug_selection:
		print("LevelSelectionManager: Back to main menu")
	
	_transition_to_main_menu()

func _transition_to_main_menu():
	"""Transition back to main menu immediately."""
	if debug_transitions:
		print("LevelSelectionManager: Returning to main menu")
	
	# Change scene immediately - no fade animations
	var error = get_tree().change_scene_to_file(main_menu_scene)
	if error != OK:
		if debug_transitions:
			print("LevelSelectionManager: Failed to load main menu: ", error)

func refresh_level_grid():
	"""Refresh the level grid (useful if levels are added/removed dynamically)."""
	if level_data_manager and level_grid and level_button_scene:
		if debug_ui_population:
			print("LevelSelectionManager: Refreshing level grid")
		level_data_manager.populate_level_grid(level_grid, level_button_scene)

# === PUBLIC API ===

func add_custom_level_button(level_data, custom_button: Control):
	"""Add a custom level button to the grid."""
	if level_grid:
		level_grid.add_child(custom_button)

func set_level_grid_columns(columns: int):
	"""Set the number of columns in the level grid."""
	if level_grid:
		level_grid.columns = columns

# === DEBUG ===

func print_ui_status():
	"""Debug function to print UI connection status."""
	print("\n=== LEVEL SELECTION UI STATUS ===")
	print("Level grid: ", "Found" if level_grid else "Missing")
	print("Back button: ", "Found" if back_button else "Missing")
	print("Level data manager: ", "Found" if level_data_manager else "Missing")
	if level_grid:
		print("Level buttons: ", level_grid.get_child_count())
	print("==================================\n")
