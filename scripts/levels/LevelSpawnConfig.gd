extends Node

# === LEVEL SPAWN CONFIGURATION ===
# Add this to any level scene to configure enemy spawning for that specific level
# This script tells ArenaSpawnManager what, when, and where to spawn

# === SPAWN EVENT CLASS ===
# Simple class for programmatic spawn event creation
class SpawnEvent:
	var enemy_type: int
	var spawn_time: float
	var spawn_marker_index: int
	var telegraph_duration: float = -1.0
	var health_multiplier: float = 1.0
	var speed_multiplier: float = 1.0
	
	func _init(type: int, time: float, marker_idx: int = 0, telegraph: float = -1.0, health_mult: float = 1.0, speed_mult: float = 1.0):
		enemy_type = type
		spawn_time = time
		spawn_marker_index = marker_idx
		telegraph_duration = telegraph
		health_multiplier = health_mult
		speed_multiplier = speed_mult

## === EXPORTED CONFIGURATION ===
@export_group("Spawn Control")
## Enable enemy spawning for this level
@export var enable_spawning: bool = true
## Auto-start spawning when level loads
@export var auto_start_spawning: bool = true
## Default telegraph duration before enemy spawns (can be overridden per spawn)
@export var default_telegraph_duration: float = 3.0

@export_group("Legacy Continuous Spawning")
## Enable legacy continuous spawning system (for horde mode)
@export var enable_continuous_spawning: bool = false
## Time between spawn attempts (seconds) - only for continuous mode
@export var spawn_interval: float = 2.0
## Maximum total enemies alive at once - only for continuous mode
@export var max_total_enemies: int = 15

@export_group("Spawn Events")
## List of scheduled spawn events for this level
@export var spawn_events: Array[SpawnEventResource] = []

@export_group("Legacy Enemy Configuration")
## Maximum Grunt enemies - only for continuous mode
@export var max_grunt_enemies: int = 8
## Maximum Sniper enemies - only for continuous mode
@export var max_sniper_enemies: int = 2
## Maximum Flanker enemies - only for continuous mode
@export var max_flanker_enemies: int = 3
## Maximum Rusher enemies - only for continuous mode
@export var max_rusher_enemies: int = 2
## Maximum Artillery enemies - only for continuous mode
@export var max_artillery_enemies: int = 1

@export_group("Legacy Difficulty Scaling")
## Enable difficulty scaling over time - only for continuous mode
@export var enable_difficulty_scaling: bool = true
## Health scaling per minute (e.g., 0.1 = +10% per minute) - only for continuous mode
@export var health_scaling_per_minute: float = 0.1
## Speed scaling per minute (e.g., 0.05 = +5% per minute) - only for continuous mode
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
	
	# Find and configure spawn markers first
	_setup_spawn_markers()
	
	# Configure spawning mode
	if enable_continuous_spawning:
		# Legacy continuous spawning mode
		if debug_spawn_config:
			print("LevelSpawnConfig: Using continuous spawning mode")
		_configure_continuous_spawning()
	else:
		# New scheduled spawn events mode
		if debug_spawn_config:
			print("LevelSpawnConfig: Using scheduled spawn events mode")
		_configure_scheduled_spawning()
	
	is_configured = true
	
	if debug_spawn_config:
		print("LevelSpawnConfig: Configuration complete")

func _configure_continuous_spawning():
	"""Configure for legacy continuous spawning mode."""
	# Configure basic spawn settings
	arena_spawn_manager.spawn_interval = spawn_interval
	arena_spawn_manager.max_total_enemies = max_total_enemies
	arena_spawn_manager.telegraph_duration = default_telegraph_duration
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
	
	# Configure difficulty scaling
	if arena_spawn_manager.has_method("set_difficulty_scaling"):
		arena_spawn_manager.set_difficulty_scaling(health_scaling_per_minute, speed_scaling_per_minute)

