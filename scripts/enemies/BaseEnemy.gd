extends CharacterBody3D
class_name BaseEnemy

# === BASE ENEMY SYSTEM ===
# Extensible enemy with modular movement and attack behaviors

# === CONFIGURATION ===
@export_group("Enemy Stats")
@export var max_health: int = 100
@export var movement_speed: float = 5.0
@export var detection_range: float = 20.0
@export var attack_range: float = 10.0
@export var turn_speed: float = 5.0
@export var piercability: float = 1.0  # How much piercing power this enemy absorbs

@export_group("Behavior Configuration")
@export var movement_behavior_type: MovementBehavior.Type = MovementBehavior.Type.CHASE
@export var attack_behavior_type: AttackBehavior.Type = AttackBehavior.Type.MELEE




@export_group("Visual Settings")
@export var enemy_color: Color = Color.RED
@export var size_scale: float = 1.0

# === STATE ===
var current_health: int
var player: Node3D = null
var is_dead: bool = false
var is_attacking: bool = false

# Death animation state
var is_dying: bool = false
var death_fade_timer: float = 0.0
var death_fade_duration: float = 1.0
var original_color: Color

# Behavior components
var movement_behavior: MovementBehavior
var attack_behavior: AttackBehavior

# Movement state - BASIC NAVIGATION
var distance_to_player: float
var speed: float = 3.5
var gravity: float = 9.8
var rotation_speed: float = 5.0

# Navigation system - BASIC IMPLEMENTATION
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D

# Performance optimization for signal emission
var player_detection_signaled: bool = false

# Time system integration
var time_manager: Node = null
var time_affected: TimeAffected = null

# === COMPONENTS ===
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var attack_timer: Timer = $AttackTimer
@onready var state_timer: Timer = $StateTimer
@onready var raycast: RayCast3D = $RayCast3D

# === SIGNALS ===
signal health_changed(current: int, max: int)
signal enemy_died(enemy: BaseEnemy)
signal player_detected(player: Node3D)
signal attack_started()
signal attack_finished()

func _ready():
	# Initialize health
	current_health = max_health
	
	# Sync movement and rotation speeds - use the exported values instead of hardcoded ones
	speed = movement_speed
	rotation_speed = turn_speed
	
	# Find player
	player = get_tree().get_first_node_in_group("player")
	if not player:
		print("WARNING: Enemy can't find player!")
	
	# Connect to time manager
	time_manager = get_node("/root/TimeManager")
	
	# Add time system component
	time_affected = TimeAffected.new()
	time_affected.time_resistance = 0.0  # Fully affected by time
	add_child(time_affected)
	
	# Set up collision
	collision_layer = 128  # Enemy layer (bit 8)
	collision_mask = 5     # Environment (4) + Player (1) = 5
	
	# Add to enemy groups
	add_to_group("enemies")
	add_to_group("enemy")  # For main script targeting
	
	# Initialize behaviors
	_setup_behaviors()
	
	# Customize appearance
	_setup_appearance()
	
	# Connect timers
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	state_timer.timeout.connect(_on_state_timer_timeout)
	
	print("Enemy spawned: ", name, " | Movement: ", MovementBehavior.Type.keys()[movement_behavior_type], " | Attack: ", AttackBehavior.Type.keys()[attack_behavior_type])
	print("  Speed synced: movement_speed=", movement_speed, " -> speed=", speed)
	print("  Rotation synced: turn_speed=", turn_speed, " -> rotation_speed=", rotation_speed)
	
	# ENSURE RAYCAST IS IN CORRECT LOCAL POSITION
	if raycast:
		raycast.target_position = Vector3(0, 0, -5)  # Reset to proper forward direction
		print("  Raycast reset to local forward: ", raycast.target_position)

