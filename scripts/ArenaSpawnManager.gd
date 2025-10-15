extends Node

# === DEBUG FLAGS (EASY TOGGLE) ===
const DEBUG_SPAWNING = false  # General spawn events
const DEBUG_DEATH_TRACKING = false  # Enemy death tracking
const DEBUG_TELEGRAPH = false  # Telegraph system
const DEBUG_TIME_SYSTEM = false  # Time system integration
const DEBUG_DIFFICULTY = false  # Difficulty scaling

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

## === EXPORTED CONFIGURATION ===
@export_group("Spawning System")
## Automatically start spawning when configured by level (usually false for singleton)
@export var auto_start: bool = false
## Time between spawn attempts (seconds) - configured by level
@export var spawn_interval: float = 2.0
## Enable difficulty scaling over time - configured by level
@export var difficulty_scaling: bool = true
## Absolute maximum enemies alive at once - configured by level
@export var max_total_enemies: int = 50
## Warning time before enemy spawns (telegraph duration) - configured by level
@export var telegraph_duration: float = 3.0

@export_group("Time System Integration")
## Minimum time scale required for spawning (below this, spawning is paused)
@export var minimum_spawn_time_scale: float = 0.1
## Time conversion factor (seconds to minutes)
@export var time_conversion_factor: float = 60.0

@export_group("Difficulty Scaling")
## Health multiplier increase per minute (e.g., 0.1 = +10% per minute)
@export var health_scaling_per_minute: float = 0.1
## Speed multiplier increase per minute (e.g., 0.05 = +5% per minute)
@export var speed_scaling_per_minute: float = 0.05
## Base health multiplier (starting value)
@export var base_health_multiplier: float = 1.0
## Base speed multiplier (starting value)
@export var base_speed_multiplier: float = 1.0

@export_group("Telegraph System")
## Height offset for telegraph effects above spawn position
@export var telegraph_height_offset: float = 2.0

@export_group("Debug Settings")
## Turn off all enemy spawning for testing
@export var disable_spawning: bool = false

# === ENEMY TYPE CONFIGURATION ===
# Each enemy type has its own maximum count that increases over time
var enemy_max_counts: Dictionary = {
	EnemyType.GRUNT: 0,      # Disabled by default - configured by level
	EnemyType.SNIPER: 0,     # Disabled by default - configured by level
	EnemyType.FLANKER: 0,    # Disabled by default - configured by level
	EnemyType.RUSHER: 0,     # Disabled by default - configured by level
	EnemyType.ARTILLERY: 0   # Disabled by default - configured by level
}

# When each enemy type should start appearing (in seconds)
var enemy_unlock_times: Dictionary = {
	EnemyType.GRUNT: 0.0,      # Available immediately
	EnemyType.SNIPER: 0.0,     # Available immediately for testing
	EnemyType.FLANKER: 00.0,   # After 60 seconds
	EnemyType.RUSHER: 00.0,    # After 90 seconds
	EnemyType.ARTILLERY: 00.0 # After 120 seconds
}

# How much the max count increases per minute
var enemy_growth_rates: Dictionary = {
	EnemyType.GRUNT: 0.0,      # +1 grunt per minute
	EnemyType.SNIPER: 0.0,     # +0.5 sniper per minute
	EnemyType.FLANKER: 0.00,    # +0.5 flanker per minute
	EnemyType.RUSHER: 0.0,     # +0.3 rusher per minute
	EnemyType.ARTILLERY: 0.0   # +0.2 artillery per minute
}

# === STATE ===
var is_spawning: bool = false
var spawn_timer: Timer
var game_time: float = 0.0  # Total time since spawning started
var enemies_alive: int = 0
var enemies_by_type: Dictionary = {}  # Track enemies by type

# Spawn markers
var spawn_markers: Array[Marker3D] = []

# Time system integration
var time_manager: Node = null

# Telegraph system
var telegraph_scene: PackedScene = preload("res://scenes/SpawnTelegraph.tscn")
var pending_spawns: Array[Dictionary] = []  # Queue of telegraphed spawns
var pending_spawns_by_type: Dictionary = {}  # Track pending spawns by enemy type

# === SCHEDULED SPAWN SYSTEM ===
# New system for precise level-based spawning
var scheduled_spawns: Array = []  # Array of SpawnEvent objects
var completed_spawns: Array[bool] = []  # Track which spawns have been executed
var default_telegraph_duration: float = 3.0
var use_scheduled_spawning: bool = false

