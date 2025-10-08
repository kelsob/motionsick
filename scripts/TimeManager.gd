extends Node

# === TIME SCALING SYSTEM ===
# Controls global time dilation without affecting Engine.time_scale
# Allows asymmetric time where player is unaffected but world slows/freezes

## === EXPORTED CONFIGURATION ===
@export_group("Time Scale Thresholds")
## Below this threshold, time is considered "frozen"
@export var time_frozen_threshold: float = 0.1
## Above this threshold, time is considered "normal speed"
@export var time_normal_threshold: float = 0.9
## Below this time scale, damage is prevented
@export var damage_prevention_threshold: float = 0.5

@export_group("Movement Response")
## Minimum time scale - time never goes below this value (prevents full stop)
@export var minimum_time_scale: float = 0.2
## Default time scale when no movement intent (normal speed)
@export var default_time_scale: float = 1.0

@export_group("Player Detection")
## How often to retry finding the player (in frames) when player reference is lost
@export var player_search_retry_interval: int = 30

@export_group("Debug Settings")
## Enable debug print statements for damage prevention
@export var debug_damage_prevention: bool = true
## Enable debug print statements for player connection
@export var debug_player_connection: bool = true
## Enable debug print statements for GameManager connection
@export var debug_gamemanager_connection: bool = true

## === RUNTIME STATE ===
# Current time scale (0.0 = frozen, 1.0 = normal speed)
var custom_time_scale: float = 1.0
# Player reference
var player: CharacterBody3D = null
# Whether TimeManager is active (only during gameplay)
var is_active: bool = false

# Signals for time scale changes
signal time_scale_changed(new_scale: float)

# Pause state
var is_paused: bool = false

func _ready():
	# Initialize time scale to default
	custom_time_scale = default_time_scale
	
	# Connect to GameManager for restart events
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.game_restart_requested.connect(_on_game_restart_requested)
		if debug_gamemanager_connection:
			print("TimeManager connected to GameManager")
	else:
		if debug_gamemanager_connection:
			print("WARNING: TimeManager can't find GameManager")
	
	# Don't find player immediately - wait for level to load

func _find_player():
	player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		if debug_player_connection:
			print("TimeManager connected to player")
	else:
		if debug_player_connection:
			print("TimeManager: Player not found!")
		player = null

func _process(delta: float):
	# Only process when active (during gameplay)
	if not is_active:
		return
	
	# Update time scale smoothly
	_update_time_scale(delta)


func _update_time_scale(delta):
	# If paused, don't update time scale
	if is_paused:
		return
	
	# Use movement intent instead of velocity percentage to avoid turning issues
	var movement_intent = 0.0
	if player and is_instance_valid(player):
		movement_intent = player.get_movement_intent()
	else:
		# If player is null or invalid, try to find it again (but not every frame)
		if not player and Engine.get_process_frames() % player_search_retry_interval == 0:
			_find_player()
		movement_intent = 0.0
	
	# Calculate time scale based on movement intent
	# Interpolate from default_time_scale (at rest) to minimum_time_scale (at max movement)
	custom_time_scale = lerp(default_time_scale, minimum_time_scale, movement_intent)
	
	# Ensure we never go below the minimum
	custom_time_scale = max(minimum_time_scale, custom_time_scale)
	
	time_scale_changed.emit(custom_time_scale)


# === PUBLIC API ===
func get_time_scale() -> float:
	"""Get current custom time scale (0.0 to 1.0)."""
	return custom_time_scale

func get_effective_delta(delta: float, time_resistance: float = 0.0) -> float:
	"""Get delta scaled by time system and resistance.
	time_resistance: 0.0 = fully affected, 1.0 = unaffected"""
	var resistance_factor = 1.0 - time_resistance
	return delta * custom_time_scale * resistance_factor

func is_time_frozen() -> bool:
	"""Check if time is currently frozen (below configured threshold)."""
	return custom_time_scale < time_frozen_threshold

func is_time_normal() -> bool:
	"""Check if time is at normal speed (above configured threshold)."""
	return custom_time_scale > time_normal_threshold

func is_damage_prevented() -> bool:
	"""Check if damage should be prevented due to time dilation."""
	var prevented = custom_time_scale < damage_prevention_threshold
	if prevented and debug_damage_prevention:
		print("TimeManager: Damage prevented - Time scale: ", "%.2f" % custom_time_scale, " < ", "%.2f" % damage_prevention_threshold)
	return prevented

func get_damage_prevention_threshold() -> float:
	"""Get the current damage prevention threshold."""
	return damage_prevention_threshold

func set_damage_prevention_threshold(threshold: float):
	"""Set the damage prevention threshold (0.0 to 1.0)."""
	damage_prevention_threshold = clamp(threshold, 0.0, 1.0)
	print("TimeManager: Damage prevention threshold set to ", damage_prevention_threshold)


func activate_for_gameplay():
	"""Activate TimeManager for gameplay - find player and start processing."""
	if debug_gamemanager_connection:
		print("TimeManager: Activating for gameplay")
	is_active = true
	_find_player()

func deactivate_for_menus():
	"""Deactivate TimeManager when returning to menus."""
	if debug_gamemanager_connection:
		print("TimeManager: Deactivating for menus")
	is_active = false
	player = null
	custom_time_scale = default_time_scale
	time_scale_changed.emit(custom_time_scale)

func _on_game_restart_requested():
	"""Called when game is restarting - reset player reference."""
	if debug_gamemanager_connection:
		print("TimeManager: Game restarting, resetting player reference")
	player = null
	# Reset time scale to default
	custom_time_scale = default_time_scale
	time_scale_changed.emit(custom_time_scale)

# === DEBUG API ===

func force_time_scale(scale: float):
	"""Force time scale for testing (bypasses smooth transitions)."""
	custom_time_scale = clamp(scale, 0.0, default_time_scale)
	time_scale_changed.emit(custom_time_scale)
	print("Time scale forced to: ", custom_time_scale)

func pause_time():
	"""Pause the time system (for player death)."""
	is_paused = true
	custom_time_scale = 0.0
	time_scale_changed.emit(custom_time_scale)
	if debug_gamemanager_connection:
		print("TimeManager: Time paused")

func resume_time():
	"""Resume the time system."""
	is_paused = false
	custom_time_scale = default_time_scale
	time_scale_changed.emit(custom_time_scale)
	if debug_gamemanager_connection:
		print("TimeManager: Time resumed")

func print_time_state():
	"""Debug function to print current time state."""
	print("=== TIME MANAGER STATE ===")
	print("Current scale: ", "%.3f" % custom_time_scale)
	print("Player valid: ", player != null and is_instance_valid(player))
	print("Time frozen: ", is_time_frozen())
	print("Time normal: ", is_time_normal())
	print("Damage prevention threshold: ", "%.2f" % damage_prevention_threshold)
	print("Damage prevented: ", is_damage_prevented())
	print("Paused: ", is_paused)
	print("==========================")
