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
@export var debug_restart: bool = true
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
	print("GameManager: Setting up connections...")
	
	# Reset game state to PLAYING when setting up connections (new game)
	print("GameManager: Resetting game state to PLAYING")
	current_state = GameState.PLAYING
	
	# Find player
	player = get_node_or_null(player_path)
	if player:
		print("GameManager: Found player, connecting death signal")
		print("GameManager: Player instance ID: ", player.get_instance_id())
		# Connect to player death signal
		if player.has_signal("player_died"):
			# Disconnect first to avoid duplicate connections
			if player.player_died.is_connected(_on_player_died):
				print("GameManager: Disconnecting existing player death connection")
				player.player_died.disconnect(_on_player_died)
			player.player_died.connect(_on_player_died)
			print("GameManager: Successfully connected to player death signal")
			print("GameManager: Player death signal connected: ", player.player_died.is_connected(_on_player_died))
		else:
			print("Warning: Player doesn't have player_died signal")
	else:
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
	print("GameManager: change_game_state called - Current: ", current_state, " New: ", new_state)
	if current_state == new_state:
		print("GameManager: State already matches, returning early")
		return
	
	print("GameManager: Changing state from ", current_state, " to ", new_state)
	current_state = new_state
	game_state_changed.emit(new_state)
	
	match new_state:
		GameState.PLAYING:
			print("GameManager: Handling PLAYING state")
			_handle_playing_state()
		GameState.PLAYER_DEAD:
			print("GameManager: Handling PLAYER_DEAD state")
			_handle_player_dead_state()
		GameState.PAUSED:
			print("GameManager: Handling PAUSED state")
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
	print("GameManager: _handle_player_dead_state() called")
	# Don't pause the game, just disable player input
	# get_tree().paused = true  # Removed - let world continue
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	print("GameManager: Set mouse mode to visible")
	
	# Disable player input
	if player and player.has_method("set_input_enabled"):
		player.set_input_enabled(false)
		print("GameManager: Disabled player input on death")
	
	# Show death screen via GameplayUIManager
	var ui_manager = get_node_or_null("/root/GameplayUIManager")
	if ui_manager and ui_manager.has_method("show_death_screen"):
		ui_manager.show_death_screen()
		print("GameManager: Called show_death_screen")
	else:
		print("GameManager: GameplayUIManager not found or no show_death_screen method")
	
	# Emit death signal
	print("GameManager: About to emit player_died signal")
	print("GameManager: Signal connections: ", player_died.get_connections().size())
	for connection in player_died.get_connections():
		print("GameManager: Connected to: ", connection.callable)
	player_died.emit()
	print("GameManager: Emitted player_died signal")

func _handle_paused_state():
	# Pause game but keep mouse captured
	get_tree().paused = true

func _on_player_died():
	"""Called when player dies"""
	print("GameManager: Received player_died signal!")
	print("GameManager: Player died!")
	
	# Disable combat UI immediately
	var ui_manager = get_node_or_null("/root/GameplayUIManager")
	if ui_manager:
		ui_manager.deactivate_gameplay_ui()
		print("GameManager: Disabled combat UI on player death")
	
	# Pause the time system
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		time_manager.pause_time()
		print("GameManager: Paused time system")
	
	# Track session end for analytics (session failed)
	AnalyticsManager.end_session(false)
	print("GameManager: Tracked session end")
	
	print("GameManager: About to change game state to PLAYER_DEAD")
	change_game_state(GameState.PLAYER_DEAD)
	print("GameManager: Changed game state to PLAYER_DEAD")

func _on_restart_button_pressed():
	"""Called when restart button is pressed"""
	restart_game()

func _on_main_menu_button_pressed():
	"""Called when main menu button is pressed"""
	return_to_main_menu()

func restart_game():
	"""Restart the current level properly through LevelManager"""
	if debug_restart:
		print("GameManager: Restarting game...")
	
	# Use GameStateManager for complete restart
	var game_state_manager = get_node_or_null("/root/GameStateManager")
	if game_state_manager:
		var success = await game_state_manager.complete_restart_level()
		if not success:
			if debug_restart:
				print("GameManager: Complete restart failed, falling back")
			await _restart_game_fallback()
	else:
		# Fallback to old scene reload method if GameStateManager not available
		if debug_restart:
			print("GameManager: GameStateManager not found, using fallback")
		await _restart_game_fallback()

