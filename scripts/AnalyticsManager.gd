extends Node

# === ANALYTICS MANAGER ===
# Autoload singleton that tracks comprehensive player metrics
# Handles per-level and global statistics with persistent storage

## === EXPORTED CONFIGURATION ===
@export_group("Save Settings")
## Analytics save file path
@export var analytics_save_file: String = "user://analytics.save"

@export_group("Save Optimization")
## Enable batched saving (saves every N sessions instead of every session)
@export var enable_batch_saving: bool = true
## Number of sessions to accumulate before saving
@export var save_batch_size: int = 3
## Maximum time between saves (seconds) - force save even if batch not full
@export var max_save_interval: float = 300.0

@export_group("Debug Settings")
## Enable debug output for analytics
@export var debug_analytics: bool = false
## Enable debug output for save/load operations
@export var debug_save_load: bool = false

## === DATA STRUCTURES ===
class LevelAnalytics:
	var level_id: String
	var sessions_played: int = 0
	var total_playtime: float = 0.0
	var best_survival_time: float = 0.0
	var average_survival_time: float = 0.0
	var success_rate: float = 0.0  # wins/total_attempts
	
	# Combat metrics
	var bullets_fired: int = 0
	var bullets_hit: int = 0
	var accuracy: float = 0.0
	var total_damage_dealt: float = 0.0
	var enemies_killed: int = 0
	var average_bullet_bounces: float = 0.0
	var average_bullet_distance: float = 0.0
	var multi_kills: int = 0  # multiple enemies with one bullet
	var multi_hits: int = 0   # multiple hits with one bullet
	
	# Movement metrics
	var distance_traveled: float = 0.0
	var dashes_used: int = 0
	var jumps_performed: int = 0
	var slides_performed: int = 0
	var deflections_performed: int = 0
	
	# Time-based metrics
	var time_in_combat: float = 0.0
	var time_moving: float = 0.0
	var time_stationary: float = 0.0
	
	func _init(level_id: String):
		self.level_id = level_id
	
	func get_accuracy() -> float:
		if bullets_fired > 0:
			return float(bullets_hit) / float(bullets_fired)
		return 0.0
	
	func update_averages():
		"""Update calculated averages after new data is added."""
		accuracy = get_accuracy()
		if sessions_played > 0:
			average_survival_time = total_playtime / float(sessions_played)

class SessionData:
	var level_id: String
	var session_start_time: float
	var session_end_time: float
	var survival_time: float = 0.0
	var was_successful: bool = false
	
	# Combat session data
	var bullets_fired: int = 0
	var bullets_hit: int = 0
	var damage_dealt: float = 0.0
	var enemies_killed: int = 0
	var bullet_bounces: int = 0
	var bullet_distances: Array[float] = []
	var multi_kill_events: int = 0
	var multi_hit_events: int = 0
	
	# Movement session data
	var distance_traveled: float = 0.0
	var dashes_used: int = 0
	var jumps_performed: int = 0
	var slides_performed: int = 0
	var deflections_performed: int = 0
	
	# Time tracking
	var time_in_combat: float = 0.0
	var time_moving: float = 0.0
	var time_stationary: float = 0.0
	
	func _init(level_id: String):
		self.level_id = level_id
		self.session_start_time = Time.get_ticks_msec() / 1000.0

## === RUNTIME STATE ===
# Per-level analytics data
var level_analytics: Dictionary = {}  # level_id -> LevelAnalytics
# Current session data
var current_session: SessionData = null
# Global aggregated data
var global_analytics: LevelAnalytics = null
# Save batching variables
var sessions_since_last_save: int = 0
var last_save_time: float = 0.0
var pending_save: bool = false

## === SIGNALS ===
signal session_started(level_id: String)
signal session_ended(level_id: String, was_successful: bool)
signal analytics_updated(level_id: String)

func _ready():
	# Load existing analytics data
	_load_analytics()
	
	# Initialize global analytics
	global_analytics = LevelAnalytics.new("global")
	
	# Initialize save batching
	last_save_time = Time.get_ticks_msec() / 1000.0
	
	# Connect to game events
	_setup_connections()
	
	# Ensure analytics are saved when game exits
	# We'll use _notification instead of signals for better compatibility
	
	if debug_analytics:
		print("AnalyticsManager: Initialized with ", level_analytics.size(), " levels tracked")

func _setup_connections():
	"""Connect to existing game systems for event tracking."""
	# Connect to GameManager for session events
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.player_died.connect(_on_player_died)
		game_manager.game_restart_requested.connect(_on_game_restart)
	
	# Connect to LevelManager for level changes
	var level_manager = get_node_or_null("/root/LevelManager")
	if level_manager:
		level_manager.level_selected.connect(_on_level_selected)