# === SIGNALS ===
signal enemy_spawned(enemy: BaseEnemy, enemy_type: EnemyType)
signal enemy_died(enemy: BaseEnemy, enemy_type: EnemyType)
signal difficulty_increased(new_level: int)
signal enemy_type_unlocked(enemy_type: EnemyType)

func _ready():
	# Initialize enemy tracking
	for enemy_type in EnemyType.values():
		enemies_by_type[enemy_type] = 0
		pending_spawns_by_type[enemy_type] = 0
	
	# Connect to time manager
	time_manager = get_node_or_null("/root/TimeManager")
	
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
	
	# Start spawning if auto-start is enabled
	if auto_start:
		start_spawning()

func _process(delta: float):
	if is_spawning:
		# Use time-adjusted delta to respect time scale
		var time_delta = delta
		if time_manager:
			var time_scale = time_manager.get_time_scale()
			time_delta = delta * time_scale
		
		game_time += time_delta
		
		if use_scheduled_spawning:
			_process_scheduled_spawns()
		else:
			_update_difficulty()

func _setup_spawn_markers():
	"""Find spawn markers from the SpawnMarkers node."""
	# DISABLED: LevelSpawnConfig now handles spawn marker setup
	# This method was conflicting with the level-based marker configuration
	if DEBUG_SPAWNING:
		print("ArenaSpawnManager: _setup_spawn_markers called but disabled - LevelSpawnConfig handles this now")
	return
	
	# OLD CODE (disabled):
	spawn_markers.clear()
	
	# Get the SpawnMarkers node from the main scene
	var spawn_markers_node = get_tree().current_scene.get_node_or_null("SpawnMarkers")
	if spawn_markers_node:
		# Get all children of SpawnMarkers as spawn points
		for child in spawn_markers_node.get_children():
			if child is Marker3D:
				spawn_markers.append(child)



func _update_difficulty():
	"""Update enemy maximums based on game time - RESPECTS TOP-LEVEL CONFIG."""
	# DISABLED: Let the user control spawning via the top-level variables
	# No more automatic difficulty scaling that overrides user settings
	pass

func _process_scheduled_spawns():
	"""Process scheduled spawn events based on game time."""
	for i in range(scheduled_spawns.size()):
		if completed_spawns[i]:
			continue  # Already spawned
		
		var spawn_event = scheduled_spawns[i]
		if game_time >= spawn_event.spawn_time:
			# Time to spawn this enemy
			_execute_scheduled_spawn(spawn_event, i)

func _execute_scheduled_spawn(spawn_event, spawn_index: int):
	"""Execute a scheduled spawn event."""
	if DEBUG_SPAWNING:
		print("ArenaSpawnManager: Executing scheduled spawn - Type: ", EnemyType.keys()[spawn_event.enemy_type], " at time: ", "%.1f" % game_time)
	
	# Mark as completed first to prevent double-spawning
	completed_spawns[spawn_index] = true
	
	# Get spawn position from marker
	var spawn_pos = _get_spawn_position_from_marker(spawn_event.spawn_marker_index)
	
	# Determine telegraph duration
	var telegraph_duration = spawn_event.telegraph_duration
	if telegraph_duration < 0:
		telegraph_duration = default_telegraph_duration
	
	# Start spawn telegraph with custom parameters
	_start_scheduled_spawn_telegraph(spawn_event, spawn_pos, telegraph_duration)

func _get_spawn_position_from_marker(marker_index: int) -> Vector3:
	"""Get spawn position from a specific marker index."""
	if DEBUG_SPAWNING:
		print("ArenaSpawnManager: _get_spawn_position_from_marker called with index: ", marker_index)
		print("ArenaSpawnManager: Available spawn markers: ", spawn_markers.size())
		for i in range(spawn_markers.size()):
			if spawn_markers[i]:
				print("ArenaSpawnManager: Marker ", i, " position: ", spawn_markers[i].global_position)
			else:
				print("ArenaSpawnManager: Marker ", i, " is null!")
	
	if spawn_markers.size() == 0:
		if DEBUG_SPAWNING:
			print("ArenaSpawnManager: WARNING - No spawn markers available!")
		return Vector3.ZERO
	
	# Clamp marker index to available markers
	var safe_index = clamp(marker_index, 0, spawn_markers.size() - 1)
	if safe_index != marker_index and DEBUG_SPAWNING:
		print("ArenaSpawnManager: WARNING - Marker index ", marker_index, " out of range, using ", safe_index)
	
	var marker_pos = spawn_markers[safe_index].global_position
	if DEBUG_SPAWNING:
		print("ArenaSpawnManager: Using marker ", safe_index, " at position: ", marker_pos)
	
	return marker_pos

