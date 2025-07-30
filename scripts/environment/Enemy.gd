extends CharacterBody3D

# === ENEMY CONFIGURATION ===
@export var max_health: int = 100
@export var death_effect_duration: float = 0.5
@export var move_speed: float = 3.0
@export var detection_range: float = 15.0
@export var stop_distance: float = 2.0  # How close to get to player before stopping

# === STATE ===
var current_health: int
var is_dead: bool = false
var player_reference: Node3D = null

# === PHYSICS ===
@onready var GRAVITY: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# === COMPONENTS ===
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var collision_shape: CollisionShape3D = $CollisionShape3D

# === SIGNALS ===
signal health_changed(new_health: int, max_health: int)
signal enemy_died
signal damage_taken(damage: int)

func _ready():
	current_health = max_health
	
	# Set enemy collision layers - layer 8 corresponds to bit 4 (value 8)
	# But the scene file uses 128 which is bit 8 (value 128)
	# Let's use what's in the scene file for consistency
	collision_layer = 128  # Enemy layer (bit 8) - matches scene file
	collision_mask = 5   # Collide with Environment (4) + Player (1)
	
	# Find player reference
	player_reference = get_tree().get_first_node_in_group("player")
	if not player_reference:
		print("Warning: Enemy couldn't find player!")
	
	health_changed.emit(current_health, max_health)

func _physics_process(delta):
	if is_dead:
		return
	
	# Apply gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		if velocity.y < 0:
			velocity.y = 0
	
	# Move towards player
	handle_movement_towards_player(delta)
	
	# Apply movement
	move_and_slide()

func handle_movement_towards_player(delta):
	if not player_reference:
		return
	
	var distance_to_player = global_position.distance_to(player_reference.global_position)
	
	# Always chase player unless we're too close
	if distance_to_player > stop_distance:
		# Calculate direction to player (only on XZ plane to avoid flying)
		var direction_to_player = (player_reference.global_position - global_position)
		direction_to_player.y = 0  # Remove vertical component
		direction_to_player = direction_to_player.normalized()
		
		# Move towards player
		velocity.x = direction_to_player.x * move_speed
		velocity.z = direction_to_player.z * move_speed
		
		# Look at player (with safety check)
		var look_direction = player_reference.global_position - global_position
		look_direction.y = 0  # Keep enemy upright
		if look_direction.length() > 0.01:  # Only look_at if direction is valid
			look_at(global_position + look_direction.normalized(), Vector3.UP)
	else:
		# Stop horizontal movement if player is too far or too close
		velocity.x = lerp(velocity.x, 0.0, 5.0 * delta)
		velocity.z = lerp(velocity.z, 0.0, 5.0 * delta)

func take_damage(damage: int):
	if is_dead:
		return
	
	current_health -= damage
	current_health = max(0, current_health)
	
	print("Enemy took ", damage, " damage. Health: ", current_health, "/", max_health)
	
	damage_taken.emit(damage)
	health_changed.emit(current_health, max_health)
	
	# Flash red briefly to indicate damage
	_flash_damage()
	
	if current_health <= 0:
		die()

func die():
	if is_dead:
		return
	
	is_dead = true
	print("Enemy died!")
	
	enemy_died.emit()
	
	# Death animation - simple fade and scale down
	_play_death_animation()

func _flash_damage():
	if not mesh or not mesh.material_override:
		# Create a simple material for flashing
		var material = StandardMaterial3D.new()
		material.albedo_color = Color.RED
		mesh.material_override = material
		
		# Remove flash after brief moment
		var flash_timer = Timer.new()
		flash_timer.wait_time = 0.1
		flash_timer.one_shot = true
		flash_timer.timeout.connect(func():
			if mesh:
				mesh.material_override = null
			flash_timer.queue_free()
		)
		add_child(flash_timer)
		flash_timer.start()

func _play_death_animation():
	# Disable collision (deferred to avoid physics query conflicts)
	call_deferred("set", "collision_shape.disabled", true)
	
	# Simple death animation - scale down and fade
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Scale to very small but not zero (prevents singular matrix)
	tween.tween_property(self, "scale", Vector3.ONE * 0.001, death_effect_duration)
	
	# Optionally rotate while scaling
	tween.tween_property(self, "rotation", rotation + Vector3(0, TAU * 2, 0), death_effect_duration)
	
	# Remove enemy after animation
	tween.tween_callback(queue_free).set_delay(death_effect_duration)

# === PUBLIC API ===
func get_health() -> int:
	return current_health

func get_max_health() -> int:
	return max_health

func is_enemy_dead() -> bool:
	return is_dead

func heal(amount: int):
	if is_dead:
		return
	
	current_health += amount
	current_health = min(max_health, current_health)
	health_changed.emit(current_health, max_health)

func reset_health():
	current_health = max_health
	is_dead = false
	collision_shape.disabled = false
	scale = Vector3.ONE
	health_changed.emit(current_health, max_health) 
