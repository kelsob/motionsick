extends Node3D
class_name EnemySpawner

# === ENHANCED ENEMY SPAWNER ===
# Spawns different enemy types with configurable behaviors

enum EnemyType {
	GRUNT,      # Melee chaser
	SNIPER,     # Long-range charged shots
	FLANKER,    # Tactical burst attacker
	RUSHER,     # Fast ranged attacker
	ARTILLERY   # Heavy explosive attacks
}

# === CONFIGURATION ===
@export_group("Spawning")
@export var enemy_type: EnemyType = EnemyType.GRUNT
@export var spawn_on_ready: bool = true
@export var respawn_delay: float = 10.0
@export var max_spawns: int = -1  # -1 for infinite

@export_group("Spawn Area")
@export var spawn_radius: float = 2.0
@export var avoid_player_distance: float = 5.0

@export_group("Behavior Overrides")
@export var override_movement: bool = false
@export var movement_override: MovementBehavior.Type = MovementBehavior.Type.CHASE
@export var override_attack: bool = false
@export var attack_override: AttackBehavior.Type = AttackBehavior.Type.MELEE

@export_group("Stat Overrides")
@export var override_health: bool = false
@export var health_override: int = 100
@export var override_speed: bool = false
@export var speed_override: float = 5.0

# === STATE ===
var current_enemy: BaseEnemy = null
var spawn_count: int = 0
var respawn_timer: Timer

# === SIGNALS ===
signal enemy_spawned(enemy: BaseEnemy)
signal enemy_killed(enemy: BaseEnemy)

func _ready():
	# Create respawn timer
	respawn_timer = Timer.new()
	respawn_timer.wait_time = respawn_delay
	respawn_timer.one_shot = true
	respawn_timer.timeout.connect(_spawn_enemy)
	add_child(respawn_timer)
	
	if spawn_on_ready:
		_spawn_enemy()

func _spawn_enemy():
	if max_spawns >= 0 and spawn_count >= max_spawns:
		return
	
	if current_enemy and is_instance_valid(current_enemy):
		return  # Enemy still alive
	
	# Get spawn position
	var spawn_pos = _get_spawn_position()
	if spawn_pos == Vector3.ZERO:
		print("EnemySpawner: Could not find valid spawn position")
		return
	
	# Create enemy of specified type
	var enemy = _create_enemy_of_type(enemy_type)
	if not enemy:
		print("EnemySpawner: Failed to create enemy of type: ", EnemyType.keys()[enemy_type])
		return
	
	# Add to tree and set position both deferred to avoid timing conflicts
	get_tree().current_scene.add_child.call_deferred(enemy)
	enemy.call_deferred("set_global_position", spawn_pos)
	
	# Apply overrides
	_apply_overrides(enemy)
	
	# Connect to enemy death
	enemy.enemy_died.connect(_on_enemy_died)
	
	current_enemy = enemy
	spawn_count += 1
	
	enemy_spawned.emit(enemy)
	print("EnemySpawner: Spawned ", EnemyType.keys()[enemy_type], " at ", spawn_pos)

func _create_enemy_of_type(type: EnemyType) -> BaseEnemy:
	"""Create an enemy of the specified type by loading its scene file."""
	var enemy_scene: PackedScene
	
	match type:
		EnemyType.GRUNT:
			enemy_scene = preload("res://scenes/enemies/Grunt.tscn")
		EnemyType.SNIPER:
			enemy_scene = preload("res://scenes/enemies/Sniper.tscn")
		EnemyType.FLANKER:
			enemy_scene = preload("res://scenes/enemies/Flanker.tscn")
		EnemyType.RUSHER:
			enemy_scene = preload("res://scenes/enemies/Rusher.tscn")
		EnemyType.ARTILLERY:
			enemy_scene = preload("res://scenes/enemies/Artillery.tscn")
		_:
			enemy_scene = preload("res://scenes/enemies/Grunt.tscn")
	
	var enemy = enemy_scene.instantiate() as BaseEnemy
	return enemy

func _apply_overrides(enemy: BaseEnemy):
	"""Apply any configured overrides to the enemy."""
	if override_health:
		enemy.max_health = health_override
		enemy.current_health = health_override
	
	if override_speed:
		enemy.movement_speed = speed_override
	
	if override_movement:
		enemy.set_movement_behavior(movement_override)
	
	if override_attack:
		enemy.set_attack_behavior(attack_override)

func _get_spawn_position() -> Vector3:
	"""Get a valid spawn position within the spawn radius."""
	var player = get_tree().get_first_node_in_group("player")
	var attempts = 10
	
	for i in range(attempts):
		# Random position within spawn radius
		var angle = randf() * TAU
		var distance = randf() * spawn_radius
		var offset = Vector3(cos(angle) * distance, 0, sin(angle) * distance)
		var potential_pos = global_position + offset
		
		# Check if too close to player
		if player:
			var player_distance = potential_pos.distance_to(player.global_position)
			if player_distance < avoid_player_distance:
				continue
		
		# Check if position is valid (not inside walls, etc.)
		if _is_position_valid(potential_pos):
			return potential_pos
	
	# Fallback to spawner position
	return global_position

func _is_position_valid(pos: Vector3) -> bool:
	"""Check if a position is valid for spawning."""
	var space_state = get_world_3d().direct_space_state
	
	# Check for obstacles
	var query = PhysicsRayQueryParameters3D.create(
		pos + Vector3.UP * 2.0,  # Start above
		pos - Vector3.UP * 1.0,  # End below
		4  # Environment layer
	)
	
	var result = space_state.intersect_ray(query)
	return not result.is_empty()  # True if there's ground

func _on_enemy_died(enemy: BaseEnemy):
	"""Called when the spawned enemy dies."""
	enemy_killed.emit(enemy)
	current_enemy = null
	
	# Start respawn timer if we haven't reached max spawns
	if max_spawns < 0 or spawn_count < max_spawns:
		respawn_timer.start()

# === PUBLIC API ===

func spawn_now():
	"""Force spawn an enemy immediately."""
	_spawn_enemy()

func clear_enemy():
	"""Remove the current enemy."""
	if current_enemy and is_instance_valid(current_enemy):
		current_enemy.queue_free()
	current_enemy = null

func set_enemy_type(type: EnemyType):
	"""Change the enemy type to spawn."""
	enemy_type = type

func get_current_enemy() -> BaseEnemy:
	"""Get the currently spawned enemy."""
	return current_enemy

# === DEBUG ===

func print_status():
	"""Debug function to print spawner status."""
	print("\n=== ENEMY SPAWNER STATUS ===")
	print("Enemy Type: ", EnemyType.keys()[enemy_type])
	print("Current Enemy: ", current_enemy.name if current_enemy else "None")
	print("Spawn Count: ", spawn_count, "/", max_spawns if max_spawns >= 0 else "∞")
	print("Respawn Timer: ", "%.1f" % respawn_timer.time_left if respawn_timer.time_left > 0 else "Not running")
	print("===========================\n")