func _setup_behaviors():
	"""Initialize movement and attack behaviors based on configuration."""
	# Create movement behavior
	movement_behavior = MovementBehavior.create(movement_behavior_type)
	movement_behavior.setup(self)
	
	# Create attack behavior  
	attack_behavior = AttackBehavior.create(attack_behavior_type)
	attack_behavior.setup(self)

func _setup_appearance():
	"""Customize the enemy's visual appearance."""
	if mesh and mesh.mesh is CapsuleMesh:
		# Scale the mesh
		mesh.scale = Vector3.ONE * size_scale
		
		# Create material with enemy color
		var material = StandardMaterial3D.new()
		material.albedo_color = enemy_color
		material.emission_enabled = true
		material.emission = enemy_color * 0.3
		mesh.material_override = material



func _physics_process(delta):
	# Handle death fade animation
	if is_dying:
		_update_death_fade(delta)
		return
		
	if is_dead or not player:
		return
	
	# Get time-adjusted delta for time system integration
	var time_delta = time_affected.get_time_adjusted_delta(delta) if time_affected else delta
	
	# Full enemy logic - optimized movement system
	_update_player_tracking()
	_update_movement(time_delta)
	_update_attack_logic(time_delta)
	_apply_movement(time_delta)

func _update_player_tracking():
	"""Update distance and direction to player."""
	if not player:
		return
		
	# Calculate distance to player camera position for consistency
	var target_position = player.get_target_position() if player.has_method("get_target_position") else player.global_position
	distance_to_player = global_position.distance_to(target_position)
	
	# Check if player is in detection range - only emit signal once per detection
	if distance_to_player <= detection_range:
		if not player_detection_signaled:
			player_detected.emit(player)
			player_detection_signaled = true
	else:
		# Reset signal flag when player moves out of range
		player_detection_signaled = false

func _update_movement(delta):
	"""Movement handled by basic navigation - no behavior system needed."""
	# Basic navigation handles movement directly via _apply_movement()
	pass

func _update_attack_logic(delta):
	"""Update attack logic using the assigned attack behavior."""
	if attack_behavior and distance_to_player <= attack_range and not is_attacking:
		if attack_behavior.should_attack(delta):
			_start_attack()

func _apply_movement(delta):
	"""EXACT implementation from video tutorial with debug for grunts."""
	# Get time-adjusted delta for consistent movement speed
	var time_delta = time_affected.get_time_adjusted_delta(delta) if time_affected else delta
	
	if not is_on_floor():
		velocity.y -= gravity * delta  # Keep gravity at real-time
	else:
		velocity.y -= 2
	
	var next_location = nav_agent.get_next_path_position()
	var current_location = global_transform.origin
	
	# Scale speed by time for proper time dilation
	var effective_time_scale = time_affected.get_effective_time_scale() if time_affected else 1.0
	var time_scaled_speed = speed * effective_time_scale
	var new_velocity = (next_location - current_location).normalized() * time_scaled_speed
	
	# DEBUG: Print movement info for grunts
	if get_class() == "Grunt" or scene_file_path.get_file().get_basename() == "Grunt":
		print("GRUNT DEBUG - ", name)
		print("  Current pos: ", current_location)
		print("  Next nav pos: ", next_location)
		print("  Nav target: ", nav_agent.target_position)
		print("  Speed (BaseEnemy): ", speed)
		print("  Time-scaled speed: ", time_scaled_speed)
		print("  Speed (Grunt): ", movement_speed)
		print("  New velocity: ", new_velocity)
		print("  Distance to nav target: ", next_location.distance_to(current_location))
		print("  Nav agent is navigating: ", nav_agent.is_navigation_finished() == false)
		print("  Nav agent path exists: ", not nav_agent.is_target_reachable())
		print("  Time delta: ", time_delta, " (real: ", delta, ")")
		print("  Effective time scale: ", effective_time_scale)
	
	# Use normal movement interpolation (velocity is already time-scaled)
	velocity = velocity.move_toward(new_velocity, 0.25)
	move_and_slide()
	
	# Leave raycast alone - it should rotate with the enemy automatically
	
	# FUCK THE NAVIGATION DIRECTION - USE ACTUAL VELOCITY DIRECTION
	var velocity_direction = Vector3(velocity.x, 0, velocity.z)
	
	if velocity_direction.length() > 0.1:
		# SMOOTH rotation toward velocity direction - respecting time scale
		# For Godot: -Z is forward, so add PI to flip from +Z to -Z
		var velocity_angle = atan2(velocity_direction.x, velocity_direction.z) + PI
		var old_rotation = rotation.y
		
		# Smooth rotation with time-scaled interpolation
		rotation.y = lerp_angle(rotation.y, velocity_angle, rotation_speed * time_delta)
		
		# DEBUG: Print rotation info for grunts
		if get_class() == "Grunt" or scene_file_path.get_file().get_basename() == "Grunt":
			print("  SMOOTH VELOCITY ROTATION DEBUG:")
			print("    Actual velocity: ", velocity_direction)
			print("    Target velocity angle (deg): ", rad_to_deg(velocity_angle))
			print("    OLD rotation.y: ", rad_to_deg(old_rotation))
			print("    NEW rotation.y: ", rad_to_deg(rotation.y))
			print("    Rotation progress: ", rad_to_deg(velocity_angle - old_rotation))
			print("    Rotation speed: ", rotation_speed, " Time delta: ", time_delta)
			if raycast:
				print("    Raycast target: ", raycast.target_position)

