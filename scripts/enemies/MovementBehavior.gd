extends Resource
class_name MovementBehavior

# === MOVEMENT BEHAVIOR SYSTEM ===
# Base class for enemy movement patterns

enum Type {
	CHASE,        # Direct pursuit of player
	KEEP_DISTANCE, # Maintain optimal range
	FLANKING,     # Try to get behind player  
	CIRCLING,     # Circle around player
	PATROL        # Patrol area, chase when detected
}

# === CONFIGURATION ===
var enemy: BaseEnemy
var behavior_name: String = "Base"

# Common state
var state_timer: float = 0.0
var current_state: String = "idle"

# === FACTORY METHOD ===
static func create(type: Type) -> MovementBehavior:
	"""Factory method to create specific movement behaviors."""
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
			return ChaseMovement.new()

# === VIRTUAL METHODS ===

func setup(enemy_ref: BaseEnemy):
	"""Initialize the behavior with enemy reference."""
	enemy = enemy_ref
	_on_setup()

func _on_setup():
	"""Override in derived classes for specific setup."""
	pass

func get_movement_direction(delta: float) -> Vector3:
	"""Get the movement direction for this frame. Override in derived classes."""
	state_timer += delta
	return Vector3.ZERO

func on_state_timer_timeout():
	"""Called when the enemy's state timer expires. Override if needed."""
	pass

func cleanup():
	"""Clean up resources when behavior is changed."""
	pass

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

# === CHASE MOVEMENT ===
class ChaseMovement extends MovementBehavior:
	"""Direct pursuit of the player."""
	
	func _on_setup():
		behavior_name = "Chase"
	
	func get_movement_direction(delta: float) -> Vector3:
		super(delta)
		
		if not enemy or not enemy.get_player():
			return Vector3.ZERO
		
		# Simple direct chase
		return get_player_direction()

# === KEEP DISTANCE MOVEMENT ===
class KeepDistanceMovement extends MovementBehavior:
	"""Maintain optimal distance from player."""
	
	var optimal_distance: float = 8.0
	var distance_tolerance: float = 2.0
	
	func _on_setup():
		behavior_name = "Keep Distance"
	
	func get_movement_direction(delta: float) -> Vector3:
		super(delta)
		
		if not enemy or not enemy.get_player():
			return Vector3.ZERO
		
		var distance = get_distance_to_player()
		var direction = get_player_direction()
		
		if distance < optimal_distance - distance_tolerance:
			# Too close, back away
			current_state = "backing_away"
			return -direction
		elif distance > optimal_distance + distance_tolerance:
			# Too far, move closer
			current_state = "closing_in"
			return direction
		else:
			# In optimal range, strafe slightly
			current_state = "strafing"
			var strafe_direction = Vector3.RIGHT if sin(state_timer * 2.0) > 0 else Vector3.LEFT
			return strafe_direction * 0.5

# === FLANKING MOVEMENT ===
class FlankingMovement extends MovementBehavior:
	"""Try to get behind the player."""
	
	var flank_distance: float = 6.0
	var flank_angle: float = 0.0
	var flank_speed: float = 2.0
	var player_has_camera_method: bool = false  # Cache the method check
	var method_checked: bool = false
	
	# Cache camera direction to avoid expensive transform calculations every frame
	var cached_camera_direction: Vector3 = Vector3.FORWARD
	var camera_cache_timer: float = 0.0
	var camera_cache_interval: float = 0.1  # Update camera direction every 0.1 seconds
	
	func _on_setup():
		behavior_name = "Flanking"
		flank_angle = randf() * TAU  # Random starting angle
	
	func get_movement_direction(delta: float) -> Vector3:
		super(delta)
		
		if not enemy or not enemy.get_player():
			return Vector3.ZERO
		
		var player = enemy.get_player()
		var player_pos = player.global_position
		
		# Cache the method check - only do it once
		if not method_checked:
			player_has_camera_method = player.has_method("get_camera_direction")
			method_checked = true
		
		# Update cached camera direction periodically instead of every frame
		camera_cache_timer += delta
		if camera_cache_timer >= camera_cache_interval:
			camera_cache_timer = 0.0
			if player_has_camera_method:
				cached_camera_direction = -player.get_camera_direction()
			else:
				cached_camera_direction = Vector3.FORWARD
		
		# Calculate flanking position behind player using cached direction
		var target_angle = atan2(cached_camera_direction.x, cached_camera_direction.z) + PI
		flank_angle = lerp_angle(flank_angle, target_angle, flank_speed * delta)
		
		# Calculate target position
		var target_pos = player_pos + Vector3(
			cos(flank_angle) * flank_distance,
			0,
			sin(flank_angle) * flank_distance
		)
		
		# Move toward flanking position
		var direction = (target_pos - enemy.global_position).normalized()
		current_state = "flanking"
		
		return direction

