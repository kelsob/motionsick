extends Node
class_name TimeAffected

# === TIME-AFFECTED OBJECT BASE CLASS ===
# Inherit from this or add as component to make objects respond to TimeManager

# Resistance to time effects (0.0 = fully affected, 1.0 = completely immune)
@export var time_resistance: float = 0.0

# Optional: Disable time effects entirely for this object
@export var ignore_time_system: bool = false

# Reference to TimeManager (automatically found)
var time_manager: Node = null

# Cached time scale for performance
var cached_time_scale: float = 1.0
var cached_effective_scale: float = 1.0

func _ready():
	# Find TimeManager singleton
	time_manager = get_node("/root/TimeManager")
	if time_manager:
		# Connect to time scale changes for efficiency
		time_manager.time_scale_changed.connect(_on_time_scale_changed)
		# Initialize cache
		_update_cached_scales()
	else:
		print("WARNING: TimeAffected object can't find TimeManager!")

func _on_time_scale_changed(new_scale: float):
	"""Update cached values when time scale changes."""
	_update_cached_scales()

func _update_cached_scales():
	"""Update cached time scale values."""
	if time_manager:
		cached_time_scale = time_manager.get_time_scale()
		if ignore_time_system:
			cached_effective_scale = 1.0
		else:
			cached_effective_scale = cached_time_scale * (1.0 - time_resistance)

# === PUBLIC API ===

func get_time_scale() -> float:
	"""Get current time scale (cached for performance)."""
	return cached_time_scale if time_manager else 1.0

func get_effective_time_scale() -> float:
	"""Get time scale adjusted for this object's resistance."""
	return cached_effective_scale if time_manager else 1.0

func get_time_adjusted_delta(delta: float) -> float:
	"""Get delta scaled by time system and this object's resistance."""
	if ignore_time_system or not time_manager:
		return delta
	return delta * cached_effective_scale

func is_time_frozen() -> bool:
	"""Check if time is effectively frozen for this object."""
	return get_effective_time_scale() < 0.1

func is_time_normal() -> bool:
	"""Check if time is effectively normal for this object."""
	return get_effective_time_scale() > 0.9

func set_time_resistance(resistance: float):
	"""Change time resistance at runtime."""
	time_resistance = clamp(resistance, 0.0, 1.0)
	_update_cached_scales()

func set_ignore_time_system(ignore: bool):
	"""Enable/disable time system effects for this object."""
	ignore_time_system = ignore
	_update_cached_scales()

# === CONVENIENCE METHODS ===

func scale_velocity(velocity: Vector3, delta: float) -> Vector3:
	"""Scale a velocity vector by time-adjusted delta."""
	return velocity * get_time_adjusted_delta(delta)

func scale_timer(timer_value: float, delta: float) -> float:
	"""Scale a timer by time-adjusted delta."""
	return timer_value - get_time_adjusted_delta(delta)

func scale_animation_speed(base_speed: float) -> float:
	"""Scale animation speed by effective time scale."""
	return base_speed * get_effective_time_scale()

# === DEBUG ===

func print_time_info():
	"""Debug function to print time state for this object."""
	print("=== TIME AFFECTED OBJECT ===")
	print("Node: ", get_parent().name if get_parent() else "No parent")
	print("Time resistance: ", time_resistance)
	print("Ignore time system: ", ignore_time_system)
	print("Current time scale: ", get_time_scale())
	print("Effective time scale: ", get_effective_time_scale())
	print("Time frozen: ", is_time_frozen())
	print("Time normal: ", is_time_normal())
	print("=============================")

# === STATIC UTILITY FUNCTIONS ===

# These can be used without inheriting from TimeAffected
static func create_time_affected_node(resistance: float = 0.0) -> TimeAffected:
	"""Create a TimeAffected node with specified resistance."""
	var time_node = TimeAffected.new()
	time_node.time_resistance = resistance
	return time_node

static func add_time_effects_to_node(node: Node, resistance: float = 0.0) -> TimeAffected:
	"""Add time effects to any node by adding TimeAffected as child."""
	var time_node = create_time_affected_node(resistance)
	node.add_child(time_node)
	return time_node

static func get_time_manager() -> Node:
	"""Get reference to TimeManager singleton."""
	return Engine.get_singleton("TimeManager") if Engine.has_singleton("TimeManager") else null