extends Control
class_name DeathScreen

# Animation properties
@export var fade_duration: float = 1.0
@export var text_animation_duration: float = 2.0

# UI elements
@onready var background: ColorRect = $Background
@onready var death_text: Label = $VBoxContainer/DeathLabel
@onready var score_text: Label = $VBoxContainer/ScoreLabel
@onready var high_score_text: Label = $VBoxContainer/HighScoreLabel
@onready var restart_button: Button = $VBoxContainer/RestartButton
@onready var stats_button: Button = $VBoxContainer/StatsButton
@onready var main_menu_button: Button = $VBoxContainer/MainMenuButton

# Animation state
var is_animating := false

func _ready():
	print("DeathScreen: _ready() called - Instance ID: ", get_instance_id())
	# Set to process even when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Initially hide everything
	background.modulate.a = 0.0
	death_text.modulate.a = 0.0
	score_text.modulate.a = 0.0
	high_score_text.modulate.a = 0.0
	restart_button.modulate.a = 0.0
	stats_button.modulate.a = 0.0
	main_menu_button.modulate.a = 0.0
	
	# Connect button signals
	_setup_buttons()
	
	# Wait a frame to ensure GameManager is loaded
	await get_tree().process_frame
	
	# Connect to game manager
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		print("DeathScreen: Found GameManager, connecting signals")
		print("DeathScreen: GameManager instance ID: ", game_manager.get_instance_id())
		
		# Disconnect first to avoid duplicate connections
		if game_manager.player_died.is_connected(_on_player_died):
			print("DeathScreen: Disconnecting existing player_died connection")
			game_manager.player_died.disconnect(_on_player_died)
		if game_manager.game_restart_requested.is_connected(_on_game_restart_requested):
			print("DeathScreen: Disconnecting existing game_restart_requested connection")
			game_manager.game_restart_requested.disconnect(_on_game_restart_requested)
		
		# Connect the signals
		game_manager.player_died.connect(_on_player_died)
		game_manager.game_restart_requested.connect(_on_game_restart_requested)
		print("DeathScreen: Successfully connected to GameManager signals")
		print("DeathScreen: player_died connected: ", game_manager.player_died.is_connected(_on_player_died))
		print("DeathScreen: game_restart_requested connected: ", game_manager.game_restart_requested.is_connected(_on_game_restart_requested))
	else:
		print("Warning: GameManager not found for DeathScreen")

func _setup_buttons():
	"""Setup button connections."""
	# Connect analytics button
	if stats_button and not stats_button.pressed.is_connected(_on_analytics_pressed):
		stats_button.pressed.connect(_on_analytics_pressed)
		print("DeathScreen: Connected analytics button")
	
	# Connect main menu button
	if main_menu_button and not main_menu_button.pressed.is_connected(_on_main_menu_pressed):
		main_menu_button.pressed.connect(_on_main_menu_pressed)
		print("DeathScreen: Connected main menu button")

func _on_player_died():
	"""Called when player dies - start death animation"""
	print("DeathScreen: Received player_died signal!")
	print("DeathScreen: Current visibility: ", visible)
	print("DeathScreen: Current modulate alpha: ", modulate.a)
	
	# Update score display
	_update_score_display()
	
	show()
	play_death_animation()
	
	print("DeathScreen: After show() - visibility: ", visible)
	print("DeathScreen: After play_death_animation() - modulate alpha: ", modulate.a)

func _update_score_display():
	"""Update the score display with current and high scores."""
	var score_manager = get_node_or_null("/root/ScoreManager")
	if score_manager:
		var current_score = score_manager.get_current_score()
		var high_score = score_manager.get_high_score()
		
		score_text.text = "Score: " + str(current_score)
		high_score_text.text = "High Score: " + str(high_score)
		
		print("DeathScreen: Updated score display - Current: ", current_score, ", High: ", high_score)
	else:
		print("WARNING: ScoreManager not found for DeathScreen!")
		score_text.text = "Score: 0"
		high_score_text.text = "High Score: 0"

func _on_game_restart_requested():
	"""Called when game is restarting - hide death screen"""
	hide()
	reset_animation_state()