# === CIRCLING MOVEMENT ===
class CirclingMovement extends MovementBehavior:
	"""Circle around the player at a set distance."""
	
	var circle_radius: float = 10.0
	var circle_speed: float = 1.5
	var circle_angle: float = 0.0
	var clockwise: bool = true
	
	func _on_setup():
		behavior_name = "Circling"
		circle_angle = randf() * TAU
		clockwise = randf() > 0.5
	
	func get_movement_direction(delta: float) -> Vector3:
		super(delta)
		
		if not enemy or not enemy.get_player():
			return Vector3.ZERO
		
		var player_pos = enemy.get_player().global_position
		
		# Update circle angle
		var angle_delta = circle_speed * delta
		if not clockwise:
			angle_delta = -angle_delta
		circle_angle += angle_delta
		
		# Calculate target position on circle
		var target_pos = player_pos + Vector3(
			cos(circle_angle) * circle_radius,
			0,
			sin(circle_angle) * circle_radius
		)
		
		# Move toward circle position
		var direction = (target_pos - enemy.global_position).normalized()
		current_state = "circling"
		
		return direction

# === PATROL MOVEMENT ===
class PatrolMovement extends MovementBehavior:
	"""Patrol an area, chase when player is detected."""
	
	var patrol_points: Array[Vector3] = []
	var current_patrol_index: int = 0
	var patrol_radius: float = 8.0
	var detection_triggered: bool = false
	var return_timer: float = 0.0
	var return_delay: float = 5.0  # Seconds before returning to patrol
	
	func _on_setup():
		behavior_name = "Patrol"
		_generate_patrol_points()
		enemy.player_detected.connect(_on_player_detected)
	
	func _generate_patrol_points():
		"""Generate patrol points around the enemy's starting position."""
		var start_pos = enemy.global_position
		patrol_points.clear()
		
		# Create 4 patrol points in a square pattern
		for i in range(4):
			var angle = (i * PI / 2.0) + (PI / 4.0)
			var point = start_pos + Vector3(
				cos(angle) * patrol_radius,
				0,
				sin(angle) * patrol_radius
			)
			patrol_points.append(point)
	
	func get_movement_direction(delta: float) -> Vector3:
		super(delta)
		
		if not enemy or not enemy.get_player():
			return Vector3.ZERO
		
		# If player detected and visible, chase
		if detection_triggered and is_player_visible():
			current_state = "chasing"
			return_timer = 0.0
			return get_player_direction()
		
		# If we were chasing but lost sight, wait before returning to patrol
		if detection_triggered:
			return_timer += delta
			if return_timer >= return_delay:
				detection_triggered = false
				return_timer = 0.0
				current_state = "returning_to_patrol"
		
		# Normal patrol behavior
		if patrol_points.size() == 0:
			return Vector3.ZERO
		
		var target_point = patrol_points[current_patrol_index]
		var distance_to_target = enemy.global_position.distance_to(target_point)
		
		# If close to current patrol point, move to next
		if distance_to_target < 2.0:
			current_patrol_index = (current_patrol_index + 1) % patrol_points.size()
			target_point = patrol_points[current_patrol_index]
		
		current_state = "patrolling"
		return (target_point - enemy.global_position).normalized()
	
	func _on_player_detected(player: Node3D):
		"""Called when player enters detection range."""
		if not detection_triggered and is_player_visible():
			detection_triggered = true
			return_timer = 0.0