extends Node

# Game states
enum GameState {
	PLAYING,
	PLAYER_DEAD,
	PAUSED
}

## === EXPORTED CONFIGURATION ===
@export_group("Scene Paths")
## Path to player node in scene
@export var player_path: String = "/root/Arena/Player"
## Path to main scene node  
@export var main_scene_path: String = "/root/Arena"
## Path to death screen UI
@export var death_screen_path: String = "/root/Arena/UI/DeathScreen"

@export_group("Menu Integration")
## Path to main menu scene
@export var main_menu_scene: String = "res://scenes/ui/MainMenu.tscn"
## Path to level selection scene
@export var level_selection_scene: String = "res://scenes/ui/LevelSelection.tscn"

@export_group("Input Settings")
## Key code for restart input when dead
@export var restart_key: int = KEY_R
## Key code for returning to main menu when dead
@export var main_menu_key: int = KEY_M

@export_group("Debug Settings")
## Enable debug output for connection setup
@export var debug_connections: bool = false
## Enable debug output for state changes
@export var debug_state_changes: bool = false
## Enable debug output for restart system
@export var debug_restart: bool = false
## Enable debug output for player death events
@export var debug_death: bool = false

## === RUNTIME STATE ===
# Current game state
var current_state: GameState = GameState.PLAYING

# Signals
signal game_state_changed(new_state: GameState)
signal player_died
signal game_restart_requested

# References
var player: Node = null
var death_screen: Control = null
var main_scene: Node3D = null

func _ready():
	# Add to autoload group
	add_to_group("game_manager")
	
	# Wait a frame to ensure scene is loaded
	await get_tree().process_frame
	
	# Connect to scene tree to detect when nodes are added
	get_tree().node_added.connect(_on_node_added)
	
	# Initial setup
	_setup_connections()

func _setup_connections():
	"""Setup connections to player and death screen"""
	if debug_connections:
		print("GameManager: Setting up connections...")
	
	# Find player
	player = get_node_or_null(player_path)
	if player:
		if debug_connections:
			print("GameManager: Found player, connecting death signal")
		# Connect to player death signal
		if player.has_signal("player_died"):
			# Disconnect first to avoid duplicate connections
			if player.player_died.is_connected(_on_player_died):
				player.player_died.disconnect(_on_player_died)
			player.player_died.connect(_on_player_died)
			if debug_connections:
				print("GameManager: Successfully connected to player death signal")
		else:
			if debug_connections:
				print("Warning: Player doesn't have player_died signal")
	else:
		if debug_connections:
			print("GameManager: Player not found")
	
	# Find main scene
	main_scene = get_node_or_null(main_scene_path)
	
	# Death screen is now handled by GameplayUIManager - no need to find it here

func _on_node_added(node: Node):
	"""Called when a new node is added to the scene tree"""
	# Check if this is the player being added (death screen is now global)
	if str(node.get_path()) == player_path:
		if debug_connections:
			print("GameManager: Player node added, reconnecting signals")
		_setup_connections()

func _input(event):
	# Handle input when dead
	if current_state == GameState.PLAYER_DEAD:
		if event is InputEventKey and event.pressed:
			if event.keycode == restart_key:
				restart_game()
			elif event.keycode == main_menu_key:
				return_to_main_menu()

func change_game_state(new_state: GameState):
	if current_state == new_state:
		return
	
	current_state = new_state
	game_state_changed.emit(new_state)
	
	match new_state:
		GameState.PLAYING:
			_handle_playing_state()
		GameState.PLAYER_DEAD:
			_handle_player_dead_state()
		GameState.PAUSED:
			_handle_paused_state()

func _handle_playing_state():
	# Resume game (no need to unpause since we're not pausing)
	# get_tree().paused = false  # Removed - we're not pausing
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Hide death screen via GameplayUIManager
	var ui_manager = get_node_or_null("/root/GameplayUIManager")
	if ui_manager and ui_manager.has_method("hide_death_screen"):
		ui_manager.hide_death_screen()

func _handle_player_dead_state():
	# Don't pause the game, just disable player input
	# get_tree().paused = true  # Removed - let world continue
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Show death screen via GameplayUIManager
	var ui_manager = get_node_or_null("/root/GameplayUIManager")
	if ui_manager and ui_manager.has_method("show_death_screen"):
		ui_manager.show_death_screen()
	
	# Emit death signal
	player_died.emit()

func _handle_paused_state():
	# Pause game but keep mouse captured
	get_tree().paused = true

func _on_player_died():
	"""Called when player dies"""
	if debug_death:
		print("GameManager: Received player_died signal!")
		print("GameManager: Player died!")
	change_game_state(GameState.PLAYER_DEAD)

func _on_restart_button_pressed():
	"""Called when restart button is pressed"""
	restart_game()

func _on_main_menu_button_pressed():
	"""Called when main menu button is pressed"""
	return_to_main_menu()

func restart_game():
	"""Restart the current level"""
	if debug_restart:
		print("GameManager: Restarting game...")
	
	# Emit restart signal
	game_restart_requested.emit()
	
	# Reset game state
	change_game_state(GameState.PLAYING)
	
	# Clean up TracerManager before scene reload to prevent lambda errors
	var tracer_manager = get_node_or_null("/root/TracerManager")
	if tracer_manager:
		if debug_restart:
			print("GameManager: Cleaning up TracerManager before scene reload")
		tracer_manager.reset_tracer_system()
		# Wait a frame for cleanup to complete
		await get_tree().process_frame
	
	# Reload current scene
	get_tree().reload_current_scene()

func return_to_main_menu():
	"""Return to the main menu."""
	if debug_restart:
		print("GameManager: Returning to main menu...")
	
	# Deactivate gameplay systems
	var level_manager = get_node_or_null("/root/LevelManager")
	if level_manager and level_manager.has_method("deactivate_gameplay_systems"):
		level_manager.deactivate_gameplay_systems()
	
	# Emit restart signal to clean up systems
	game_restart_requested.emit()
	
	# Reset game state
	change_game_state(GameState.PLAYING)
	
	# Clean up TracerManager before scene change
	var tracer_manager = get_node_or_null("/root/TracerManager")
	if tracer_manager:
		if debug_restart:
			print("GameManager: Cleaning up TracerManager before menu return")
		tracer_manager.reset_tracer_system()
		# Wait a frame for cleanup to complete
		await get_tree().process_frame
	
	# Change to main menu scene
	var error = get_tree().change_scene_to_file(main_menu_scene)
	if error != OK:
		if debug_restart:
			print("GameManager: Failed to load main menu: ", error)

func return_to_level_select():
	"""Return to the level selection menu."""
	if debug_restart:
		print("GameManager: Returning to level selection...")
	
	# Deactivate gameplay systems
	var level_manager = get_node_or_null("/root/LevelManager")
	if level_manager and level_manager.has_method("deactivate_gameplay_systems"):
		level_manager.deactivate_gameplay_systems()
	
	# Emit restart signal to clean up systems
	game_restart_requested.emit()
	
	# Reset game state
	change_game_state(GameState.PLAYING)
	
	# Clean up TracerManager before scene change
	var tracer_manager = get_node_or_null("/root/TracerManager")
	if tracer_manager:
		tracer_manager.reset_tracer_system()
		await get_tree().process_frame
	
	# Change to level selection scene
	var error = get_tree().change_scene_to_file(level_selection_scene)
	if error != OK:
		if debug_restart:
			print("GameManager: Failed to load level selection: ", error)

func is_player_dead() -> bool:
	return current_state == GameState.PLAYER_DEAD

func is_game_paused() -> bool:
	return current_state == GameState.PAUSED 
