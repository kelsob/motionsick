extends Node

# === GAMEPLAY UI MANAGER ===
# Autoload singleton that manages global gameplay UI across all levels
# Shows/hides UI based on game state (menus vs gameplay)

## === EXPORTED CONFIGURATION ===
@export_group("UI Scene Paths")
## Path to gameplay UI scene
@export var gameplay_ui_scene: String = "res://scenes/ui/GameplayUI.tscn"
## Path to death screen scene
@export var death_screen_scene: String = "res://scenes/ui/DeathScreen.tscn"
## Path to victory screen scene
@export var victory_screen_scene: String = "res://scenes/ui/VictoryScreen.tscn"

@export_group("UI State Management")
## Show UI immediately when entering gameplay
@export var auto_show_on_gameplay: bool = true
## Hide UI when in menus
@export var auto_hide_in_menus: bool = true

@export_group("Debug Settings")
## Enable debug output for UI state changes
@export var debug_ui_state: bool = false
## Enable debug output for UI loading
@export var debug_ui_loading: bool = false

## === RUNTIME STATE ===
# UI instances
var gameplay_ui_instance: CanvasLayer = null
var death_screen_instance: Control = null
var victory_screen_instance: Control = null
# Current state
var is_ui_active: bool = false
var is_in_gameplay: bool = false

# === SIGNALS ===
signal gameplay_ui_loaded()
signal gameplay_ui_activated()
signal gameplay_ui_deactivated()

func _ready():
	# Connect to GameManager for state changes
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		# We'll connect to game state changes when they're available
		if debug_ui_loading:
			print("GameplayUIManager: Connected to GameManager")
	
	if debug_ui_loading:
		print("GameplayUIManager: Initialized")

func activate_gameplay_ui():
	"""Activate gameplay UI when entering a level."""
	if is_ui_active:
		if debug_ui_state:
			print("GameplayUIManager: UI already active")
		return
	
	if debug_ui_state:
		print("GameplayUIManager: Activating gameplay UI")
	
	# Always reload death screen to ensure fresh connections
	if death_screen_instance:
		death_screen_instance.queue_free()
		death_screen_instance = null
	
	# Always reload victory screen to ensure fresh connections
	if victory_screen_instance:
		victory_screen_instance.queue_free()
		victory_screen_instance = null
	
	# Always reload gameplay UI to ensure fresh connections (especially for ammo indicator)
	if gameplay_ui_instance:
		gameplay_ui_instance.queue_free()
		gameplay_ui_instance = null
	
	# Load gameplay UI
	_load_gameplay_ui()
	
	# Load death screen (always reload for fresh connections)
	_load_death_screen()
	
	# Load victory screen (always reload for fresh connections)
	_load_victory_screen()
	
	# Show the UI
	if gameplay_ui_instance:
		gameplay_ui_instance.visible = true
	
	# Hide death screen initially
	if death_screen_instance:
		death_screen_instance.visible = false
	
	# Hide victory screen initially
	if victory_screen_instance:
		victory_screen_instance.visible = false
	
	is_ui_active = true
	is_in_gameplay = true
	gameplay_ui_activated.emit()

func deactivate_gameplay_ui():
	"""Deactivate gameplay UI when returning to menus."""
	if not is_ui_active:
		if debug_ui_state:
			print("GameplayUIManager: UI already inactive")
		return
	
	if debug_ui_state:
		print("GameplayUIManager: Deactivating gameplay UI")
	
	# Hide the UI
	if gameplay_ui_instance:
		gameplay_ui_instance.visible = false
	
	if death_screen_instance:
		death_screen_instance.visible = false
	
	if victory_screen_instance:
		victory_screen_instance.visible = false
	
	is_ui_active = false
	is_in_gameplay = false
	gameplay_ui_deactivated.emit()

func show_death_screen():
	"""Show the death screen."""
	if death_screen_instance:
		death_screen_instance.visible = true
		if debug_ui_state:
			print("GameplayUIManager: Death screen shown")

func hide_death_screen():
	"""Hide the death screen."""
	if death_screen_instance:
		death_screen_instance.visible = false
		if debug_ui_state:
			print("GameplayUIManager: Death screen hidden")

func show_victory_screen():
	"""Show the victory screen."""
	if victory_screen_instance:
		victory_screen_instance.visible = true
		if debug_ui_state:
			print("GameplayUIManager: Victory screen shown")

func hide_victory_screen():
	"""Hide the victory screen."""
	if victory_screen_instance:
		victory_screen_instance.visible = false
		if debug_ui_state:
			print("GameplayUIManager: Victory screen hidden")

func _load_gameplay_ui():
	"""Load the gameplay UI scene."""
	var ui_scene = load(gameplay_ui_scene)
	if ui_scene:
		gameplay_ui_instance = ui_scene.instantiate()
		get_tree().root.add_child(gameplay_ui_instance)
		# Start hidden
		gameplay_ui_instance.visible = false
		
		if debug_ui_loading:
			print("GameplayUIManager: Gameplay UI loaded")
		gameplay_ui_loaded.emit()
	else:
		if debug_ui_loading:
			print("GameplayUIManager: Failed to load gameplay UI scene: ", gameplay_ui_scene)