## === SESSION MANAGEMENT ===

func start_session(level_id: String):
	"""Start tracking a new session for the specified level."""
	if current_session:
		end_session(false)  # End previous session if it exists
	
	current_session = SessionData.new(level_id)
	session_started.emit(level_id)
	
	if debug_analytics:
		print("AnalyticsManager: Started session for level: ", level_id)

func end_session(was_successful: bool):
	"""End the current session and update analytics."""
	if not current_session:
		return
	
	current_session.session_end_time = Time.get_ticks_msec() / 1000.0
	current_session.survival_time = current_session.session_end_time - current_session.session_start_time
	current_session.was_successful = was_successful
	
	# Update level analytics
	_update_level_analytics(current_session)
	
	# Update global analytics
	_update_global_analytics(current_session)
	
	# Handle batched saving
	_handle_batched_save()
	
	session_ended.emit(current_session.level_id, was_successful)
	analytics_updated.emit(current_session.level_id)
	
	if debug_analytics:
		print("AnalyticsManager: Ended session for level: ", current_session.level_id, 
			  " (Success: ", was_successful, ", Time: ", "%.1f" % current_session.survival_time, "s)")
	
	current_session = null

## === EVENT TRACKING ===

func track_bullet_fired():
	"""Track when a bullet is fired."""
	if current_session:
		current_session.bullets_fired += 1
		if debug_analytics:
			print("AnalyticsManager: Bullet fired (Total: ", current_session.bullets_fired, ")")

func track_bullet_hit(damage: float = 0.0):
	"""Track when a bullet hits something."""
	if current_session:
		current_session.bullets_hit += 1
		current_session.damage_dealt += damage
		if debug_analytics:
			print("AnalyticsManager: Bullet hit (Total: ", current_session.bullets_hit, ")")

func track_enemy_killed():
	"""Track when an enemy is killed."""
	if current_session:
		current_session.enemies_killed += 1
		if debug_analytics:
			print("AnalyticsManager: Enemy killed (Total: ", current_session.enemies_killed, ")")

func track_bullet_bounce():
	"""Track when a bullet bounces."""
	if current_session:
		current_session.bullet_bounces += 1

func track_bullet_distance(distance: float):
	"""Track bullet travel distance."""
	if current_session:
		current_session.bullet_distances.append(distance)

func track_multi_kill():
	"""Track when multiple enemies are killed with one bullet."""
	if current_session:
		current_session.multi_kill_events += 1
		if debug_analytics:
			print("AnalyticsManager: Multi-kill event!")

func track_multi_hit():
	"""Track when multiple enemies are hit with one bullet."""
	if current_session:
		current_session.multi_hit_events += 1

func track_movement(distance: float):
	"""Track player movement distance."""
	if current_session:
		current_session.distance_traveled += distance

func track_dash():
	"""Track dash usage."""
	if current_session:
		current_session.dashes_used += 1

func track_jump():
	"""Track jump usage."""
	if current_session:
		current_session.jumps_performed += 1

func track_slide():
	"""Track slide usage."""
	if current_session:
		current_session.slides_performed += 1

func track_deflection():
	"""Track bullet deflection usage."""
	if current_session:
		current_session.deflections_performed += 1

func track_combat_time(delta_time: float):
	"""Track time spent in combat."""
	if current_session:
		current_session.time_in_combat += delta_time

func track_movement_time(delta_time: float):
	"""Track time spent moving."""
	if current_session:
		current_session.time_moving += delta_time

func track_stationary_time(delta_time: float):
	"""Track time spent stationary."""
	if current_session:
		current_session.time_stationary += delta_time

## === DATA AGGREGATION ===

