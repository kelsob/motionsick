extends Node
class_name TimeAffectedEnemy

# === TIME-AFFECTED ENEMY HELPER ===
# Add this as a child to any enemy to make it respond to time dilation

@export var time_resistance: float = 0.0  # 0.0 = fully affected, 1.0 = immune
@export var affect_ai: bool = true  # Whether AI logic should be time-scaled
@export var affect_animation: bool = true  # Whether animations should be time-scaled
@export var affect_movement: bool = true  # Whether movement should be time-scaled

# Time system component
var time_affected: TimeAffected = null

# Parent enemy reference
var enemy: Node = null

func _ready():
	# Get parent enemy
	enemy = get_parent()
	
	# Create time affected component
	time_affected = TimeAffected.new()
	time_affected.time_resistance = time_resistance
	add_child(time_affected)
	
	print("Enemy ", enemy.name, " now affected by time system (resistance: ", time_resistance, ")")

# === CONVENIENCE METHODS FOR ENEMY SCRIPTS ===

func get_time_adjusted_delta(delta: float) -> float:
	"""Get delta adjusted for time effects."""
	if not time_affected:
		return delta
	return time_affected.get_time_adjusted_delta(delta)

func get_effective_time_scale() -> float:
	"""Get current effective time scale for this enemy."""
	if not time_affected:
		return 1.0
	return time_affected.get_effective_time_scale()

func scale_movement_speed(base_speed: float) -> float:
	"""Scale movement speed by time effects."""
	if not affect_movement or not time_affected:
		return base_speed
	return base_speed * time_affected.get_effective_time_scale()

func scale_ai_timer(timer_value: float, delta: float) -> float:
	"""Scale AI timers by time effects."""
	if not affect_ai or not time_affected:
		return timer_value - delta
	return timer_value - time_affected.get_time_adjusted_delta(delta)

func scale_animation_speed(base_speed: float) -> float:
	"""Scale animation speed by time effects."""
	if not affect_animation or not time_affected:
		return base_speed
	return base_speed * time_affected.get_effective_time_scale()

func is_time_frozen() -> bool:
	"""Check if time is effectively frozen for this enemy."""
	if not time_affected:
		return false
	return time_affected.is_time_frozen()

func set_time_resistance(resistance: float):
	"""Change time resistance at runtime."""
	time_resistance = clamp(resistance, 0.0, 1.0)
	if time_affected:
		time_affected.set_time_resistance(time_resistance)

# === EXAMPLE USAGE FOR ENEMY SCRIPTS ===
# func _physics_process(delta: float):
#     var time_delta = time_affected_enemy.get_time_adjusted_delta(delta)
#     
#     # Update AI with time-scaled delta
#     ai_timer = time_affected_enemy.scale_ai_timer(ai_timer, delta)
#     
#     # Move with time-scaled speed
#     velocity = direction * time_affected_enemy.scale_movement_speed(base_speed)
#     
#     # Only process AI when time isn't frozen
#     if not time_affected_enemy.is_time_frozen():
#         update_ai_logic(time_delta)