func _configure_scheduled_spawning():
	"""Configure for new scheduled spawn events mode."""
	# Disable continuous spawning
	arena_spawn_manager.disable_spawning = not enable_spawning
	
	# Convert SpawnEventResource objects to SpawnEvent objects and pass to spawn manager
	var parsed_events: Array[SpawnEvent] = []
	for event_resource in spawn_events:
		if event_resource == null:
			continue  # Skip null entries
		
		var spawn_event = SpawnEvent.new(
			event_resource.enemy_type,
			event_resource.spawn_time,
			event_resource.spawn_marker_index,
			event_resource.telegraph_duration,
			event_resource.health_multiplier,
			event_resource.speed_multiplier
		)
		parsed_events.append(spawn_event)
	
	# Pass scheduled events to spawn manager
	if arena_spawn_manager.has_method("set_scheduled_spawns"):
		arena_spawn_manager.set_scheduled_spawns(parsed_events, default_telegraph_duration)
		if debug_spawn_config:
			print("LevelSpawnConfig: Configured ", parsed_events.size(), " scheduled spawn events")

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

func add_spawn_event(enemy_type: int, spawn_time: float, marker_index: int = 0, telegraph_duration: float = -1.0, health_mult: float = 1.0, speed_mult: float = 1.0):
	"""Add a spawn event to the level's spawn list."""
	var event_resource = SpawnEventResource.new()
	event_resource.enemy_type = enemy_type
	event_resource.spawn_time = spawn_time
	event_resource.spawn_marker_index = marker_index
	event_resource.telegraph_duration = telegraph_duration
	event_resource.health_multiplier = health_mult
	event_resource.speed_multiplier = speed_mult
	
	spawn_events.append(event_resource)
	
	if debug_spawn_config:
		print("LevelSpawnConfig: Added spawn event - Type: ", enemy_type, " Time: ", spawn_time, " Marker: ", marker_index)

func clear_spawn_events():
	"""Clear all spawn events."""
	spawn_events.clear()
	if debug_spawn_config:
		print("LevelSpawnConfig: Cleared all spawn events")

func create_example_spawn_sequence():
	"""Create an example spawn sequence for testing."""
	clear_spawn_events()
	
	# Example sequence: Grunt at 5s, Sniper at 10s, two Grunts at 15s
	add_spawn_event(0, 5.0, 0)   # Grunt at marker 0, 5 seconds
	add_spawn_event(1, 10.0, 1)  # Sniper at marker 1, 10 seconds  
	add_spawn_event(0, 15.0, 2)  # Grunt at marker 2, 15 seconds
	add_spawn_event(0, 15.5, 0)  # Another Grunt at marker 0, 15.5 seconds
	
	if debug_spawn_config:
		print("LevelSpawnConfig: Created example spawn sequence with ", spawn_events.size(), " events")

func get_spawn_marker_count() -> int:
	"""Get the number of available spawn markers."""
	if spawn_markers_node:
		return spawn_markers_node.get_child_count()
	return 0

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
	print("Spawning mode: ", "Scheduled Events" if not enable_continuous_spawning else "Continuous")
	
	if enable_continuous_spawning:
		print("=== CONTINUOUS MODE SETTINGS ===")
		print("Spawn interval: ", spawn_interval, "s")
		print("Max total enemies: ", max_total_enemies)
		print("Enemy maximums:")
		print("  Grunt: ", max_grunt_enemies)
		print("  Sniper: ", max_sniper_enemies)
		print("  Flanker: ", max_flanker_enemies)
		print("  Rusher: ", max_rusher_enemies)
		print("  Artillery: ", max_artillery_enemies)
	else:
		print("=== SCHEDULED EVENTS MODE ===")
		print("Default telegraph duration: ", default_telegraph_duration, "s")
		print("Spawn events: ", spawn_events.size())
		for i in range(spawn_events.size()):
			var event = spawn_events[i]
			if event == null:
				print("  Event ", i, ": NULL")
				continue
			var enemy_names = ["Grunt", "Sniper", "Flanker", "Rusher", "Artillery"]
			var enemy_name = enemy_names[event.enemy_type] if event.enemy_type < enemy_names.size() else "Unknown"
			print("  Event ", i, ": ", enemy_name, " at ", event.spawn_time, "s (marker ", event.spawn_marker_index, ")")
	
	print("Spawn markers available: ", get_spawn_marker_count())
	print("Configured: ", is_configured)
	print("========================\n")