func _start_scheduled_spawn_telegraph(spawn_event, spawn_pos: Vector3, telegraph_duration: float):
	"""Start a telegraph for a scheduled spawn with custom parameters."""
	# TRACK PENDING SPAWN for scheduled spawns too
	pending_spawns_by_type[spawn_event.enemy_type] += 1
	if DEBUG_TELEGRAPH:
		print("ArenaSpawnManager: Started scheduled telegraph for ", EnemyType.keys()[spawn_event.enemy_type], " - pending count now: ", pending_spawns_by_type[spawn_event.enemy_type])
	
	# Create telegraph effect
	var telegraph = telegraph_scene.instantiate()
	get_tree().current_scene.add_child(telegraph)
	telegraph.global_position = spawn_pos + Vector3(0, telegraph_height_offset, 0)
	
	# Configure telegraph colors based on enemy type
	var telegraph_color = Color.RED
	match spawn_event.enemy_type:
		EnemyType.GRUNT:
			telegraph_color = Color.RED
		EnemyType.SNIPER:
			telegraph_color = Color.BLUE
		EnemyType.FLANKER:
			telegraph_color = Color.PURPLE
		EnemyType.RUSHER:
			telegraph_color = Color.YELLOW
		EnemyType.ARTILLERY:
			telegraph_color = Color.DARK_GREEN
	
	telegraph.set_telegraph_color(telegraph_color)
	telegraph.set_telegraph_duration(telegraph_duration)
	
	# Connect completion signal with spawn event data
	telegraph.telegraph_completed.connect(_on_scheduled_telegraph_completed.bind(spawn_event, spawn_pos))
	
	# Start the effect
	telegraph.start_telegraph()
	
	# Play spawn telegraph SFX (time scale will be handled automatically by AudioManager)
	AudioManager.play_sfx("enemy_spawn_telegraph")
	
	if DEBUG_TELEGRAPH:
		print("ArenaSpawnManager: Telegraph duration: ", telegraph_duration, " seconds")
		print("ArenaSpawnManager: Started scheduled telegraph for ", EnemyType.keys()[spawn_event.enemy_type], " at marker ", spawn_event.spawn_marker_index)

func _on_scheduled_telegraph_completed(spawn_event, spawn_pos: Vector3):
	"""Called when a scheduled spawn telegraph finishes."""
	# REMOVE FROM PENDING SPAWNS for scheduled spawns too
	pending_spawns_by_type[spawn_event.enemy_type] -= 1
	if DEBUG_TELEGRAPH:
		print("ArenaSpawnManager: Scheduled telegraph completed for ", EnemyType.keys()[spawn_event.enemy_type], " - pending count now: ", pending_spawns_by_type[spawn_event.enemy_type])
	
	var enemy = _spawn_enemy_at_position_with_modifiers(spawn_event.enemy_type, spawn_pos, spawn_event.health_multiplier, spawn_event.speed_multiplier)
	if enemy:
		enemies_alive += 1
		enemies_by_type[spawn_event.enemy_type] += 1
		
		if DEBUG_SPAWNING:
			print("ArenaSpawnManager: === SCHEDULED ENEMY SPAWNED ===")
			print("ArenaSpawnManager: Type: ", EnemyType.keys()[spawn_event.enemy_type])
			print("ArenaSpawnManager: Health mult: x", spawn_event.health_multiplier, " Speed mult: x", spawn_event.speed_multiplier)
			print("ArenaSpawnManager: New counts - Total: ", enemies_alive, ", Type: ", enemies_by_type[spawn_event.enemy_type])
		
		# Connect to enemy death
		enemy.enemy_died.connect(_on_enemy_died)
		
		enemy_spawned.emit(enemy, spawn_event.enemy_type)