func target_position(target):
	"""Set the navigation target position - called by Main script."""
	nav_agent.target_position = target
	
	# DEBUG: Print target updates for grunts
	if get_class() == "Grunt" or scene_file_path.get_file().get_basename() == "Grunt":
		print("GRUNT NAV TARGET UPDATE - ", name, ": ", target)

func _start_attack():
	"""Initiate an attack."""
	if is_attacking or not attack_behavior:
		return
	
	is_attacking = true
	attack_started.emit()
	
	# Let the attack behavior handle the attack
	attack_behavior.execute_attack()
	
	print(name, " attacking player!")

func _finish_attack():
	"""Complete the current attack."""
	is_attacking = false
	attack_finished.emit()

func _on_attack_timer_timeout():
	"""Called when attack timer expires."""
	if attack_behavior:
		attack_behavior.on_attack_timer_timeout()

func _on_state_timer_timeout():
	"""Called when state timer expires."""
	if movement_behavior:
		movement_behavior.on_state_timer_timeout()

# === DAMAGE SYSTEM ===

func take_damage(amount: int):
	"""Take damage and handle death if health reaches zero."""
	if is_dead:
		return
	
	current_health = max(0, current_health - amount)
	health_changed.emit(current_health, max_health)
	
	print(name, " took ", amount, " damage (", current_health, "/", max_health, ")")
	
	if current_health <= 0:
		_die()

func _die():
	"""Handle enemy death."""
	if is_dead:
		return
		
	is_dead = true
	print(name, " died!")
	
	# Add score for killing this enemy
	var score_manager = get_node_or_null("/root/ScoreManager")
	if score_manager:
		# Get enemy type from the class name
		var enemy_type = get_enemy_type_name()
		score_manager.add_score(enemy_type)
	else:
		print("WARNING: ScoreManager not found!")
	
	enemy_died.emit(self)
	
	# Start manual death fade animation that respects time scale
	is_dying = true
	death_fade_timer = 0.0
	
	# Store original color and enable transparency
	if mesh and mesh.material_override:
		original_color = mesh.material_override.albedo_color
		# Enable transparency on the material
		mesh.material_override.flags_transparent = true
	else:
		original_color = enemy_color
		
	print(name, " starting death fade animation")

