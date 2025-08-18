extends Node

# === CONTINUOUS SPAWNING SYSTEM ===
# Spawns enemies persistently to maintain maximum counts per type
# Difficulty increases over time with more enemies and new types

# === ENEMY TYPES ===
enum EnemyType {
	GRUNT,
	SNIPER,
	FLANKER,
	RUSHER,
	ARTILLERY
}

# === CONFIGURATION ===
@export var auto_start: bool = true
@export var spawn_interval: float = 2.0  # Time between spawn attempts
@export var difficulty_scaling: bool = true
@export var max_total_enemies: int = 50  # Absolute maximum enemies alive

# === ENEMY TYPE CONFIGURATION ===
# Each enemy type has its own maximum count that increases over time
var enemy_max_counts: Dictionary = {
	EnemyType.GRUNT: 3,      # Start with 3 grunts
	EnemyType.SNIPER: 0,     # No snipers initially
	EnemyType.FLANKER: 0,    # No flankers initially
	EnemyType.RUSHER: 0,     # No rushers initially
	EnemyType.ARTILLERY: 0   # No artillery initially
}

# When each enemy type should start appearing (in seconds)
var enemy_unlock_times: Dictionary = {
	EnemyType.GRUNT: 0.0,      # Available immediately
	EnemyType.SNIPER: 30.0,    # After 30 seconds
	EnemyType.FLANKER: 60.0,   # After 60 seconds
	EnemyType.RUSHER: 90.0,    # After 90 seconds
	EnemyType.ARTILLERY: 120.0 # After 120 seconds
}

# How much the max count increases per minute
var enemy_growth_rates: Dictionary = {
	EnemyType.GRUNT: 1.0,      # +1 grunt per minute
	EnemyType.SNIPER: 0.5,     # +0.5 sniper per minute
	EnemyType.FLANKER: 0.5,    # +0.5 flanker per minute
	EnemyType.RUSHER: 0.3,     # +0.3 rusher per minute
	EnemyType.ARTILLERY: 0.2   # +0.2 artillery per minute
}

# === STATE ===
var is_spawning: bool = false
var spawn_timer: Timer
var game_time: float = 0.0  # Total time since spawning started
var enemies_alive: int = 0
var enemies_by_type: Dictionary = {}  # Track enemies by type

# Spawn markers
var spawn_markers: Array[Marker3D] = []

# === SIGNALS ===
signal enemy_spawned(enemy: BaseEnemy, enemy_type: EnemyType)
signal enemy_died(enemy: BaseEnemy, enemy_type: EnemyType)
signal difficulty_increased(new_level: int)
signal enemy_type_unlocked(enemy_type: EnemyType)

func _ready():
	# Initialize enemy tracking
	for enemy_type in EnemyType.values():
		enemies_by_type[enemy_type] = 0
	
	# Create spawn timer
	spawn_timer = Timer.new()
	spawn_timer.wait_time = spawn_interval
	spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(spawn_timer)
	
	# Setup spawn markers
	_setup_spawn_markers()
	
	# Connect to GameManager for restart events
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.game_restart_requested.connect(_on_game_restart_requested)
		print("ArenaSpawnManager connected to GameManager")
	
	# Start spawning if auto-start is enabled
	if auto_start:
		start_spawning()

func _process(delta: float):
	if is_spawning:
		game_time += delta
		_update_difficulty()

func _setup_spawn_markers():
	"""Find spawn markers from the SpawnMarkers node."""
	spawn_markers.clear()
	
	# Get the SpawnMarkers node from the main scene
	var spawn_markers_node = get_tree().current_scene.get_node_or_null("SpawnMarkers")
	if spawn_markers_node:
		# Get all children of SpawnMarkers as spawn points
		for child in spawn_markers_node.get_children():
			if child is Marker3D:
				spawn_markers.append(child)
				print("Found spawn marker: ", child.name, " at ", child.global_position)
	else:
		print("WARNING: No SpawnMarkers node found!")
	
	print("ArenaSpawnManager: Found ", spawn_markers.size(), " spawn markers")



func _update_difficulty():
	"""Update enemy maximums based on game time."""
	var minutes_elapsed = game_time / 60.0
	
	for enemy_type in EnemyType.values():
		# Check if this enemy type should be unlocked yet
		if game_time < enemy_unlock_times[enemy_type]:
			continue
		
		# Calculate new maximum based on growth rate
		var base_count = 0
		if enemy_type == EnemyType.GRUNT:
			base_count = 3  # Start with 3 grunts
		
		var growth = enemy_growth_rates[enemy_type] * minutes_elapsed
		var new_max = base_count + growth
		
		# Update if maximum has increased
		if new_max > enemy_max_counts[enemy_type]:
			enemy_max_counts[enemy_type] = new_max
			#print("ArenaSpawnManager: ", EnemyType.keys()[enemy_type], " max increased to ", enemy_max_counts[enemy_type])