func _on_spawn_timer_timeout():
	"""Called when it's time to attempt spawning."""
	if DEBUG_TIME_SYSTEM:
		print("ArenaSpawnManager: Spawn timer timeout triggered")
	
	if not is_spawning:
		if DEBUG_SPAWNING:
			print("ArenaSpawnManager: Not spawning, ignoring timer")
		return
	
	# Skip timer-based spawning if we're using scheduled spawning mode
	if use_scheduled_spawning:
		if DEBUG_SPAWNING:
			print("ArenaSpawnManager: Using scheduled spawning, ignoring timer")
		spawn_timer.start()  # Keep timer running but don't spawn
		return
	
	# Only spawn if time isn't heavily slowed/frozen
	if time_manager and time_manager.get_time_scale() < minimum_spawn_time_scale:
		if DEBUG_TIME_SYSTEM:
			print("ArenaSpawnManager: Time scale too low (", time_manager.get_time_scale(), "), skipping spawn")
		# Skip spawning during heavy time dilation
		spawn_timer.start()
		return
	
	if DEBUG_SPAWNING:
		print("ArenaSpawnManager: Attempting to spawn enemy")
	# Try to spawn an enemy
	_attempt_spawn()
	
	# Restart timer
	spawn_timer.start()

func _attempt_spawn():
	"""Attempt to spawn an enemy if we're under the maximum."""
	if DEBUG_SPAWNING:
		print("ArenaSpawnManager: === SPAWN ATTEMPT DEBUG ===")
		print("ArenaSpawnManager: Current enemy counts: ", enemies_by_type)
		print("ArenaSpawnManager: Pending spawns: ", pending_spawns_by_type)
		print("ArenaSpawnManager: Max enemy counts: ", enemy_max_counts)
		print("ArenaSpawnManager: Total enemies alive: ", enemies_alive, "/", max_total_enemies)
	
	# Check debug toggle first
	if disable_spawning:
		if DEBUG_SPAWNING:
			print("ArenaSpawnManager: DEBUG: Spawning disabled")
		return
	
	# Don't spawn if we're at the absolute maximum
	if enemies_alive >= max_total_enemies:
		if DEBUG_SPAWNING:
			print("ArenaSpawnManager: DEBUG: At total enemy maximum")
		return
	
	# Find which enemy type to spawn
	var spawn_type = _select_spawn_type()
	if DEBUG_SPAWNING:
		print("ArenaSpawnManager: Selected spawn type: ", spawn_type, " (", EnemyType.keys()[spawn_type] if spawn_type >= 0 else "NONE", ")")
	
	if spawn_type == -1:  # Use -1 instead of null for no valid type
		if DEBUG_SPAWNING:
			print("ArenaSpawnManager: DEBUG: No valid spawn type")
		return  # No valid spawn type
	
	# Check if we're under the maximum for this type (including pending spawns)
	var total_count = enemies_by_type[spawn_type] + pending_spawns_by_type[spawn_type]
	if total_count >= enemy_max_counts[spawn_type]:
		if DEBUG_SPAWNING:
			print("ArenaSpawnManager: DEBUG: At maximum for type ", EnemyType.keys()[spawn_type], " (spawned: ", enemies_by_type[spawn_type], " + pending: ", pending_spawns_by_type[spawn_type], " = ", total_count, "/", enemy_max_counts[spawn_type], ")")
		return  # At maximum for this type
	
	if DEBUG_SPAWNING:
		print("ArenaSpawnManager: DEBUG: SPAWNING ", EnemyType.keys()[spawn_type])
	# Start spawn telegraph instead of immediate spawn
	_start_spawn_telegraph(spawn_type)

func _select_spawn_type() -> int:
	"""Select which enemy type to spawn based on current counts and availability."""
	# TEMPORARY: Only spawn snipers for testing gunfire telegraphs
	# Comment out the line below to return to normal spawning
	# return EnemyType.SNIPER
	
	# Original code:
	var available_types: Array[int] = []
	
	for enemy_type in EnemyType.values():
		# Check if this type is unlocked
		if game_time < enemy_unlock_times[enemy_type]:
			continue
		
		# Check if we're under the maximum for this type (including pending spawns)
		var total_count = enemies_by_type[enemy_type] + pending_spawns_by_type[enemy_type]
		if total_count < enemy_max_counts[enemy_type]:
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
		if DEBUG_SPAWNING:
			print("ArenaSpawnManager: ERROR: Failed to instantiate enemy of type: ", EnemyType.keys()[type])
		return null
	
	# Apply difficulty scaling
	if difficulty_scaling:
		var minutes_elapsed = game_time / time_conversion_factor
		var health_mult = base_health_multiplier + (minutes_elapsed * health_scaling_per_minute)
		var speed_mult = base_speed_multiplier + (minutes_elapsed * speed_scaling_per_minute)
		
		if DEBUG_DIFFICULTY:
			print("ArenaSpawnManager: Difficulty scaling - Minutes: ", "%.1f" % minutes_elapsed, " Health: x", "%.2f" % health_mult, " Speed: x", "%.2f" % speed_mult)
		
		enemy.max_health = int(enemy.max_health * health_mult)
		enemy.current_health = enemy.max_health
		enemy.movement_speed *= speed_mult
	
	# Add to scene first
	get_tree().current_scene.add_child(enemy)
	
	# Set spawn position IMMEDIATELY after being added to tree
	var spawn_pos = _get_spawn_position()
	enemy.global_position = spawn_pos
	
	return enemy