func _update_level_analytics(session: SessionData):
	"""Update level analytics with session data."""
	var level_id = session.level_id
	
	# Get or create level analytics
	if not level_analytics.has(level_id):
		level_analytics[level_id] = LevelAnalytics.new(level_id)
	
	var analytics = level_analytics[level_id]
	
	# Update session count and playtime
	analytics.sessions_played += 1
	analytics.total_playtime += session.survival_time
	
	# Update best survival time
	if session.survival_time > analytics.best_survival_time:
		analytics.best_survival_time = session.survival_time
	
	# Update success rate
	if session.was_successful:
		analytics.success_rate = (analytics.success_rate * (analytics.sessions_played - 1) + 1.0) / float(analytics.sessions_played)
	else:
		analytics.success_rate = (analytics.success_rate * (analytics.sessions_played - 1) + 0.0) / float(analytics.sessions_played)
	
	# Update combat metrics
	analytics.bullets_fired += session.bullets_fired
	analytics.bullets_hit += session.bullets_hit
	analytics.total_damage_dealt += session.damage_dealt
	analytics.enemies_killed += session.enemies_killed
	# Note: bullet_bounces is tracked in session but stored as average_bullet_bounces in analytics
	analytics.multi_kills += session.multi_kill_events
	analytics.multi_hits += session.multi_hit_events
	
	# Update movement metrics
	analytics.distance_traveled += session.distance_traveled
	analytics.dashes_used += session.dashes_used
	analytics.jumps_performed += session.jumps_performed
	analytics.slides_performed += session.slides_performed
	analytics.deflections_performed += session.deflections_performed
	
	# Update time metrics
	analytics.time_in_combat += session.time_in_combat
	analytics.time_moving += session.time_moving
	analytics.time_stationary += session.time_stationary
	
	# Update bullet distance average
	if session.bullet_distances.size() > 0:
		var total_distance = 0.0
		for distance in session.bullet_distances:
			total_distance += distance
		analytics.average_bullet_distance = (analytics.average_bullet_distance * (analytics.sessions_played - 1) + total_distance / session.bullet_distances.size()) / float(analytics.sessions_played)
	
	# Update averages
	analytics.update_averages()

func _update_global_analytics(session: SessionData):
	"""Update global analytics with session data."""
	# Update session count and playtime
	global_analytics.sessions_played += 1
	global_analytics.total_playtime += session.survival_time
	
	# Update best survival time
	if session.survival_time > global_analytics.best_survival_time:
		global_analytics.best_survival_time = session.survival_time
	
	# Update success rate
	if session.was_successful:
		global_analytics.success_rate = (global_analytics.success_rate * (global_analytics.sessions_played - 1) + 1.0) / float(global_analytics.sessions_played)
	else:
		global_analytics.success_rate = (global_analytics.success_rate * (global_analytics.sessions_played - 1) + 0.0) / float(global_analytics.sessions_played)
	
	# Update all other metrics (same as level analytics)
	global_analytics.bullets_fired += session.bullets_fired
	global_analytics.bullets_hit += session.bullets_hit
	global_analytics.total_damage_dealt += session.damage_dealt
	global_analytics.enemies_killed += session.enemies_killed
	# Note: bullet_bounces is tracked in session but stored as average_bullet_bounces in analytics
	global_analytics.multi_kills += session.multi_kill_events
	global_analytics.multi_hits += session.multi_hit_events
	global_analytics.distance_traveled += session.distance_traveled
	global_analytics.dashes_used += session.dashes_used
	global_analytics.jumps_performed += session.jumps_performed
	global_analytics.slides_performed += session.slides_performed
	global_analytics.deflections_performed += session.deflections_performed
	global_analytics.time_in_combat += session.time_in_combat
	global_analytics.time_moving += session.time_moving
	global_analytics.time_stationary += session.time_stationary
	
	# Update averages
	global_analytics.update_averages()

## === DATA RETRIEVAL ===

func get_level_analytics(level_id: String) -> LevelAnalytics:
	"""Get analytics for a specific level."""
	if level_analytics.has(level_id):
		return level_analytics[level_id]
	return LevelAnalytics.new(level_id)

func get_global_analytics() -> LevelAnalytics:
	"""Get global aggregated analytics."""
	return global_analytics

func get_all_levels() -> Array[String]:
	"""Get list of all tracked level IDs."""
	return level_analytics.keys()

## === SAVE/LOAD SYSTEM ===

func _handle_batched_save():
	"""Handle batched saving logic."""
	if not enable_batch_saving:
		# If batching disabled, save immediately
		_save_analytics()
		return
	
	sessions_since_last_save += 1
	pending_save = true
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Check if we should save now
	var should_save = (sessions_since_last_save >= save_batch_size) or \
					  (current_time - last_save_time >= max_save_interval)
	
	if should_save:
		_save_analytics()
		sessions_since_last_save = 0
		last_save_time = current_time
		pending_save = false
		
		if debug_save_load:
			print("AnalyticsManager: Batch save triggered (Sessions: ", save_batch_size, ", Time: %.1f" % max_save_interval, "s)")

func force_save():
	"""Force an immediate save regardless of batch settings."""
	if pending_save:
		_save_analytics()
		sessions_since_last_save = 0
		last_save_time = Time.get_ticks_msec() / 1000.0
		pending_save = false
		
		if debug_save_load:
			print("AnalyticsManager: Force save completed")

