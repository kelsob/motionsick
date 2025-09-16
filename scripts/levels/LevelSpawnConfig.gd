extends Node

# === LEVEL SPAWN CONFIGURATION ===
# Add this to any level scene to configure enemy spawning for that specific level
# This script tells ArenaSpawnManager what, when, and where to spawn

## === EXPORTED CONFIGURATION ===
@export_group("Spawn Control")
## Enable enemy spawning for this level
@export var enable_spawning: bool = true
## Auto-start spawning when level loads
@export var auto_start_spawning: bool = true
## Time between spawn attempts (seconds)
@export var spawn_interval: float = 2.0
## Maximum total enemies alive at once
@export var max_total_enemies: int = 15
## Telegraph duration before enemy spawns
@export var telegraph_duration: float = 3.0

@export_group("Enemy Configuration")
## Maximum Grunt enemies
@export var max_grunt_enemies: int = 8
## Maximum Sniper enemies  
@export var max_sniper_enemies: int = 2
## Maximum Flanker enemies
@export var max_flanker_enemies: int = 3
## Maximum Rusher enemies
@export var max_rusher_enemies: int = 2
## Maximum Artillery enemies
@export var max_artillery_enemies: int = 1

@export_group("Enemy Unlock Timing")
## When Grunt enemies start appearing (seconds)
@export var grunt_unlock_time: float = 0.0
## When Sniper enemies start appearing (seconds)
@export var sniper_unlock_time: float = 30.0
## When Flanker enemies start appearing (seconds)
@export var flanker_unlock_time: float = 60.0
## When Rusher enemies start appearing (seconds)
@export var rusher_unlock_time: float = 90.0
## When Artillery enemies start appearing (seconds)
@export var artillery_unlock_time: float = 120.0

@export_group("Difficulty Scaling")
## Enable difficulty scaling over time
@export var enable_difficulty_scaling: bool = true
## Health scaling per minute (e.g., 0.1 = +10% per minute)
@export var health_scaling_per_minute: float = 0.1
## Speed scaling per minute (e.g., 0.05 = +5% per minute)
@export var speed_scaling_per_minute: float = 0.05

@export_group("Spawn Markers")
## Node path to spawn markers container (relative to level scene)
@export var spawn_markers_path: String = "SpawnMarkers"

@export_group("Debug Settings")
## Enable debug output for spawn configuration
@export var debug_spawn_config: bool = false

## === RUNTIME STATE ===
var arena_spawn_manager: Node = null
var spawn_markers_node: Node = null
var is_configured: bool = false

func _ready():
	# Wait for level to be fully loaded
	await get_tree().process_frame
	
	# Configure the ArenaSpawnManager for this level
	_configure_spawn_manager()

func _configure_spawn_manager():
	"""Configure the global ArenaSpawnManager with this level's settings."""
	arena_spawn_manager = get_node_or_null("/root/ArenaSpawnManager")
	if not arena_spawn_manager:
		if debug_spawn_config:
			print("LevelSpawnConfig: ArenaSpawnManager not found!")
		return
	
	if debug_spawn_config:
		print("LevelSpawnConfig: Configuring spawn manager for level")
	
	# Configure basic spawn settings
	arena_spawn_manager.spawn_interval = spawn_interval
	arena_spawn_manager.max_total_enemies = max_total_enemies
	arena_spawn_manager.telegraph_duration = telegraph_duration
	arena_spawn_manager.difficulty_scaling = enable_difficulty_scaling
	arena_spawn_manager.disable_spawning = not enable_spawning
	
	# Configure enemy maximum counts
	arena_spawn_manager.enemy_max_counts = {
		arena_spawn_manager.EnemyType.GRUNT: max_grunt_enemies,
		arena_spawn_manager.EnemyType.SNIPER: max_sniper_enemies,
		arena_spawn_manager.EnemyType.FLANKER: max_flanker_enemies,
		arena_spawn_manager.EnemyType.RUSHER: max_rusher_enemies,
		arena_spawn_manager.EnemyType.ARTILLERY: max_artillery_enemies
	}
	
	# Configure enemy unlock times
	arena_spawn_manager.enemy_unlock_times = {
		arena_spawn_manager.EnemyType.GRUNT: grunt_unlock_time,
		arena_spawn_manager.EnemyType.SNIPER: sniper_unlock_time,
		arena_spawn_manager.EnemyType.FLANKER: flanker_unlock_time,
		arena_spawn_manager.EnemyType.RUSHER: rusher_unlock_time,
		arena_spawn_manager.EnemyType.ARTILLERY: artillery_unlock_time
	}
	
	# Configure difficulty scaling
	if arena_spawn_manager.has_method("set_difficulty_scaling"):
		arena_spawn_manager.set_difficulty_scaling(health_scaling_per_minute, speed_scaling_per_minute)
	
	# Find and configure spawn markers
	_setup_spawn_markers()
	
	# Start spawning if auto-start is enabled
	if auto_start_spawning and enable_spawning:
		arena_spawn_manager.start_spawning()
		if debug_spawn_config:
			print("LevelSpawnConfig: Started spawning with auto-start")
	
	is_configured = true
	
	if debug_spawn_config:
		print("LevelSpawnConfig: Configuration complete")
		print("  Max enemies: ", max_total_enemies)
		print("  Spawn interval: ", spawn_interval)
		print("  Enemy maxes: Grunt=", max_grunt_enemies, " Sniper=", max_sniper_enemies, " Flanker=", max_flanker_enemies)