func _spawn_enemy_at_position(type: int, spawn_pos: Vector3) -> BaseEnemy:
	"""Spawn an enemy of the specified type at a specific position."""
	return _spawn_enemy_at_position_with_modifiers(type, spawn_pos, 1.0, 1.0)

func _spawn_enemy_at_position_with_modifiers(type: int, spawn_pos: Vector3, health_mult: float, speed_mult: float) -> BaseEnemy:
	"""Spawn an enemy of the specified type at a specific position with custom modifiers."""
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
		return null
	
	# Apply difficulty scaling (legacy continuous mode)
	if difficulty_scaling and not use_scheduled_spawning:
		var minutes_elapsed = game_time / time_conversion_factor
		var difficulty_health_mult = base_health_multiplier + (minutes_elapsed * health_scaling_per_minute)
		var difficulty_speed_mult = base_speed_multiplier + (minutes_elapsed * speed_scaling_per_minute)
		
		if DEBUG_DIFFICULTY:
			print("ArenaSpawnManager: Difficulty scaling (positioned spawn) - Minutes: ", "%.1f" % minutes_elapsed, " Health: x", "%.2f" % difficulty_health_mult, " Speed: x", "%.2f" % difficulty_speed_mult)
		
		health_mult *= difficulty_health_mult
		speed_mult *= difficulty_speed_mult
	
	# Apply modifiers
	if health_mult != 1.0:
		enemy.max_health = int(enemy.max_health * health_mult)
		enemy.current_health = enemy.max_health
	
	if speed_mult != 1.0:
		enemy.movement_speed *= speed_mult
	
	# Add to scene and position
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = spawn_pos
	
	return enemy

func _start_spawn_telegraph(enemy_type: int):
	"""Start a spawn telegraph effect before actually spawning the enemy."""
	var spawn_pos = _get_spawn_position()
	
	# TRACK PENDING SPAWN
	pending_spawns_by_type[enemy_type] += 1
	if DEBUG_TELEGRAPH:
		print("ArenaSpawnManager: Started telegraph for ", EnemyType.keys()[enemy_type], " - pending count now: ", pending_spawns_by_type[enemy_type])
	
	# Create telegraph effect from your scene
	var telegraph = telegraph_scene.instantiate()
	
	get_tree().current_scene.add_child(telegraph)
	telegraph.global_position = spawn_pos + Vector3(0, telegraph_height_offset, 0)
	
	# Configure telegraph colors based on enemy type
	var telegraph_color = Color.RED
	match enemy_type:
		EnemyType.GRUNT:
			telegraph_color = Color.RED
		EnemyType.SNIPER:
			telegraph_color = Color.BLUE
		EnemyType.FLANKER:
			telegraph_color = Color.PURPLE
		EnemyType.RUSHER:
			telegraph_color = Color.YELLOW
		EnemyType.ARTILLERY:
			telegraph_color = Color.DARK_GREEN
	
	telegraph.set_telegraph_color(telegraph_color)
	telegraph.set_telegraph_duration(telegraph_duration)
	
	# Connect completion signal
	telegraph.telegraph_completed.connect(_on_telegraph_completed.bind(enemy_type, spawn_pos))
	
	# Start the effect
	telegraph.start_telegraph()
	
	# Play spawn telegraph SFX (time scale will be handled automatically by AudioManager)
	AudioManager.play_sfx("enemy_spawn_telegraph")
	
	if DEBUG_TELEGRAPH:
		print("ArenaSpawnManager: Telegraph duration: ", telegraph_duration, " seconds")