# Old restart method removed - now using GameStateManager.complete_restart_level()

func _restart_game_fallback():
	"""Fallback restart method - PROPERLY restart through LevelManager."""
	if debug_restart:
		print("GameManager: FALLBACK RESTART - doing it properly...")
	
	# Get current level BEFORE cleanup
	var level_manager = get_node_or_null("/root/LevelManager")
	if not level_manager or not level_manager.current_level:
		if debug_restart:
			print("GameManager: No level found, using scene reload")
		get_tree().reload_current_scene()
		return
	
	var current_level = level_manager.current_level
	if debug_restart:
		print("GameManager: Restarting level: ", current_level.display_name)
	
	# === STEP 1: STOP EVERYTHING ===
	var arena_spawn_manager = get_node_or_null("/root/ArenaSpawnManager")
	if arena_spawn_manager:
		arena_spawn_manager.stop_spawning()
		if debug_restart:
			print("GameManager: Stopped enemy spawning")
	
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		time_manager.deactivate_for_menus()
		if debug_restart:
			print("GameManager: Deactivated TimeManager")
	
	var ui_manager = get_node_or_null("/root/GameplayUIManager")
	if ui_manager:
		ui_manager.deactivate_gameplay_ui()
		if debug_restart:
			print("GameManager: Deactivated UI")
	
	# === STEP 2: RESET EVERYTHING ===
	var score_manager = get_node_or_null("/root/ScoreManager")
	if score_manager:
		score_manager.reset_score()
		if debug_restart:
			print("GameManager: Reset score")
	
	var tracer_manager = get_node_or_null("/root/TracerManager")
	if tracer_manager:
		tracer_manager.reset_tracer_system()
		if debug_restart:
			print("GameManager: Reset TracerManager")
	
	if arena_spawn_manager and arena_spawn_manager.has_method("reset_for_level"):
		arena_spawn_manager.reset_for_level()
		if debug_restart:
			print("GameManager: Reset ArenaSpawnManager")
	
	# Analytics
	AnalyticsManager.end_session(false)
	if debug_restart:
		print("GameManager: Ended analytics session")
	
	# === STEP 3: SIGNAL CLEANUP ===
	game_restart_requested.emit()
	change_game_state(GameState.PLAYING)
	if debug_restart:
		print("GameManager: Emitted signals")
	
	# Wait for cleanup
	await get_tree().process_frame
	await get_tree().process_frame
	
	# === STEP 4: PROPER RELOAD ===
	if debug_restart:
		print("GameManager: Reloading through LevelManager...")
	
	# Use LevelManager to properly reload everything
	level_manager.current_level = current_level
	await level_manager.load_selected_level()
	
	if debug_restart:
		print("GameManager: *** FALLBACK RESTART COMPLETE ***")

func return_to_main_menu():
	"""Return to the main menu."""
	if debug_restart:
		print("GameManager: Returning to main menu...")
	
	# Use centralized cleanup and scene change
	var game_state_manager = get_node_or_null("/root/GameStateManager")
	if game_state_manager:
		await game_state_manager.cleanup_and_change_scene(main_menu_scene)
	else:
		# Fallback to individual cleanup if GameStateManager not available
		await _return_to_main_menu_fallback()

func _return_to_main_menu_fallback():
	"""Fallback method for returning to main menu if GameStateManager is not available."""
	# Resume time system
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		time_manager.resume_time()
	
	# Clean up UI
	_cleanup_game_ui()
	
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

func _cleanup_game_ui():
	"""Clean up gameplay UI when returning to menu."""
	# Hide gameplay UI
	var ui_manager = get_node_or_null("/root/GameplayUIManager")
	if ui_manager:
		ui_manager.deactivate_gameplay_ui()
		if debug_restart:
			print("GameManager: Cleaned up gameplay UI")

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
