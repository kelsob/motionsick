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

# Movement state
var target_position: Vector3
var movement_direction: Vector3
var distance_to_player: float

# Time system integration
var time_manager: Node = null
var time_affected: TimeAffected = null

# === COMPONENTS ===
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var attack_timer: Timer = $AttackTimer
@onready var state_timer: Timer = $StateTimer

# === SIGNALS ===
signal health_changed(current: int, max: int)
signal enemy_died(enemy: BaseEnemy)
signal player_detected(player: Node3D)
signal attack_started()
signal attack_finished()

func _ready():
	# Initialize health
	current_health = max_health
	
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
	
	# Add to enemy group
	add_to_group("enemies")
	
	# Initialize behaviors
	_setup_behaviors()
	
	# Customize appearance
	_setup_appearance()
	
	# Connect timers
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	state_timer.timeout.connect(_on_state_timer_timeout)
	
	print("Enemy spawned: ", name, " | Movement: ", MovementBehavior.Type.keys()[movement_behavior_type], " | Attack: ", AttackBehavior.Type.keys()[attack_behavior_type])

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
	
	_update_player_tracking()
	_update_movement(time_delta)
	_update_attack_logic(time_delta)
	_apply_movement(time_delta)

func _update_player_tracking():
	"""Update distance and direction to player."""
	if not player:
		return
		
	distance_to_player = global_position.distance_to(player.global_position)
	
	# Check if player is in detection range
	if distance_to_player <= detection_range:
		player_detected.emit(player)

func _update_movement(delta):
	"""Update movement using the assigned movement behavior."""
	if movement_behavior:
		# Check if time is frozen - if so, don't update movement direction
		var is_frozen = time_affected and time_affected.is_time_frozen()
		if is_frozen:
			movement_direction = Vector3.ZERO  # Reset movement when frozen
		else:
			movement_direction = movement_behavior.get_movement_direction(delta)

func _update_attack_logic(delta):
	"""Update attack logic using the assigned attack behavior."""
	if attack_behavior and distance_to_player <= attack_range and not is_attacking:
		if attack_behavior.should_attack(delta):
			_start_attack()

func _apply_movement(delta):
	"""Apply movement to the enemy."""
	if movement_direction.length() > 0:
		# Face movement direction - keep enemy upright by only rotating around Y-axis
		var flat_direction = Vector3(movement_direction.x, 0, movement_direction.z).normalized()
		if flat_direction.length() > 0.001:
			var target_transform = global_transform.looking_at(global_position + flat_direction, Vector3.UP)
			global_transform = global_transform.interpolate_with(target_transform, turn_speed * delta)
		
		# Apply movement with time scaling
		var effective_time_scale = time_affected.get_effective_time_scale() if time_affected else 1.0
		
		# Safety check: prevent extreme movement speeds
		effective_time_scale = clamp(effective_time_scale, 0.1, 5.0)  # Limit time scale effects
		
		# Additional safety: if time was recently frozen, limit movement
		if time_affected and time_affected.is_time_frozen():
			effective_time_scale = min(effective_time_scale, 1.0)  # Don't allow speed boost after freeze
		
		velocity = movement_direction * movement_speed * effective_time_scale
		
		# Debug: Check for extreme movement
		if velocity.length() > 50.0:  # Very fast movement
			print("WARNING: ", name, " moving very fast! Velocity: ", velocity.length(), " Time scale: ", effective_time_scale)
	else:
		velocity = Vector3.ZERO
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= 20.0 * delta  # Simple gravity
	
	var old_pos = global_position
	move_and_slide()
	
	# Debug: Check for large position changes
	var pos_change = global_position.distance_to(old_pos)
	if pos_change > 10.0:  # Large position change
		print("WARNING: ", name, " moved ", pos_change, " units in one frame! From ", old_pos, " to ", global_position)

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

func get_direction_to_player() -> Vector3:
	"""Get normalized direction vector to player."""
	if player:
		return (player.global_position - global_position).normalized()
	return Vector3.ZERO

func is_player_in_range(range: float) -> bool:
	"""Check if player is within specified range."""
	return distance_to_player <= range

func is_player_visible() -> bool:
	"""Check if player is visible (no obstacles blocking line of sight)."""
	if not player:
		return false
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 0.5,  # Start slightly above ground
		player.global_position + Vector3.UP * 0.5,
		4  # Environment layer only
	)
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	return result.is_empty()  # True if no obstacles

func set_target_position(pos: Vector3):
	"""Set a target position for movement behaviors."""
	target_position = pos

func get_target_position() -> Vector3:
	"""Get current target position."""
	return target_position

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