func _on_spawn_timer_timeout():
	"""Called when it's time to attempt spawning."""
	if not is_spawning:
		return
	
	print("ArenaSpawnManager: Spawn timer triggered - attempting spawn")
	
	# Try to spawn an enemy
	_attempt_spawn()
	
	# Restart timer
	spawn_timer.start()

func _attempt_spawn():
	"""Attempt to spawn an enemy if we're under the maximum."""
	# Don't spawn if we're at the absolute maximum
	if enemies_alive >= max_total_enemies:
		print("ArenaSpawnManager: At max total enemies, skipping spawn")
		return
	
	# Find which enemy type to spawn
	var spawn_type = _select_spawn_type()
	if spawn_type == -1:  # Use -1 instead of null for no valid type
		print("ArenaSpawnManager: No valid spawn type available")
		return  # No valid spawn type
	
	# Check if we're under the maximum for this type
	if enemies_by_type[spawn_type] >= enemy_max_counts[spawn_type]:
		print("ArenaSpawnManager: At max for type ", EnemyType.keys()[spawn_type], ", skipping spawn")
		return  # At maximum for this type
	
	print("ArenaSpawnManager: SPAWNING ENEMY TYPE: ", EnemyType.keys()[spawn_type])
	
	# Spawn the enemy
	var enemy = _spawn_enemy(spawn_type)
	if enemy:
		enemies_alive += 1
		enemies_by_type[spawn_type] += 1
		
		# Connect to enemy death
		enemy.enemy_died.connect(_on_enemy_died)
		
		enemy_spawned.emit(enemy, spawn_type)
		print("ArenaSpawnManager: Spawned ", EnemyType.keys()[spawn_type], " at position: ", enemy.global_position, " (", enemies_by_type[spawn_type], "/", enemy_max_counts[spawn_type], ")")

func _select_spawn_type() -> int:
	"""Select which enemy type to spawn based on current counts and availability."""
	var available_types: Array[int] = []
	
	for enemy_type in EnemyType.values():
		# Check if this type is unlocked
		if game_time < enemy_unlock_times[enemy_type]:
			continue
		
		# Check if we're under the maximum for this type
		if enemies_by_type[enemy_type] < enemy_max_counts[enemy_type]:
			available_types.append(enemy_type)
	
	# Return random available type, or -1 if none available
	if available_types.size() > 0:
		return available_types[randi() % available_types.size()]
	return -1

func _spawn_enemy(type: int) -> BaseEnemy:
	"""Spawn an enemy of the specified type."""
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
	if not enemy:
		print("ERROR: Failed to instantiate enemy of type: ", EnemyType.keys()[type])
		return null
	
	# Apply difficulty scaling
	if difficulty_scaling:
		var minutes_elapsed = game_time / 60.0
		var health_mult = 1.0 + (minutes_elapsed * 0.1)  # +10% health per minute
		var speed_mult = 1.0 + (minutes_elapsed * 0.05)  # +5% speed per minute
		
		enemy.max_health = int(enemy.max_health * health_mult)
		enemy.current_health = enemy.max_health
		enemy.movement_speed *= speed_mult
	
	# Add to scene first
	get_tree().current_scene.add_child(enemy)
	
	# Set spawn position IMMEDIATELY after being added to tree
	var spawn_pos = _get_spawn_position()
	print("ArenaSpawnManager: Setting enemy position to ", spawn_pos)
	enemy.global_position = spawn_pos
	
	# VERIFY position was set correctly
	print("ArenaSpawnManager: Enemy final position: ", enemy.global_position, " (should be: ", spawn_pos, ")")
	
	return enemy

func _get_spawn_position() -> Vector3:
	"""Get a random spawn position from available markers."""
	if spawn_markers.size() == 0:
		print("WARNING: No spawn markers, using origin")
		return Vector3.ZERO
	
	# Get random marker
	var marker = spawn_markers[randi() % spawn_markers.size()]
	var spawn_pos = marker.global_position
	
	# STRICT ENFORCEMENT: Log exact spawn position
	print("ArenaSpawnManager: SPAWNING AT EXACT MARKER POSITION - Marker: ", marker.name, " Position: ", spawn_pos)
	
	return spawn_pos