func _save_analytics():
	"""Save analytics data to file."""
	var save_data = {
		"level_analytics": {},
		"global_analytics": {
			"level_id": global_analytics.level_id,
			"sessions_played": global_analytics.sessions_played,
			"total_playtime": global_analytics.total_playtime,
			"best_survival_time": global_analytics.best_survival_time,
			"average_survival_time": global_analytics.average_survival_time,
			"success_rate": global_analytics.success_rate,
			"bullets_fired": global_analytics.bullets_fired,
			"bullets_hit": global_analytics.bullets_hit,
			"accuracy": global_analytics.accuracy,
			"total_damage_dealt": global_analytics.total_damage_dealt,
			"enemies_killed": global_analytics.enemies_killed,
			"average_bullet_bounces": global_analytics.average_bullet_bounces,
			"average_bullet_distance": global_analytics.average_bullet_distance,
			"multi_kills": global_analytics.multi_kills,
			"multi_hits": global_analytics.multi_hits,
			"distance_traveled": global_analytics.distance_traveled,
			"dashes_used": global_analytics.dashes_used,
			"jumps_performed": global_analytics.jumps_performed,
			"slides_performed": global_analytics.slides_performed,
			"deflections_performed": global_analytics.deflections_performed,
			"time_in_combat": global_analytics.time_in_combat,
			"time_moving": global_analytics.time_moving,
			"time_stationary": global_analytics.time_stationary
		}
	}
	
	# Convert level analytics to dictionary format
	for level_id in level_analytics.keys():
		var analytics = level_analytics[level_id]
		save_data["level_analytics"][level_id] = {
			"level_id": analytics.level_id,
			"sessions_played": analytics.sessions_played,
			"total_playtime": analytics.total_playtime,
			"best_survival_time": analytics.best_survival_time,
			"average_survival_time": analytics.average_survival_time,
			"success_rate": analytics.success_rate,
			"bullets_fired": analytics.bullets_fired,
			"bullets_hit": analytics.bullets_hit,
			"accuracy": analytics.accuracy,
			"total_damage_dealt": analytics.total_damage_dealt,
			"enemies_killed": analytics.enemies_killed,
			"average_bullet_bounces": analytics.average_bullet_bounces,
			"average_bullet_distance": analytics.average_bullet_distance,
			"multi_kills": analytics.multi_kills,
			"multi_hits": analytics.multi_hits,
			"distance_traveled": analytics.distance_traveled,
			"dashes_used": analytics.dashes_used,
			"jumps_performed": analytics.jumps_performed,
			"slides_performed": analytics.slides_performed,
			"deflections_performed": analytics.deflections_performed,
			"time_in_combat": analytics.time_in_combat,
			"time_moving": analytics.time_moving,
			"time_stationary": analytics.time_stationary
		}
	
	var save_file = FileAccess.open(analytics_save_file, FileAccess.WRITE)
	if save_file:
		save_file.store_var(save_data)
		save_file.close()
		if debug_save_load:
			print("AnalyticsManager: Analytics saved")
	else:
		if debug_save_load:
			print("AnalyticsManager: Failed to save analytics file")

