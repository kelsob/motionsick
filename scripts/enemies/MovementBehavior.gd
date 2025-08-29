class_name MovementBehavior
extends Resource

# === MOVEMENT BEHAVIOR SYSTEM ===
# Base class for all enemy movement behaviors - STRIPPED FOR REBUILD

enum Type {
	CHASE,
	KEEP_DISTANCE,
	FLANKING,
	CIRCLING,
	PATROL
}

# Base behavior properties
var enemy: Node3D
var behavior_name: String = "Base"
var current_state: String = "idle"
var state_timer: float = 0.0

func setup(enemy_node: Node3D):
	"""Initialize the behavior with the enemy reference."""
	enemy = enemy_node
	_on_setup()

func _on_setup():
	"""Override in derived classes for specific setup."""
	pass

func get_movement_direction(delta: float) -> Vector3:
	"""TODO: Rebuild movement direction system."""
	state_timer += delta
	# Movement system stripped - will be rebuilt from ground up
	return Vector3.ZERO

func get_target_position(delta: float) -> Vector3:
	"""TODO: Rebuild navigation target system."""
	# Navigation system stripped - will be rebuilt from ground up
	return Vector3.ZERO

func on_state_timer_timeout():
	"""Called when the enemy's state timer expires. Override if needed."""
	pass

func cleanup():
	"""Clean up resources when behavior is changed."""
	pass

# === FACTORY METHOD ===

static func create(type: Type) -> MovementBehavior:
	"""Create a movement behavior of the specified type."""
	match type:
		Type.CHASE:
			return ChaseMovement.new()
		Type.KEEP_DISTANCE:
			return KeepDistanceMovement.new()
		Type.FLANKING:
			return FlankingMovement.new()
		Type.CIRCLING:
			return CirclingMovement.new()
		Type.PATROL:
			return PatrolMovement.new()
		_:
			return ChaseMovement.new()  # Default fallback

# === UTILITY METHODS ===

func get_player_direction() -> Vector3:
	"""Get normalized direction to player."""
	if enemy and enemy.get_player():
		return enemy.get_direction_to_player()
	return Vector3.ZERO

func get_distance_to_player() -> float:
	"""Get distance to player."""
	if enemy:
		return enemy.get_distance_to_player()
	return 0.0

func is_player_visible() -> bool:
	"""Check if player is visible."""
	if enemy:
		return enemy.is_player_visible()
	return false

# === MOVEMENT BEHAVIOR CLASSES - STRIPPED FOR REBUILD ===

class ChaseMovement extends MovementBehavior:
	"""TODO: Rebuild chase movement behavior."""
	
	func _on_setup():
		behavior_name = "Chase"
	
	func get_movement_direction(delta: float) -> Vector3:
		super(delta)
		# Chase movement stripped - will be rebuilt
		return Vector3.ZERO

class KeepDistanceMovement extends MovementBehavior:
	"""TODO: Rebuild keep distance behavior."""
	
	var optimal_distance: float = 8.0
	var distance_tolerance: float = 2.0
	
	func _on_setup():
		behavior_name = "Keep Distance"
	
	func get_movement_direction(delta: float) -> Vector3:
		super(delta)
		# Keep distance movement stripped - will be rebuilt
		return Vector3.ZERO

class FlankingMovement extends MovementBehavior:
	"""TODO: Rebuild flanking behavior."""
	
	var flank_distance: float = 6.0
	var flank_angle: float = 0.0
	var flank_speed: float = 2.0
	
	func _on_setup():
		behavior_name = "Flanking"
	
	func get_movement_direction(delta: float) -> Vector3:
		super(delta)
		# Flanking movement stripped - will be rebuilt
		return Vector3.ZERO

class CirclingMovement extends MovementBehavior:
	"""TODO: Rebuild circling behavior."""
	
	var circle_radius: float = 10.0
	var circle_speed: float = 1.5
	
	func _on_setup():
		behavior_name = "Circling"
	
	func get_movement_direction(delta: float) -> Vector3:
		super(delta)
		# Circling movement stripped - will be rebuilt
		return Vector3.ZERO

class PatrolMovement extends MovementBehavior:
	"""TODO: Rebuild patrol behavior."""
	
	var patrol_radius: float = 8.0
	
	func _on_setup():
		behavior_name = "Patrol"
	
	func get_movement_direction(delta: float) -> Vector3:
		super(delta)
		# Patrol movement stripped - will be rebuilt
		return Vector3.ZERO