func _on_telegraph_completed(enemy_type: int, spawn_pos: Vector3):
	"""Called when a telegraph finishes - actually spawn the enemy now."""
	# REMOVE FROM PENDING SPAWNS
	pending_spawns_by_type[enemy_type] -= 1
	if DEBUG_TELEGRAPH:
		print("ArenaSpawnManager: Telegraph completed for ", EnemyType.keys()[enemy_type], " - pending count now: ", pending_spawns_by_type[enemy_type])
	
	var enemy = _spawn_enemy_at_position(enemy_type, spawn_pos)
	if enemy:
		enemies_alive += 1
		enemies_by_type[enemy_type] += 1
		
		if DEBUG_SPAWNING:
			print("ArenaSpawnManager: === ENEMY SPAWNED ===")
			print("ArenaSpawnManager: Type: ", EnemyType.keys()[enemy_type])
			print("ArenaSpawnManager: New counts - Total: ", enemies_alive, ", Type: ", enemies_by_type[enemy_type])
			print("ArenaSpawnManager: Max allowed: ", enemy_max_counts[enemy_type])
		
		# Connect to enemy death
		enemy.enemy_died.connect(_on_enemy_died)
		
		enemy_spawned.emit(enemy, enemy_type)

func _get_spawn_position() -> Vector3:
	"""Get a random spawn position from available markers."""
	if spawn_markers.size() == 0:
		return Vector3.ZERO
	
	# Get random marker
	var marker = spawn_markers[randi() % spawn_markers.size()]
	return marker.global_position

func _on_enemy_died(enemy: BaseEnemy):
	"""Called when an enemy dies."""
	enemies_alive -= 1
	
	if DEBUG_DEATH_TRACKING:
		print("ArenaSpawnManager: === ENEMY DIED ===")
		print("ArenaSpawnManager: Enemy scene: ", enemy.scene_file_path.get_file().get_basename())
	
	# Find which type this enemy was and decrement its count
	for enemy_type in EnemyType.values():
		if enemy.scene_file_path.get_file().get_basename().to_upper() == EnemyType.keys()[enemy_type]:
			enemies_by_type[enemy_type] -= 1
			if DEBUG_DEATH_TRACKING:
				print("ArenaSpawnManager: Decremented ", EnemyType.keys()[enemy_type], " count to: ", enemies_by_type[enemy_type])
				print("ArenaSpawnManager: Total enemies now: ", enemies_alive)
			enemy_died.emit(enemy, enemy_type)
			break
	
	# Check for level win condition
	_check_level_win_condition()

func _check_level_win_condition():
	"""Check if level win condition is met (no enemies alive, no pending spawns, and no enemies left to spawn)."""
	# Don't check win condition if spawning isn't active
	if not is_spawning:
		return
	
	# Check if there are any enemies still alive
	if enemies_alive > 0:
		if DEBUG_SPAWNING:
			print("ArenaSpawnManager: Win check - still ", enemies_alive, " enemies alive")
		return
	
	# Check if there are any enemies currently spawning (telegraphing)
	var total_pending_spawns = 0
	for enemy_type in EnemyType.values():
		total_pending_spawns += pending_spawns_by_type[enemy_type]
	
	if total_pending_spawns > 0:
		if DEBUG_SPAWNING:
			print("ArenaSpawnManager: Win check - still ", total_pending_spawns, " enemies spawning (telegraphing)")
		return
	
	# Check if there are any enemies left to spawn
	var enemies_left_to_spawn = false
	
	if use_scheduled_spawning:
		# Check scheduled spawn mode - are there any uncompleted spawns?
		for i in range(completed_spawns.size()):
			if not completed_spawns[i]:
				enemies_left_to_spawn = true
				break
		
		if DEBUG_SPAWNING:
			var stats = get_scheduled_spawn_stats()
			print("ArenaSpawnManager: Win check (scheduled mode) - Completed: ", stats.completed, "/", stats.total_scheduled)
	else:
		# Check continuous spawn mode - are we still able to spawn more enemies?
		# In continuous mode, enemies can always spawn unless disabled
		# So we only win if spawning is explicitly disabled (e.g., max counts all at 0)
		var can_spawn_more = false
		for enemy_type in EnemyType.values():
			if enemy_max_counts[enemy_type] > 0:
				can_spawn_more = true
				break
		
		enemies_left_to_spawn = can_spawn_more
		
		if DEBUG_SPAWNING:
			print("ArenaSpawnManager: Win check (continuous mode) - Can spawn more: ", can_spawn_more)
	
	# If no enemies alive, no pending spawns, and no enemies left to spawn, level is won!
	if not enemies_left_to_spawn:
		if DEBUG_SPAWNING:
			print("ArenaSpawnManager: *** LEVEL WIN CONDITION MET ***")
			print("ArenaSpawnManager: No enemies alive, no pending spawns, and no enemies left to spawn")
		
		# Trigger level win
		var game_manager = get_node_or_null("/root/GameManager")
		if game_manager and game_manager.has_method("trigger_level_won"):
			game_manager.trigger_level_won()
		else:
			print("ArenaSpawnManager: WARNING - GameManager not found or doesn't have trigger_level_won method")