func _load_analytics():
	"""Load analytics data from file."""
	if FileAccess.file_exists(analytics_save_file):
		var save_file = FileAccess.open(analytics_save_file, FileAccess.READ)
		if save_file:
			var save_data = save_file.get_var()
			save_file.close()
			
			if debug_save_load:
				print("AnalyticsManager: Analytics loaded")
			
			# Load level analytics
			if save_data.has("level_analytics"):
				for level_id in save_data["level_analytics"].keys():
					var data = save_data["level_analytics"][level_id]
					var analytics = LevelAnalytics.new(level_id)
					analytics.sessions_played = data.get("sessions_played", 0)
					analytics.total_playtime = data.get("total_playtime", 0.0)
					analytics.best_survival_time = data.get("best_survival_time", 0.0)
					analytics.average_survival_time = data.get("average_survival_time", 0.0)
					analytics.success_rate = data.get("success_rate", 0.0)
					analytics.bullets_fired = data.get("bullets_fired", 0)
					analytics.bullets_hit = data.get("bullets_hit", 0)
					analytics.accuracy = data.get("accuracy", 0.0)
					analytics.total_damage_dealt = data.get("total_damage_dealt", 0.0)
					analytics.enemies_killed = data.get("enemies_killed", 0)
					analytics.average_bullet_bounces = data.get("average_bullet_bounces", 0.0)
					analytics.average_bullet_distance = data.get("average_bullet_distance", 0.0)
					analytics.multi_kills = data.get("multi_kills", 0)
					analytics.multi_hits = data.get("multi_hits", 0)
					analytics.distance_traveled = data.get("distance_traveled", 0.0)
					analytics.dashes_used = data.get("dashes_used", 0)
					analytics.jumps_performed = data.get("jumps_performed", 0)
					analytics.slides_performed = data.get("slides_performed", 0)
					analytics.deflections_performed = data.get("deflections_performed", 0)
					analytics.time_in_combat = data.get("time_in_combat", 0.0)
					analytics.time_moving = data.get("time_moving", 0.0)
					analytics.time_stationary = data.get("time_stationary", 0.0)
					level_analytics[level_id] = analytics
			
			# Load global analytics
			if save_data.has("global_analytics"):
				var data = save_data["global_analytics"]
				global_analytics = LevelAnalytics.new("global")
				
				# Check if data is a dictionary or an object
				if data is Dictionary:
					global_analytics.sessions_played = data.get("sessions_played", 0)
					global_analytics.total_playtime = data.get("total_playtime", 0.0)
					global_analytics.best_survival_time = data.get("best_survival_time", 0.0)
					global_analytics.average_survival_time = data.get("average_survival_time", 0.0)
					global_analytics.success_rate = data.get("success_rate", 0.0)
					global_analytics.bullets_fired = data.get("bullets_fired", 0)
					global_analytics.bullets_hit = data.get("bullets_hit", 0)
					global_analytics.accuracy = data.get("accuracy", 0.0)
					global_analytics.total_damage_dealt = data.get("total_damage_dealt", 0.0)
					global_analytics.enemies_killed = data.get("enemies_killed", 0)
					global_analytics.average_bullet_bounces = data.get("average_bullet_bounces", 0.0)
					global_analytics.average_bullet_distance = data.get("average_bullet_distance", 0.0)
					global_analytics.multi_kills = data.get("multi_kills", 0)
					global_analytics.multi_hits = data.get("multi_hits", 0)
					global_analytics.distance_traveled = data.get("distance_traveled", 0.0)
					global_analytics.dashes_used = data.get("dashes_used", 0)
					global_analytics.jumps_performed = data.get("jumps_performed", 0)
					global_analytics.slides_performed = data.get("slides_performed", 0)
					global_analytics.deflections_performed = data.get("deflections_performed", 0)
					global_analytics.time_in_combat = data.get("time_in_combat", 0.0)
					global_analytics.time_moving = data.get("time_moving", 0.0)
					global_analytics.time_stationary = data.get("time_stationary", 0.0)
				else:
					# Handle old format where global_analytics was saved as an object
					if debug_save_load:
						print("AnalyticsManager: Converting old global analytics format")
					# If it's an old object format, just use default values
					# The data will be rebuilt as new sessions are played
		else:
			if debug_save_load:
				print("AnalyticsManager: Failed to load analytics file")
	else:
		if debug_save_load:
			print("AnalyticsManager: No analytics file found, starting fresh")

## === EVENT HANDLERS ===

func _on_level_selected(level_data):
	"""Called when a level is selected."""
	start_session(level_data.id)

func _on_player_died():
	"""Called when player dies."""
	if current_session:
		end_session(false)  # Session failed

func _on_game_restart():
	"""Called when game is restarted."""
	# Store the level_id before ending the session
	var level_id = "unknown"
	if current_session:
		level_id = current_session.level_id
		end_session(false)  # Previous session failed
	
	# Get level from LevelManager if we don't have it
	if level_id == "unknown":
		var level_manager = get_node_or_null("/root/LevelManager")
		if level_manager and level_manager.current_level:
			level_id = level_manager.current_level.id
	
	# Only start new session if we have a valid level
	if level_id != "unknown":
		start_session(level_id)

## === PUBLIC API ===

func clear_analytics():
	"""Clear all analytics data (for testing/debugging)."""
	level_analytics.clear()
	global_analytics = LevelAnalytics.new("global")
	# Reset save batching state
	sessions_since_last_save = 0
	last_save_time = Time.get_ticks_msec() / 1000.0
	pending_save = false
	# Force immediate save after clearing
	_save_analytics()
	if debug_analytics:
		print("AnalyticsManager: All analytics data cleared")

func _notification(what):
	"""Handle system notifications including application quit."""
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		# Application is being closed
		if debug_save_load:
			print("AnalyticsManager: Application closing, saving pending analytics")
		
		# End current session if any
		if current_session:
			end_session(false)  # Consider incomplete session as failed
		
		# Force save any pending data
		force_save()