func _update_death_fade(delta: float):
	"""Update manual death fade animation that respects time scale."""
	# Get time-adjusted delta
	var time_delta = time_affected.get_time_adjusted_delta(delta) if time_affected else delta
	
	# Update fade timer
	death_fade_timer += time_delta
	
	# Calculate fade progress (0.0 to 1.0)
	var fade_progress = death_fade_timer / death_fade_duration
	fade_progress = clamp(fade_progress, 0.0, 1.0)
	
	# Fade alpha from 1.0 to 0.0
	var alpha = 1.0 - fade_progress
	var faded_color = Color(original_color.r, original_color.g, original_color.b, alpha)
	
	# Apply faded color
	if mesh and mesh.material_override:
		mesh.material_override.albedo_color = faded_color
		print(faded_color)
	
	# Check if fade is complete
	if fade_progress >= 1.0:
		queue_free()

func get_enemy_type_name() -> String:
	"""Get the enemy type name for scoring purposes."""
	# Extract enemy type from the class name or scene name
	var scene_name = scene_file_path.get_file().get_basename()
	if scene_name in ["Grunt", "Sniper", "Flanker", "Rusher", "Artillery"]:
		return scene_name
	
	# Fallback to class name
	return get_class()

func get_piercability() -> float:
	"""Get the piercability value for this enemy."""
	return piercability

# === PUBLIC API ===

func get_player() -> Node3D:
	"""Get reference to the player."""
	return player

func get_distance_to_player() -> float:
	"""Get current distance to player."""
	return distance_to_player

func get_direction_to_player(from_position: Vector3 = Vector3.ZERO) -> Vector3:
	"""Get normalized direction vector to player camera (head level)."""
	if player:
		var start_pos = from_position if from_position != Vector3.ZERO else global_position
		var target_position = player.get_target_position(start_pos) if player.has_method("get_target_position") else player.global_position
		return (target_position - start_pos).normalized()
	return Vector3.ZERO

func is_player_in_range(range: float) -> bool:
	"""Check if player is within specified range."""
	return distance_to_player <= range

# Visibility check optimization
var visibility_cache: bool = true
var visibility_check_timer: float = 0.0
var visibility_check_interval: float = 0.1  # Check every 0.1 seconds instead of every frame

func is_player_visible() -> bool:
	"""Check if player is visible (cached for performance)."""
	if not player:
		return false
	
	# Only do expensive raycast every 0.1 seconds
	visibility_check_timer += get_physics_process_delta_time()
	if visibility_check_timer >= visibility_check_interval:
		visibility_check_timer = 0.0
		
		var space_state = get_world_3d().direct_space_state
		var target_position = player.get_target_position() if player.has_method("get_target_position") else player.global_position
		var query = PhysicsRayQueryParameters3D.create(
			global_position + Vector3.UP * 0.5,  # Start slightly above ground
			target_position,  # Aim at camera/head level
			4  # Environment layer only
		)
		query.exclude = [self]
		
		var result = space_state.intersect_ray(query)
		visibility_cache = result.is_empty()  # True if no obstacles
	
	return visibility_cache



# === BEHAVIOR CONFIGURATION ===

func set_movement_behavior(type: MovementBehavior.Type):
	"""Change movement behavior at runtime."""
	movement_behavior_type = type
	if movement_behavior:
		movement_behavior.cleanup()
	_setup_behaviors()

func set_attack_behavior(type: AttackBehavior.Type):
	"""Change attack behavior at runtime."""
	attack_behavior_type = type
	if attack_behavior:
		attack_behavior.cleanup()
	_setup_behaviors()

# === DEBUG ===

func print_status():
	"""Debug function to print enemy status."""
	print("\n=== ENEMY STATUS: ", name, " ===")
	print("Health: ", current_health, "/", max_health)
	print("Distance to player: ", "%.1f" % distance_to_player)
	print("Movement behavior: ", MovementBehavior.Type.keys()[movement_behavior_type])
	print("Attack behavior: ", AttackBehavior.Type.keys()[attack_behavior_type])
	print("Is attacking: ", is_attacking)
	print("Is dead: ", is_dead)
	print("========================\n")