func _on_game_restart_requested():
	"""Called when game is restarting - reset spawning system."""
	if DEBUG_SPAWNING:
		print("ArenaSpawnManager: Game restarting, resetting spawning system")
	stop_spawning()
	game_time = 0.0
	enemies_alive = 0
	
	# Reset enemy counts
	for enemy_type in EnemyType.values():
		enemies_by_type[enemy_type] = 0
		pending_spawns_by_type[enemy_type] = 0
	
	# Reset scheduled spawns
	_reset_scheduled_spawns()
	
	# DON'T RESET ENEMY MAXIMUMS - RESPECT USER'S TOP-LEVEL CONFIGURATION
	# The user controls spawning via the variables at the top of this file
	if DEBUG_SPAWNING:
		print("ArenaSpawnManager: Keeping user-defined enemy max counts - Grunt max: ", enemy_max_counts[EnemyType.GRUNT])
	
	# IMPORTANT: Restart spawning after reset
	if auto_start:
		if DEBUG_SPAWNING:
			print("ArenaSpawnManager: Restarting spawning after reset")
		start_spawning()
	else:
		if DEBUG_SPAWNING:
			print("ArenaSpawnManager: Auto-start disabled, not restarting spawning")
	
	# Wait for scene to reload, then restart spawning
	await get_tree().process_frame
	await get_tree().process_frame  # Wait a bit more to ensure scene is fully loaded
	
	# Re-setup spawn markers for the new scene
	_setup_spawn_markers()
	
	# Restart spawning if auto-start is enabled
	if auto_start:
		if DEBUG_SPAWNING:
			print("ArenaSpawnManager: Restarting spawning after game restart")
		start_spawning()

func _reset_scheduled_spawns():
	"""Reset all scheduled spawn tracking."""
	for i in range(completed_spawns.size()):
		completed_spawns[i] = false
	
	if DEBUG_SPAWNING and use_scheduled_spawning:
		print("ArenaSpawnManager: Reset ", completed_spawns.size(), " scheduled spawns")

# === PUBLIC API ===

func start_spawning():
	"""Start the continuous spawning system."""
	if is_spawning:
		if DEBUG_SPAWNING:
			print("ArenaSpawnManager: Already spawning, ignoring start request")
		return
	
	is_spawning = true
	game_time = 0.0
	spawn_timer.start()
	if DEBUG_SPAWNING:
		print("ArenaSpawnManager: Started continuous spawning - timer wait time: ", spawn_timer.wait_time)
		print("ArenaSpawnManager: Spawn markers found: ", spawn_markers.size())

func stop_spawning():
	"""Stop the continuous spawning system."""
	is_spawning = false
	if spawn_timer:
		spawn_timer.stop()
	if DEBUG_SPAWNING:
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

func set_spawn_markers(markers: Array[Marker3D]):
	"""Set spawn markers from level configuration."""
	spawn_markers.clear()
	spawn_markers = markers
	if DEBUG_SPAWNING:
		print("ArenaSpawnManager: Configured with ", markers.size(), " spawn markers from level")

func set_difficulty_scaling(health_per_minute: float, speed_per_minute: float):
	"""Configure difficulty scaling rates."""
	health_scaling_per_minute = health_per_minute
	speed_scaling_per_minute = speed_per_minute
	if DEBUG_DIFFICULTY:
		print("ArenaSpawnManager: Difficulty scaling configured - Health: ", health_per_minute, "/min, Speed: ", speed_per_minute, "/min")

func configure_for_level(config: Dictionary):
	"""Configure spawn manager with level-specific settings."""
	if config.has("spawn_interval"):
		spawn_interval = config.spawn_interval
		if spawn_timer:
			spawn_timer.wait_time = spawn_interval
	
	if config.has("max_total_enemies"):
		max_total_enemies = config.max_total_enemies
	
	if config.has("telegraph_duration"):
		telegraph_duration = config.telegraph_duration
	
	if config.has("difficulty_scaling"):
		difficulty_scaling = config.difficulty_scaling
	
	if config.has("enemy_max_counts"):
		enemy_max_counts = config.enemy_max_counts
	
	if config.has("enemy_unlock_times"):
		enemy_unlock_times = config.enemy_unlock_times
	
	if DEBUG_SPAWNING:
		print("ArenaSpawnManager: Configured for level with settings: ", config.keys())

