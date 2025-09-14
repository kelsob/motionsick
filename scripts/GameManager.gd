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
@export var player_path: String = "/root/Main/Player"
## Path to main scene node
@export var main_scene_path: String = "/root/Main"
## Path to death screen UI
@export var death_screen_path: String = "/root/Main/UI/DeathScreen"
## Path to restart button in death screen
@export var restart_button_path: String = "VBoxContainer/RestartButton"

@export_group("Input Settings")
## Key code for restart input when dead
@export var restart_key: int = KEY_R

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
	
	# Find death screen
	death_screen = get_node_or_null(death_screen_path)
	if death_screen:
		if debug_connections:
			print("GameManager: Found death screen")
		death_screen.hide()
		# Connect restart button
		var restart_button = death_screen.get_node_or_null(restart_button_path)
		if restart_button:
			# Disconnect first to avoid duplicate connections
			if restart_button.pressed.is_connected(_on_restart_button_pressed):
				restart_button.pressed.disconnect(_on_restart_button_pressed)
			restart_button.pressed.connect(_on_restart_button_pressed)
			if debug_connections:
				print("GameManager: Successfully connected restart button")
		else:
			if debug_connections:
				print("GameManager: Restart button not found")
	else:
		if debug_connections:
			print("GameManager: DeathScreen not found in scene")

func _on_node_added(node: Node):
	"""Called when a new node is added to the scene tree"""
	# Check if this is the player or death screen being added
	if str(node.get_path()) == player_path:
		if debug_connections:
			print("GameManager: Player node added, reconnecting signals")
		_setup_connections()
	elif str(node.get_path()) == death_screen_path:
		if debug_connections:
			print("GameManager: DeathScreen node added, reconnecting signals")
		_setup_connections()

func _input(event):
	# Handle restart input when dead
	if current_state == GameState.PLAYER_DEAD:
		if (event is InputEventKey and event.pressed and event.keycode == restart_key):
			restart_game()

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
	
	# Hide death screen
	if death_screen:
		death_screen.hide()
		# Ensure death screen is properly reset
		if death_screen.has_method("reset_animation_state"):
			death_screen.reset_animation_state()

func _handle_player_dead_state():
	# Don't pause the game, just disable player input
	# get_tree().paused = true  # Removed - let world continue
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Show death screen
	if death_screen:
		death_screen.show()
	
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

func is_player_dead() -> bool:
	return current_state == GameState.PLAYER_DEAD

func is_game_paused() -> bool:
	return current_state == GameState.PAUSED 
