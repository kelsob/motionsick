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

@export_group("Level Gameplay Configuration")
## Comprehensive gameplay settings for this level (optional)
@export var gameplay_config: LevelGameplayConfig = null

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
## Node path to spawn markers container (relative to this LevelSpawnConfig node)
@export var spawn_markers_path: String = "SpawnMarkers"

@export_group("Debug Settings")
## Enable debug output for spawn configuration
@export var debug_spawn_config: bool = true

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
	
	# Apply gameplay configuration if provided
	if gameplay_config:
		_apply_gameplay_config()
	
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
	# COMPLETELY disable continuous spawning
	arena_spawn_manager.disable_spawning = not enable_spawning
	
	# Clear all enemy max counts to prevent continuous spawning
	arena_spawn_manager.enemy_max_counts = {
		arena_spawn_manager.EnemyType.GRUNT: 0,
		arena_spawn_manager.EnemyType.SNIPER: 0,
		arena_spawn_manager.EnemyType.FLANKER: 0,
		arena_spawn_manager.EnemyType.RUSHER: 0,
		arena_spawn_manager.EnemyType.ARTILLERY: 0
	}
	
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
			print("LevelSpawnConfig: Disabled continuous spawning - all enemy max counts set to 0")

func _setup_spawn_markers():
	"""Find spawn markers and pass them to ArenaSpawnManager."""
	if debug_spawn_config:
		print("LevelSpawnConfig: Looking for spawn markers...")
		print("LevelSpawnConfig: My children:")
		for child in get_children():
			print("  - ", child.name, " (", child.get_class(), ")")
	
	# First try the configured path
	spawn_markers_node = get_node_or_null(spawn_markers_path)
	
	# If not found, try to find any child named SpawnMarkers
	if not spawn_markers_node:
		if debug_spawn_config:
			print("LevelSpawnConfig: Path '", spawn_markers_path, "' not found, searching children...")
		for child in get_children():
			if child.name == "SpawnMarkers":
				spawn_markers_node = child
				if debug_spawn_config:
					print("LevelSpawnConfig: Found SpawnMarkers as direct child!")
				break
	
	if not spawn_markers_node:
		if debug_spawn_config:
			print("LevelSpawnConfig: ERROR - No SpawnMarkers node found!")
			print("LevelSpawnConfig: Make sure you have a child node named 'SpawnMarkers'")
		return
	
	if debug_spawn_config:
		print("LevelSpawnConfig: Found spawn markers node: ", spawn_markers_node.name)
		print("LevelSpawnConfig: Spawn markers node children:")
		for child in spawn_markers_node.get_children():
			print("  - ", child.name, " (", child.get_class(), ") at ", child.global_position)
	
	# Get all marker children
	var markers: Array[Marker3D] = []
	for child in spawn_markers_node.get_children():
		if child is Marker3D:
			markers.append(child)
			if debug_spawn_config:
				print("LevelSpawnConfig: Added marker: ", child.name, " at ", child.global_position)
	
	# Pass markers to ArenaSpawnManager
	if arena_spawn_manager and arena_spawn_manager.has_method("set_spawn_markers"):
		arena_spawn_manager.set_spawn_markers(markers)
		if debug_spawn_config:
			print("LevelSpawnConfig: Configured ", markers.size(), " spawn markers")
	else:
		if debug_spawn_config:
			print("LevelSpawnConfig: ERROR - Could not pass markers to ArenaSpawnManager")

func _apply_gameplay_config():
	"""Apply level-specific gameplay configuration to all relevant systems."""
	if debug_spawn_config:
		print("LevelSpawnConfig: Applying gameplay configuration")
		var overrides = gameplay_config.get_active_overrides()
		print("LevelSpawnConfig: Active overrides: ", overrides.keys())
	
	# Apply player configuration
	_apply_player_config()
	
	# Apply bullet configuration  
	_apply_bullet_config()
	
	# Apply time system configuration
	_apply_time_config()
	
	# Apply enemy configuration
	_apply_enemy_config()
	
	# Apply environmental effects
	_apply_environmental_config()
	
	# Apply audio/visual configuration
	_apply_audiovisual_config()

func _apply_player_config():
	"""Apply player-specific configuration."""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		if debug_spawn_config:
			print("LevelSpawnConfig: No player found for configuration")
		return
	
	# Starting bullet count
	if gameplay_config.starting_bullet_count != -1:
		if player.has_method("set_bullet_count"):
			player.set_bullet_count(gameplay_config.starting_bullet_count)
			if debug_spawn_config:
				print("LevelSpawnConfig: Set player bullet count to: ", gameplay_config.starting_bullet_count)
	
	# Movement speed
	if gameplay_config.player_movement_speed_multiplier != 1.0:
		if player.has_method("set_movement_speed_multiplier"):
			player.set_movement_speed_multiplier(gameplay_config.player_movement_speed_multiplier)
			if debug_spawn_config:
				print("LevelSpawnConfig: Set player movement speed multiplier to: ", gameplay_config.player_movement_speed_multiplier)
	
	# Time energy
	if gameplay_config.player_time_energy_multiplier != 1.0:
		var time_energy_manager = get_node_or_null("/root/TimeEnergyManager")
		if time_energy_manager and time_energy_manager.has_method("set_capacity_multiplier"):
			time_energy_manager.set_capacity_multiplier(gameplay_config.player_time_energy_multiplier)
			if debug_spawn_config:
				print("LevelSpawnConfig: Set time energy capacity multiplier to: ", gameplay_config.player_time_energy_multiplier)