func reset_for_level():
	"""Reset spawn manager state for a new level."""
	stop_spawning()
	game_time = 0.0
	enemies_alive = 0
	
	# Reset enemy counts
	for enemy_type in EnemyType.values():
		enemies_by_type[enemy_type] = 0
		pending_spawns_by_type[enemy_type] = 0
	
	# Reset scheduled spawns
	_reset_scheduled_spawns()
	
	# DON'T clear spawn markers - they will be set by LevelSpawnConfig
	# spawn_markers.clear()  # REMOVED - this was causing the markers to be lost
	
	if DEBUG_SPAWNING:
		print("ArenaSpawnManager: Reset for new level (keeping existing spawn markers: ", spawn_markers.size(), ")")

func set_scheduled_spawns(spawn_events: Array, default_telegraph: float = 3.0):
	"""Configure scheduled spawn events for level-based spawning."""
	scheduled_spawns = spawn_events
	default_telegraph_duration = default_telegraph
	use_scheduled_spawning = true
	
	# Initialize completion tracking
	completed_spawns.clear()
	for i in range(spawn_events.size()):
		completed_spawns.append(false)
	
	if DEBUG_SPAWNING:
		print("ArenaSpawnManager: Configured ", spawn_events.size(), " scheduled spawn events")
		print("ArenaSpawnManager: Switched to scheduled spawning mode")

func add_scheduled_spawn(spawn_event):
	"""Add a single scheduled spawn event."""
	scheduled_spawns.append(spawn_event)
	completed_spawns.append(false)
	
	if DEBUG_SPAWNING:
		print("ArenaSpawnManager: Added scheduled spawn event - Type: ", EnemyType.keys()[spawn_event.enemy_type], " Time: ", spawn_event.spawn_time)

func clear_scheduled_spawns():
	"""Clear all scheduled spawn events."""
	scheduled_spawns.clear()
	completed_spawns.clear()
	use_scheduled_spawning = false
	
	if DEBUG_SPAWNING:
		print("ArenaSpawnManager: Cleared all scheduled spawns, switched to continuous mode")

func get_scheduled_spawn_stats() -> Dictionary:
	"""Get statistics about scheduled spawns."""
	var total_spawns = scheduled_spawns.size()
	var completed_count = 0
	for completed in completed_spawns:
		if completed:
			completed_count += 1
	
	return {
		"total_scheduled": total_spawns,
		"completed": completed_count,
		"remaining": total_spawns - completed_count,
		"using_scheduled_mode": use_scheduled_spawning
	}

func force_spawn_enemy(enemy_type: int):
	"""Force spawn a specific enemy type (ignores limits)."""
	var enemy = _spawn_enemy(enemy_type)
	if enemy:
		enemies_alive += 1
		enemies_by_type[enemy_type] += 1
		enemy.enemy_died.connect(_on_enemy_died)
		enemy_spawned.emit(enemy, enemy_type)
		if DEBUG_SPAWNING:
			print("ArenaSpawnManager: Force spawned ", EnemyType.keys()[enemy_type])

# === DEBUG ===

func print_status():
	"""Debug function to print current spawning status."""
	print("ArenaSpawnManager: \n=== ARENA SPAWN MANAGER STATUS ===")
	print("ArenaSpawnManager: Game time: ", "%.1f" % game_time, " seconds")
	print("ArenaSpawnManager: Enemies alive: ", enemies_alive, "/", max_total_enemies)
	print("ArenaSpawnManager: Spawning: ", is_spawning)
	print("ArenaSpawnManager: \nEnemy counts:")
	for enemy_type in EnemyType.values():
		var type_name = EnemyType.keys()[enemy_type]
		var current = enemies_by_type[enemy_type]
		var maximum = enemy_max_counts[enemy_type]
		var unlocked = game_time >= enemy_unlock_times[enemy_type]
		print("ArenaSpawnManager:   ", type_name, ": ", current, "/", maximum, " (unlocked: ", unlocked, ")")
	print("ArenaSpawnManager: ===============================\n")
