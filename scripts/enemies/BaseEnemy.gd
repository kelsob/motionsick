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
		movement_direction = movement_behavior.get_movement_direction(delta)

func _update_attack_logic(delta):
	"""Update attack logic using the assigned attack behavior."""
	if attack_behavior and distance_to_player <= attack_range and not is_attacking:
		if attack_behavior.should_attack(delta):
			_start_attack()

func _apply_movement(delta):
	"""Apply movement to the enemy."""
	if movement_direction.length() > 0:
		# Face movement direction
		var target_rotation = Vector3.FORWARD.cross(movement_direction.normalized())
		if target_rotation.length() > 0.001:
			var target_transform = global_transform.looking_at(global_position + movement_direction.normalized())
			global_transform = global_transform.interpolate_with(target_transform, turn_speed * delta)
		
		# Apply movement with time scaling
		var effective_time_scale = time_affected.get_effective_time_scale() if time_affected else 1.0
		velocity = movement_direction * movement_speed * effective_time_scale
	else:
		velocity = Vector3.ZERO
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= 20.0 * delta  # Simple gravity
	
	move_and_slide()

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
	
	enemy_died.emit(self)
	
	# Simple death effect - fade out
	var tween = get_tree().create_tween()
	tween.tween_property(mesh, "transparency", 1.0, 1.0)
	tween.tween_callback(queue_free)

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