func _on_enemy_died(enemy: BaseEnemy):
	"""Called when an enemy dies."""
	enemies_alive -= 1
	
	# Find which type this enemy was and decrement its count
	for enemy_type in EnemyType.values():
		if enemy.scene_file_path.get_file().get_basename().to_upper() == EnemyType.keys()[enemy_type]:
			enemies_by_type[enemy_type] -= 1
			enemy_died.emit(enemy, enemy_type)
			break
	
	print("ArenaSpawnManager: ENEMY DIED - ", enemies_alive, " total remaining - NEXT SPAWN WILL BE MONITORED")

func _on_game_restart_requested():
	"""Called when game is restarting - reset spawning system."""
	print("ArenaSpawnManager: Game restarting, resetting spawning system")
	stop_spawning()
	game_time = 0.0
	enemies_alive = 0
	
	# Reset enemy counts
	for enemy_type in EnemyType.values():
		enemies_by_type[enemy_type] = 0
	
	# Reset enemy maximums to starting values
	enemy_max_counts = {
		EnemyType.GRUNT: 3,
		EnemyType.SNIPER: 0,
		EnemyType.FLANKER: 0,
		EnemyType.RUSHER: 0,
		EnemyType.ARTILLERY: 0
	}
	
	# Wait for scene to reload, then restart spawning
	await get_tree().process_frame
	await get_tree().process_frame  # Wait a bit more to ensure scene is fully loaded
	
	# Re-setup spawn markers for the new scene
	_setup_spawn_markers()
	
	# Restart spawning if auto-start is enabled
	if auto_start:
		print("ArenaSpawnManager: Restarting spawning after game restart")
		start_spawning()

# === PUBLIC API ===

func start_spawning():
	"""Start the continuous spawning system."""
	if is_spawning:
		return
	
	is_spawning = true
	game_time = 0.0
	spawn_timer.start()
	print("ArenaSpawnManager: Started continuous spawning")

func stop_spawning():
	"""Stop the continuous spawning system."""
	is_spawning = false
	if spawn_timer:
		spawn_timer.stop()
	print("ArenaSpawnManager: Stopped spawning")

func get_current_stats() -> Dictionary:
	"""Get current spawning statistics."""
	var stats = {
		"game_time": game_time,
		"enemies_alive": enemies_alive,
		"max_total_enemies": max_total_enemies,
		"enemy_counts": enemies_by_type.duplicate(),
		"enemy_maximums": enemy_max_counts.duplicate()
	}
	return stats

func set_spawn_interval(interval: float):
	"""Set the spawn interval."""
	spawn_interval = interval
	if spawn_timer:
		spawn_timer.wait_time = interval

func set_max_total_enemies(max_enemies: int):
	"""Set the absolute maximum number of enemies alive."""
	max_total_enemies = max_enemies

func set_enemy_unlock_time(enemy_type: int, unlock_time: float):
	"""Set when an enemy type should start appearing."""
	enemy_unlock_times[enemy_type] = unlock_time

func set_enemy_growth_rate(enemy_type: int, growth_rate: float):
	"""Set how quickly an enemy type's maximum count increases."""
	enemy_growth_rates[enemy_type] = growth_rate

func force_spawn_enemy(enemy_type: int):
	"""Force spawn a specific enemy type (ignores limits)."""
	var enemy = _spawn_enemy(enemy_type)
	if enemy:
		enemies_alive += 1
		enemies_by_type[enemy_type] += 1
		enemy.enemy_died.connect(_on_enemy_died)
		enemy_spawned.emit(enemy, enemy_type)
		print("ArenaSpawnManager: Force spawned ", EnemyType.keys()[enemy_type])

# === DEBUG ===

func print_status():
	"""Debug function to print current spawning status."""
	print("\n=== ARENA SPAWN MANAGER STATUS ===")
	print("Game time: ", "%.1f" % game_time, " seconds")
	print("Enemies alive: ", enemies_alive, "/", max_total_enemies)
	print("Spawning: ", is_spawning)
	print("\nEnemy counts:")
	for enemy_type in EnemyType.values():
		var type_name = EnemyType.keys()[enemy_type]
		var current = enemies_by_type[enemy_type]
		var maximum = enemy_max_counts[enemy_type]
		var unlocked = game_time >= enemy_unlock_times[enemy_type]
		print("  ", type_name, ": ", current, "/", maximum, " (unlocked: ", unlocked, ")")
	print("===============================\n")
