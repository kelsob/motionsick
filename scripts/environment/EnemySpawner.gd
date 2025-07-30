extends Node3D

# === SPAWNER CONFIGURATION ===
@export var enemy_scene: PackedScene
@export var spawn_interval: float = 5.0
@export var max_enemies: int = 5
@export var spawn_radius: float = 20.0
@export var min_spawn_distance: float = 10.0  # Minimum distance from player
@export var spawn_on_enemy_death: bool = true
@export var auto_spawn: bool = true

# === STATE ===
var spawn_timer: float = 0.0
var current_enemies: Array[Node3D] = []
var player_reference: Node3D = null

# === SIGNALS ===
signal enemy_spawned(enemy: Node3D)
signal max_enemies_reached

func _ready():
	# Find player reference
	player_reference = get_tree().get_first_node_in_group("player")
	if not player_reference:
		print("Warning: EnemySpawner couldn't find player!")
	
	# Connect to existing enemies if any
	connect_to_existing_enemies()
	
	# Start spawn timer
	spawn_timer = spawn_interval

func _process(delta):
	if auto_spawn:
		spawn_timer -= delta
		
		if spawn_timer <= 0.0 and can_spawn():
			spawn_enemy()
			spawn_timer = spawn_interval

func connect_to_existing_enemies():
	"""Connect to enemies that already exist in the scene."""
	var enemies = get_tree().get_nodes_in_group("enemies")
	for enemy in enemies:
		if enemy and enemy.has_signal("enemy_died"):
			add_enemy_to_tracking(enemy)

func can_spawn() -> bool:
	"""Check if we can spawn a new enemy."""
	# Clean up dead enemies from tracking
	current_enemies = current_enemies.filter(func(enemy): return is_instance_valid(enemy))
	
	if current_enemies.size() >= max_enemies:
		max_enemies_reached.emit()
		return false
	
	return player_reference != null

func spawn_enemy() -> Node3D:
	"""Spawn a new enemy at a valid position."""
	if not enemy_scene:
		print("Error: No enemy scene assigned to spawner!")
		return null
	
	var spawn_position = get_valid_spawn_position()
	if spawn_position == Vector3.INF:
		print("Warning: Couldn't find valid spawn position")
		return null
	
	# Instantiate enemy
	var enemy = enemy_scene.instantiate() as Node3D
	if not enemy:
		print("Error: Failed to instantiate enemy scene")
		return null
	
	# Add to scene tree first
	add_child(enemy)
	
	# Set position after node is in tree
	enemy.global_position = spawn_position
	
	# Add to groups
	enemy.add_to_group("enemies")
	
	# Track enemy
	add_enemy_to_tracking(enemy)
	
	print("Enemy spawned at: ", spawn_position)
	enemy_spawned.emit(enemy)
	
	return enemy

func add_enemy_to_tracking(enemy: Node3D):
	"""Add enemy to tracking and connect death signal."""
	if not enemy in current_enemies:
		current_enemies.append(enemy)
	
	# Connect death signal if available
	if enemy.has_signal("enemy_died") and not enemy.enemy_died.is_connected(_on_enemy_died):
		enemy.enemy_died.connect(_on_enemy_died.bind(enemy))

func get_valid_spawn_position() -> Vector3:
	"""Find a valid spawn position around the player."""
	if not player_reference:
		return Vector3.INF
	
	var player_pos = player_reference.global_position
	var attempts = 20  # Try up to 20 times to find a valid position
	
	for attempt in attempts:
		# Generate random position in a circle around spawner
		var angle = randf() * TAU
		var distance = randf_range(min_spawn_distance, spawn_radius)
		
		var spawn_pos = global_position + Vector3(
			cos(angle) * distance,
			0,  # Spawn at spawner height
			sin(angle) * distance
		)
		
		# Check distance from player
		if spawn_pos.distance_to(player_pos) >= min_spawn_distance:
			# Optional: Add raycast check to ensure spawn position is valid
			if is_position_valid(spawn_pos):
				return spawn_pos
	
	return Vector3.INF

func is_position_valid(position: Vector3) -> bool:
	"""Check if a position is valid for spawning (not inside walls, etc.)."""
	# Simple check - you can expand this with raycast collision detection
	return true

func _on_enemy_died(enemy: Node3D):
	"""Called when an enemy dies."""
	print("Enemy died, removing from tracking")
	
	# Remove from tracking
	current_enemies.erase(enemy)
	
	# Spawn replacement if enabled
	if spawn_on_enemy_death and can_spawn():
		# Delay spawn slightly
		await get_tree().create_timer(1.0).timeout
		spawn_enemy()

# === PUBLIC API ===
func force_spawn() -> Node3D:
	"""Force spawn an enemy regardless of limits."""
	return spawn_enemy()

func clear_all_enemies():
	"""Remove all tracked enemies."""
	for enemy in current_enemies:
		if is_instance_valid(enemy):
			enemy.queue_free()
	current_enemies.clear()

func get_enemy_count() -> int:
	"""Get current number of alive enemies."""
	current_enemies = current_enemies.filter(func(enemy): return is_instance_valid(enemy))
	return current_enemies.size()

func set_spawn_interval(new_interval: float):
	"""Change spawn interval."""
	spawn_interval = new_interval
	spawn_timer = min(spawn_timer, spawn_interval)

func set_max_enemies(new_max: int):
	"""Change maximum enemy count."""
	max_enemies = new_max 