func _load_death_screen():
	"""Load the death screen scene."""
	var death_scene = load(death_screen_scene)
	if death_scene:
		death_screen_instance = death_scene.instantiate()
		get_tree().root.add_child(death_screen_instance)
		# Start hidden
		death_screen_instance.visible = false
		
		# Connect to GameManager for death screen functionality
		_connect_death_screen()
		
		if debug_ui_loading:
			print("GameplayUIManager: Death screen loaded")
	else:
		if debug_ui_loading:
			print("GameplayUIManager: Failed to load death screen scene: ", death_screen_scene)

func _connect_death_screen():
	"""Connect death screen to GameManager signals."""
	if not death_screen_instance:
		return
	
	var game_manager = get_node_or_null("/root/GameManager")
	if not game_manager:
		return
	
	# Connect restart button
	var restart_button = death_screen_instance.get_node_or_null("VBoxContainer/RestartButton")
	if restart_button:
		restart_button.pressed.connect(game_manager._on_restart_button_pressed)
		if debug_ui_loading:
			print("GameplayUIManager: Connected restart button")
	
	# Connect main menu button
	var main_menu_button = death_screen_instance.get_node_or_null("VBoxContainer/MainMenuButton")
	if main_menu_button:
		main_menu_button.pressed.connect(game_manager._on_main_menu_button_pressed)
		if debug_ui_loading:
			print("GameplayUIManager: Connected main menu button")
	
	# The death screen will connect to GameManager signals in its own _ready() function
	if debug_ui_loading:
		print("GameplayUIManager: Death screen connections complete")

func _load_victory_screen():
	"""Load the victory screen scene."""
	var victory_scene = load(victory_screen_scene)
	if victory_scene:
		victory_screen_instance = victory_scene.instantiate()
		get_tree().root.add_child(victory_screen_instance)
		# Start hidden
		victory_screen_instance.visible = false
		
		# Connect to GameManager for victory screen functionality
		_connect_victory_screen()
		
		if debug_ui_loading:
			print("GameplayUIManager: Victory screen loaded")
	else:
		if debug_ui_loading:
			print("GameplayUIManager: Failed to load victory screen scene: ", victory_screen_scene)

func _connect_victory_screen():
	"""Connect victory screen to GameManager signals."""
	if not victory_screen_instance:
		return
	
	var game_manager = get_node_or_null("/root/GameManager")
	if not game_manager:
		return
	
	# The victory screen will connect to GameManager signals in its own _ready() function
	if debug_ui_loading:
		print("GameplayUIManager: Victory screen connections complete")

func cleanup_ui():
	"""Clean up UI instances (for scene changes)."""
	if gameplay_ui_instance:
		gameplay_ui_instance.queue_free()
		gameplay_ui_instance = null
	
	if death_screen_instance:
		death_screen_instance.queue_free()
		death_screen_instance = null
	
	if victory_screen_instance:
		victory_screen_instance.queue_free()
		victory_screen_instance = null
	
	is_ui_active = false
	is_in_gameplay = false
	
	if debug_ui_loading:
		print("GameplayUIManager: UI cleaned up")

# === PUBLIC API ===

func is_gameplay_ui_active() -> bool:
	"""Check if gameplay UI is currently active."""
	return is_ui_active

func is_currently_in_gameplay() -> bool:
	"""Check if currently in gameplay mode."""
	return is_in_gameplay

func get_gameplay_ui() -> CanvasLayer:
	"""Get reference to gameplay UI instance."""
	return gameplay_ui_instance

func get_death_screen() -> Control:
	"""Get reference to death screen instance."""
	return death_screen_instance

func get_victory_screen() -> Control:
	"""Get reference to victory screen instance."""
	return victory_screen_instance

func force_reload_ui():
	"""Force reload of all UI (useful for testing)."""
	cleanup_ui()
	if is_in_gameplay:
		activate_gameplay_ui()

# === DEBUG ===

func print_ui_status():
	"""Debug function to print UI manager status."""
	print("\n=== GAMEPLAY UI MANAGER STATUS ===")
	print("UI Active: ", is_ui_active)
	print("In Gameplay: ", is_in_gameplay)
	print("Gameplay UI Instance: ", "Loaded" if gameplay_ui_instance else "Not Loaded")
	print("Death Screen Instance: ", "Loaded" if death_screen_instance else "Not Loaded")
	print("Victory Screen Instance: ", "Loaded" if victory_screen_instance else "Not Loaded")
	if gameplay_ui_instance:
		print("Gameplay UI Visible: ", gameplay_ui_instance.visible)
	if death_screen_instance:
		print("Death Screen Visible: ", death_screen_instance.visible)
	if victory_screen_instance:
		print("Victory Screen Visible: ", victory_screen_instance.visible)
	print("===================================\n")
