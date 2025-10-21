extends Node

# === DEBUG FLAGS (EASY TOGGLE) ===
const DEBUG_STATE_TRANSITIONS = false  # State transition logs

# === CENTRALIZED GAME STATE MANAGER ===
# Autoload singleton that centralizes all game state transitions and cleanup
# Eliminates duplicate cleanup code across different UI screens and managers

## === EXPORTED CONFIGURATION ===

## === PUBLIC API ===

func reset_all_game_systems():
	"""Centralized function to reset all game systems for menu transitions."""
	if DEBUG_STATE_TRANSITIONS:
		print("GameStateManager: Resetting all game systems")
	
	# 1. Reset TimeManager
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		time_manager.deactivate_for_menus()
	
	# 1.5. Deactivate MenuTimeManager
	var menu_time_manager = get_node_or_null("/root/MenuTimeManager")
	if menu_time_manager:
		menu_time_manager.deactivate_for_gameplay()
	
	# 2. Reset LayeredVisualManager
	var layered_visual_manager = get_node_or_null("/root/LayeredVisualManager")
	if layered_visual_manager and layered_visual_manager.has_method("deactivate"):
		layered_visual_manager.deactivate()
	
	# 3. Reset GameplayUIManager  
	var ui_manager = get_node_or_null("/root/GameplayUIManager")
	if ui_manager:
		ui_manager.deactivate_gameplay_ui()
	
	# 4. Reset LevelManager gameplay systems
	var level_manager = get_node_or_null("/root/LevelManager")
	if level_manager and level_manager.has_method("deactivate_gameplay_systems"):
		level_manager.deactivate_gameplay_systems()
	
	# 5. Reset ArenaSpawnManager
	var arena_spawn_manager = get_node_or_null("/root/ArenaSpawnManager")
	if arena_spawn_manager:
		arena_spawn_manager.stop_spawning()
		if arena_spawn_manager.has_method("reset_for_level"):
			arena_spawn_manager.reset_for_level()
	
	# 6. Reset TracerManager
	var tracer_manager = get_node_or_null("/root/TracerManager")
	if tracer_manager:
		tracer_manager.reset_tracer_system()
	
	# 7. Reset ScoreManager
	var score_manager = get_node_or_null("/root/ScoreManager")
	if score_manager:
		score_manager.reset_score()
	
	# 8. Stop continuous inverse SFX
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager and audio_manager.has_method("stop_continuous_inverse_sfx"):
		audio_manager.stop_continuous_inverse_sfx()
	
	# 9. Emit game restart signal for any other systems
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.game_restart_requested.emit()
	
	# 10. Reset GameManager state
	if game_manager:
		game_manager.change_game_state(game_manager.GameState.PLAYING)
	
	if DEBUG_STATE_TRANSITIONS:
		print("GameStateManager: All game systems reset")