func play_death_animation():
	"""Show the death screen immediately with no animations"""
	visible = true
	
	# Show everything immediately
	background.modulate.a = 0.8
	death_text.modulate.a = 1.0
	score_text.modulate.a = 1.0
	high_score_text.modulate.a = 1.0
	restart_button.modulate.a = 1.0
	stats_button.modulate.a = 1.0
	main_menu_button.modulate.a = 1.0
	
	is_animating = false

func reset_animation_state():
	"""Reset animation state for next death"""
	background.modulate.a = 0.0
	death_text.modulate.a = 0.0
	score_text.modulate.a = 0.0
	high_score_text.modulate.a = 0.0
	restart_button.modulate.a = 0.0
	stats_button.modulate.a = 0.0
	main_menu_button.modulate.a = 0.0
	is_animating = false
	visible = false

func _on_analytics_pressed():
	"""Handle analytics button press."""
	print("DeathScreen: Analytics button pressed")
	# Stop all gameplay SFX before leaving
	AudioManager.stop_all_sfx()
	# Call cleanup functions but don't resume time (keep mouse visible for stats)
	_call_game_cleanup_for_stats()
	get_tree().change_scene_to_file("res://scenes/ui/AnalyticsMenu.tscn")

func _call_game_cleanup():
	"""Call the same cleanup functions as GameManager.return_to_main_menu()"""
	var game_state_manager = get_node_or_null("/root/GameStateManager")
	if game_state_manager:
		game_state_manager.reset_for_main_menu()
	else:
		# Fallback to individual cleanup if GameStateManager not available
		_cleanup_systems_fallback()
	
	print("DeathScreen: Called game cleanup functions")

func _cleanup_systems_fallback():
	"""Fallback cleanup method if GameStateManager is not available."""
	# Resume time system
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		time_manager.resume_time()
	
	# Clean up UI
	var ui_manager = get_node_or_null("/root/GameplayUIManager")
	if ui_manager:
		ui_manager.deactivate_gameplay_ui()
	
	# Deactivate gameplay systems
	var level_manager = get_node_or_null("/root/LevelManager")
	if level_manager and level_manager.has_method("deactivate_gameplay_systems"):
		level_manager.deactivate_gameplay_systems()
	
	# Emit restart signal to clean up systems
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.game_restart_requested.emit()
	
	# Reset game state
	if game_manager:
		game_manager.change_game_state(game_manager.GameState.PLAYING)
	
	# Clean up TracerManager
	var tracer_manager = get_node_or_null("/root/TracerManager")
	if tracer_manager:
		tracer_manager.reset_tracer_system()

func _call_game_cleanup_for_stats():
	"""Call cleanup functions for stats screen (ensure mouse is visible)"""
	var game_state_manager = get_node_or_null("/root/GameStateManager")
	if game_state_manager:
		game_state_manager.reset_for_analytics()
	else:
		# Fallback to individual cleanup if GameStateManager not available
		_cleanup_for_stats_fallback()
	
	print("DeathScreen: Called game cleanup functions for stats")

func _cleanup_for_stats_fallback():
	"""Fallback cleanup method for stats if GameStateManager is not available."""
	# Make sure mouse is visible for stats screen
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	# Clean up UI
	var ui_manager = get_node_or_null("/root/GameplayUIManager")
	if ui_manager:
		ui_manager.deactivate_gameplay_ui()
	
	# Deactivate gameplay systems
	var level_manager = get_node_or_null("/root/LevelManager")
	if level_manager and level_manager.has_method("deactivate_gameplay_systems"):
		level_manager.deactivate_gameplay_systems()
	
	# Emit restart signal to clean up systems
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.game_restart_requested.emit()
	
	# Reset game state
	if game_manager:
		game_manager.change_game_state(game_manager.GameState.PLAYING)
	
	# Clean up TracerManager
	var tracer_manager = get_node_or_null("/root/TracerManager")
	if tracer_manager:
		tracer_manager.reset_tracer_system()

func _on_main_menu_pressed():
	"""Handle main menu button press."""
	print("DeathScreen: Main menu button pressed")
	# Stop all gameplay SFX before leaving
	AudioManager.stop_all_sfx()
	# Call the same cleanup functions as analytics but go to main menu
	_call_game_cleanup()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn") 