func _apply_bullet_config():
	"""Apply bullet-specific configuration."""
	# Set global bullet multipliers that will affect all future bullets
	var bullet_manager = get_node_or_null("/root/BulletManager")
	if not bullet_manager:
		# Create a simple global bullet config if no manager exists
		if not get_tree().has_meta("level_bullet_config"):
			get_tree().set_meta("level_bullet_config", {})
		
		var bullet_config = get_tree().get_meta("level_bullet_config")
		bullet_config["speed_multiplier"] = gameplay_config.bullet_speed_multiplier
		bullet_config["damage_multiplier"] = gameplay_config.bullet_damage_multiplier
		bullet_config["bounce_multiplier"] = gameplay_config.bullet_bounce_multiplier
		bullet_config["lifetime_multiplier"] = gameplay_config.bullet_lifetime_multiplier
		bullet_config["gravity_multiplier"] = gameplay_config.bullet_gravity_multiplier
		
		if debug_spawn_config:
			print("LevelSpawnConfig: Set global bullet config: ", bullet_config)

func _apply_time_config():
	"""Apply time system configuration."""
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		if gameplay_config.disable_time_dilation:
			if time_manager.has_method("disable_time_dilation"):
				time_manager.disable_time_dilation()
				if debug_spawn_config:
					print("LevelSpawnConfig: Disabled time dilation for this level")
		
		if gameplay_config.time_dilation_strength_multiplier != 1.0:
			if time_manager.has_method("set_dilation_strength_multiplier"):
				time_manager.set_dilation_strength_multiplier(gameplay_config.time_dilation_strength_multiplier)
				if debug_spawn_config:
					print("LevelSpawnConfig: Set time dilation strength multiplier to: ", gameplay_config.time_dilation_strength_multiplier)

func _apply_enemy_config():
	"""Apply enemy configuration to spawn manager."""
	if arena_spawn_manager:
		if gameplay_config.enemy_health_multiplier != 1.0:
			if arena_spawn_manager.has_method("set_enemy_health_multiplier"):
				arena_spawn_manager.set_enemy_health_multiplier(gameplay_config.enemy_health_multiplier)
				if debug_spawn_config:
					print("LevelSpawnConfig: Set enemy health multiplier to: ", gameplay_config.enemy_health_multiplier)
		
		if gameplay_config.enemy_speed_multiplier != 1.0:
			if arena_spawn_manager.has_method("set_enemy_speed_multiplier"):
				arena_spawn_manager.set_enemy_speed_multiplier(gameplay_config.enemy_speed_multiplier)
				if debug_spawn_config:
					print("LevelSpawnConfig: Set enemy speed multiplier to: ", gameplay_config.enemy_speed_multiplier)

func _apply_environmental_config():
	"""Apply environmental effects."""
	# Set global gravity
	if gameplay_config.gravity_multiplier != 1.0:
		var default_gravity = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
		PhysicsServer3D.area_set_param(get_viewport().world_3d.space, PhysicsServer3D.AREA_PARAM_GRAVITY, default_gravity * gameplay_config.gravity_multiplier)
		if debug_spawn_config:
			print("LevelSpawnConfig: Set gravity multiplier to: ", gameplay_config.gravity_multiplier)
	
	# Apply wind force (would need a wind system to implement)
	if gameplay_config.wind_force != Vector3.ZERO:
		get_tree().set_meta("level_wind_force", gameplay_config.wind_force)
		if debug_spawn_config:
			print("LevelSpawnConfig: Set wind force to: ", gameplay_config.wind_force)

func _apply_audiovisual_config():
	"""Apply audio and visual configuration."""
	# Audio configuration
	if gameplay_config.master_volume_multiplier != 1.0:
		var master_bus = AudioServer.get_bus_index("Master")
		if master_bus != -1:
			var current_volume = AudioServer.get_bus_volume_db(master_bus)
			var new_volume = current_volume + (20.0 * log(gameplay_config.master_volume_multiplier) / log(10.0))
			AudioServer.set_bus_volume_db(master_bus, new_volume)
			if debug_spawn_config:
				print("LevelSpawnConfig: Set master volume multiplier to: ", gameplay_config.master_volume_multiplier)
	
	# Custom environment
	if gameplay_config.override_lighting and gameplay_config.custom_environment:
		get_viewport().environment = gameplay_config.custom_environment
		if debug_spawn_config:
			print("LevelSpawnConfig: Applied custom environment")

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