func complete_restart_level():
	"""COMPLETELY restart the current level - reset EVERYTHING and reload properly."""
	if DEBUG_STATE_TRANSITIONS:
		print("GameStateManager: *** COMPLETE LEVEL RESTART ***")
	
	# Get current level before cleanup
	var level_manager = get_node_or_null("/root/LevelManager")
	if not level_manager or not level_manager.current_level:
		if DEBUG_STATE_TRANSITIONS:
			print("GameStateManager: No current level found!")
		return false
	
	var current_level = level_manager.current_level
	if DEBUG_STATE_TRANSITIONS:
		print("GameStateManager: Restarting level: ", current_level.display_name)
	
	# === STEP 1: STOP ALL SYSTEMS ===
	var arena_spawn_manager = get_node_or_null("/root/ArenaSpawnManager")
	if arena_spawn_manager:
		arena_spawn_manager.stop_spawning()
		if DEBUG_STATE_TRANSITIONS:
			print("GameStateManager: Stopped enemy spawning")
	
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		time_manager.deactivate_for_menus()
		if DEBUG_STATE_TRANSITIONS:
			print("GameStateManager: Deactivated TimeManager")
	
	var ui_manager = get_node_or_null("/root/GameplayUIManager")
	if ui_manager:
		ui_manager.deactivate_gameplay_ui()
		if DEBUG_STATE_TRANSITIONS:
			print("GameStateManager: Deactivated GameplayUI")
	
	var layered_visual_manager = get_node_or_null("/root/LayeredVisualManager")
	if layered_visual_manager:
		layered_visual_manager.deactivate()
		if DEBUG_STATE_TRANSITIONS:
			print("GameStateManager: Deactivated LayeredVisualManager")
	
	# === STEP 2: CLEAN UP EVERYTHING ===
	var tracer_manager = get_node_or_null("/root/TracerManager")
	if tracer_manager:
		tracer_manager.reset_tracer_system()
		if DEBUG_STATE_TRANSITIONS:
			print("GameStateManager: Reset TracerManager")
	
	var score_manager = get_node_or_null("/root/ScoreManager")
	if score_manager:
		score_manager.reset_score()
		if DEBUG_STATE_TRANSITIONS:
			print("GameStateManager: Reset score to 0")
	
	if arena_spawn_manager and arena_spawn_manager.has_method("reset_for_level"):
		arena_spawn_manager.reset_for_level()
		if DEBUG_STATE_TRANSITIONS:
			print("GameStateManager: Reset ArenaSpawnManager")
	
	# Stop continuous inverse SFX
	var audio_manager = get_node_or_null("/root/AudioManager")
	if audio_manager and audio_manager.has_method("stop_continuous_inverse_sfx"):
		audio_manager.stop_continuous_inverse_sfx()
		if DEBUG_STATE_TRANSITIONS:
			print("GameStateManager: Stopped continuous inverse SFX")
	
	# Track session end for analytics
	AnalyticsManager.end_session(false)
	if DEBUG_STATE_TRANSITIONS:
		print("GameStateManager: Ended analytics session")
	
	# === STEP 3: EMIT CLEANUP SIGNALS ===
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.game_restart_requested.emit()
		if DEBUG_STATE_TRANSITIONS:
			print("GameStateManager: Emitted restart signal")
	
	# Wait for cleanup
	await get_tree().process_frame
	await get_tree().process_frame
	
	# === STEP 4: RELOAD LEVEL PROPERLY ===
	if DEBUG_STATE_TRANSITIONS:
		print("GameStateManager: Reloading level through LevelManager...")
	
	level_manager.current_level = current_level
	await level_manager.load_selected_level()
	
	if DEBUG_STATE_TRANSITIONS:
		print("GameStateManager: *** RESTART COMPLETE - All systems reactivated ***")
	
	return true

func reset_for_main_menu():
	"""Reset systems specifically for returning to main menu."""
	if DEBUG_STATE_TRANSITIONS:
		print("GameStateManager: Resetting for main menu")
	
	# Resume time system for menus
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		time_manager.resume_time()
	
	# Activate menu time manager for background effects
	var menu_time_manager = get_node_or_null("/root/MenuTimeManager")
	if menu_time_manager:
		menu_time_manager.activate_for_menu()
	
	# Standard reset
	reset_all_game_systems()
	
	# Note: Mouse mode will be set by the target scene (main menu)

func reset_for_analytics():
	"""Reset systems specifically for analytics menu (keep mouse visible)."""
	if DEBUG_STATE_TRANSITIONS:
		print("GameStateManager: Resetting for analytics")
	
	# Store current mouse position to prevent reset
	var current_mouse_pos = get_viewport().get_mouse_position()
	
	# Standard reset
	reset_all_game_systems()
	
	# Keep mouse visible for analytics menu WITHOUT resetting position
	if Input.get_mouse_mode() != Input.MOUSE_MODE_VISIBLE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Restore mouse position (wait a frame for mouse mode to take effect)
	await get_tree().process_frame
	get_viewport().warp_mouse(current_mouse_pos)

func cleanup_and_change_scene(scene_path: String):
	"""Clean up game state and change to specified scene."""
	if DEBUG_STATE_TRANSITIONS:
		print("GameStateManager: Cleaning up and changing to: ", scene_path)
	
	reset_for_main_menu()
	
	# Clean up TracerManager before scene change to prevent lambda errors
	var tracer_manager = get_node_or_null("/root/TracerManager")
	if tracer_manager:
		tracer_manager.reset_tracer_system()
		# Wait a frame for cleanup to complete
		await get_tree().process_frame
	
	# Change scene
	var error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		if DEBUG_STATE_TRANSITIONS:
			print("GameStateManager: Failed to load scene: ", scene_path, " Error: ", error)
