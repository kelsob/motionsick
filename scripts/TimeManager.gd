extends Node

# === TIME SCALING SYSTEM ===
# Controls global time dilation without affecting Engine.time_scale
# Allows asymmetric time where player is unaffected but world slows/freezes

# Current time scale (0.0 = frozen, 1.0 = normal speed)
var custom_time_scale: float = 1.0

# Smoothing parameters
@export var freeze_duration: float = 0.4  # Time to freeze when player starts moving
@export var unfreeze_duration: float = 1.0  # Time to unfreeze when player stops

# Damage prevention threshold
@export var damage_prevention_threshold: float = 0.5  # Below this time scale, damage is prevented

# State tracking
var target_time_scale: float = 1.0
var is_transitioning: bool = false
var transition_speed: float = 1.0

# Player movement state
var player_is_moving: bool = false
var player: CharacterBody3D = null

# Signals for time scale changes
signal time_scale_changed(new_scale: float)
signal time_freeze_started()
signal time_unfreeze_started()

func _ready():
	# Find player reference
	call_deferred("_find_player")
	
	# Connect to GameManager for restart events
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.game_restart_requested.connect(_on_game_restart_requested)
		print("TimeManager connected to GameManager")
	else:
		print("WARNING: TimeManager can't find GameManager")

func _find_player():
	player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		print("TimeManager connected to player")
	else:
		print("TimeManager: Player not found!")
		player = null

func _process(delta: float):
	# Update time scale smoothly
	_update_time_scale(delta)


func _update_time_scale(delta):
	# Use movement intent instead of velocity percentage to avoid turning issues
	var movement_intent = 0.0
	if player and is_instance_valid(player):
		movement_intent = player.get_movement_intent()
	else:
		# If player is null or invalid, try to find it again (but not every frame)
		if not player and Engine.get_process_frames() % 30 == 0:  # Try every 30 frames
			_find_player()
		movement_intent = 0.0
	
	custom_time_scale = 1.0 - movement_intent
	
	if custom_time_scale < 0.01:
		custom_time_scale = 0.0
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
	"""Check if time is currently frozen (below 0.1 threshold)."""
	return custom_time_scale < 0.1

func is_time_normal() -> bool:
	"""Check if time is at normal speed (above 0.9 threshold)."""
	return custom_time_scale > 0.9

func is_damage_prevented() -> bool:
	"""Check if damage should be prevented due to time dilation."""
	var prevented = custom_time_scale < damage_prevention_threshold
	if prevented:
		print("TimeManager: Damage prevented - Time scale: ", "%.2f" % custom_time_scale, " < ", "%.2f" % damage_prevention_threshold)
	return prevented

func get_damage_prevention_threshold() -> float:
	"""Get the current damage prevention threshold."""
	return damage_prevention_threshold

func set_damage_prevention_threshold(threshold: float):
	"""Set the damage prevention threshold (0.0 to 1.0)."""
	damage_prevention_threshold = clamp(threshold, 0.0, 1.0)
	print("TimeManager: Damage prevention threshold set to ", damage_prevention_threshold)

func get_player_moving_state() -> bool:
	"""Get current player movement state."""
	return player_is_moving

func _on_game_restart_requested():
	"""Called when game is restarting - reset player reference."""
	print("TimeManager: Game restarting, resetting player reference")
	player = null
	# Reset time scale to normal
	custom_time_scale = 1.0
	time_scale_changed.emit(custom_time_scale)

# === DEBUG API ===

func force_time_scale(scale: float):
	"""Force time scale for testing (bypasses smooth transitions)."""
	custom_time_scale = clamp(scale, 0.0, 1.0)
	target_time_scale = custom_time_scale
	is_transitioning = false
	time_scale_changed.emit(custom_time_scale)
	print("Time scale forced to: ", custom_time_scale)

func print_time_state():
	"""Debug function to print current time state."""
	print("=== TIME MANAGER STATE ===")
	print("Current scale: ", "%.3f" % custom_time_scale)
	print("Target scale: ", "%.3f" % target_time_scale)
	print("Player moving: ", player_is_moving)
	print("Transitioning: ", is_transitioning)
	if is_transitioning:
		print("Transition speed: ", "%.2f" % transition_speed)
	print("Damage prevention threshold: ", "%.2f" % damage_prevention_threshold)
	print("Damage prevented: ", is_damage_prevented())
	print("==========================")