func _setup_spawn_markers():
	"""Find spawn markers and pass them to ArenaSpawnManager."""
	spawn_markers_node = get_node_or_null(spawn_markers_path)
	if not spawn_markers_node:
		if debug_spawn_config:
			print("LevelSpawnConfig: Spawn markers not found at: ", spawn_markers_path)
		return
	
	# Get all marker children
	var markers: Array[Marker3D] = []
	for child in spawn_markers_node.get_children():
		if child is Marker3D:
			markers.append(child)
	
	# Pass markers to ArenaSpawnManager
	if arena_spawn_manager and arena_spawn_manager.has_method("set_spawn_markers"):
		arena_spawn_manager.set_spawn_markers(markers)
		if debug_spawn_config:
			print("LevelSpawnConfig: Configured ", markers.size(), " spawn markers")

# === PUBLIC API ===

func start_spawning():
	"""Manually start spawning (if auto-start is disabled)."""
	if arena_spawn_manager and is_configured:
		arena_spawn_manager.start_spawning()

func stop_spawning():
	"""Stop spawning for this level."""
	if arena_spawn_manager:
		arena_spawn_manager.stop_spawning()

func update_enemy_max(enemy_type: String, new_max: int):
	"""Update maximum count for a specific enemy type at runtime."""
	if not arena_spawn_manager:
		return
	
	match enemy_type.to_lower():
		"grunt":
			max_grunt_enemies = new_max
			arena_spawn_manager.enemy_max_counts[arena_spawn_manager.EnemyType.GRUNT] = new_max
		"sniper":
			max_sniper_enemies = new_max
			arena_spawn_manager.enemy_max_counts[arena_spawn_manager.EnemyType.SNIPER] = new_max
		"flanker":
			max_flanker_enemies = new_max
			arena_spawn_manager.enemy_max_counts[arena_spawn_manager.EnemyType.FLANKER] = new_max
		"rusher":
			max_rusher_enemies = new_max
			arena_spawn_manager.enemy_max_counts[arena_spawn_manager.EnemyType.RUSHER] = new_max
		"artillery":
			max_artillery_enemies = new_max
			arena_spawn_manager.enemy_max_counts[arena_spawn_manager.EnemyType.ARTILLERY] = new_max
	
	if debug_spawn_config:
		print("LevelSpawnConfig: Updated ", enemy_type, " max to: ", new_max)

func get_spawn_stats() -> Dictionary:
	"""Get current spawn statistics."""
	if arena_spawn_manager and arena_spawn_manager.has_method("get_current_stats"):
		return arena_spawn_manager.get_current_stats()
	return {}

# === DEBUG ===

func print_spawn_config():
	"""Debug function to print current spawn configuration."""
	print("\n=== LEVEL SPAWN CONFIG ===")
	print("Level: ", get_parent().name if get_parent() else "Unknown")
	print("Spawning enabled: ", enable_spawning)
	print("Auto-start: ", auto_start_spawning)
	print("Spawn interval: ", spawn_interval, "s")
	print("Max total enemies: ", max_total_enemies)
	print("Enemy maximums:")
	print("  Grunt: ", max_grunt_enemies)
	print("  Sniper: ", max_sniper_enemies)
	print("  Flanker: ", max_flanker_enemies)
	print("  Rusher: ", max_rusher_enemies)
	print("  Artillery: ", max_artillery_enemies)
	print("Unlock times:")
	print("  Grunt: ", grunt_unlock_time, "s")
	print("  Sniper: ", sniper_unlock_time, "s")
	print("  Flanker: ", flanker_unlock_time, "s")
	print("  Rusher: ", rusher_unlock_time, "s")
	print("  Artillery: ", artillery_unlock_time, "s")
	print("Configured: ", is_configured)
	print("========================\n")
