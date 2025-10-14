extends Control
class_name VictoryScreen

# Animation properties
@export var fade_duration: float = 1.0
@export var text_animation_duration: float = 2.0

# UI elements
@onready var background: ColorRect = $Background
@onready var victory_label: Label = $VBoxContainer/VictoryLabel
@onready var score_label: Label = $VBoxContainer/ScoreLabel
@onready var high_score_label: Label = $VBoxContainer/HighScoreLabel
@onready var new_high_score_label: Label = $VBoxContainer/NewHighScoreLabel
@onready var level_select_button: Button = $VBoxContainer/LevelSelectButton
@onready var stats_button: Button = $VBoxContainer/StatsButton
@onready var main_menu_button: Button = $VBoxContainer/MainMenuButton

# Animation state
var is_animating := false

func _ready():
	print("VictoryScreen: _ready() called - Instance ID: ", get_instance_id())
	# Set to process even when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Initially hide everything
	background.modulate.a = 0.0
	victory_label.modulate.a = 0.0
	score_label.modulate.a = 0.0
	high_score_label.modulate.a = 0.0
	new_high_score_label.modulate.a = 0.0
	new_high_score_label.visible = false
	level_select_button.modulate.a = 0.0
	stats_button.modulate.a = 0.0
	main_menu_button.modulate.a = 0.0
	
	# Connect button signals
	_setup_buttons()
	
	# Wait a frame to ensure GameManager is loaded
	await get_tree().process_frame
	
	# Connect to game manager
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		print("VictoryScreen: Found GameManager, connecting signals")
		print("VictoryScreen: GameManager instance ID: ", game_manager.get_instance_id())
		
		# Disconnect first to avoid duplicate connections
		if game_manager.level_won.is_connected(_on_level_won):
			print("VictoryScreen: Disconnecting existing level_won connection")
			game_manager.level_won.disconnect(_on_level_won)
		if game_manager.game_restart_requested.is_connected(_on_game_restart_requested):
			print("VictoryScreen: Disconnecting existing game_restart_requested connection")
			game_manager.game_restart_requested.disconnect(_on_game_restart_requested)
		
		# Connect the signals
		game_manager.level_won.connect(_on_level_won)
		game_manager.game_restart_requested.connect(_on_game_restart_requested)
		print("VictoryScreen: Successfully connected to GameManager signals")
		print("VictoryScreen: level_won connected: ", game_manager.level_won.is_connected(_on_level_won))
		print("VictoryScreen: game_restart_requested connected: ", game_manager.game_restart_requested.is_connected(_on_game_restart_requested))
	else:
		print("Warning: GameManager not found for VictoryScreen")

func _setup_buttons():
	"""Setup button connections."""
	# Connect level select button
	if level_select_button and not level_select_button.pressed.is_connected(_on_level_select_pressed):
		level_select_button.pressed.connect(_on_level_select_pressed)
		print("VictoryScreen: Connected level select button")
	
	# Connect stats button
	if stats_button and not stats_button.pressed.is_connected(_on_stats_pressed):
		stats_button.pressed.connect(_on_stats_pressed)
		print("VictoryScreen: Connected stats button")
	
	# Connect main menu button
	if main_menu_button and not main_menu_button.pressed.is_connected(_on_main_menu_pressed):
		main_menu_button.pressed.connect(_on_main_menu_pressed)
		print("VictoryScreen: Connected main menu button")

func _on_level_won():
	"""Called when level is won - start victory animation"""
	print("VictoryScreen: Received level_won signal!")
	print("VictoryScreen: Current visibility: ", visible)
	print("VictoryScreen: Current modulate alpha: ", modulate.a)
	
	# Update score display
	_update_score_display()
	
	show()
	play_victory_animation()
	
	print("VictoryScreen: After show() - visibility: ", visible)
	print("VictoryScreen: After play_victory_animation() - modulate alpha: ", modulate.a)

func _update_score_display():
	"""Update the score display with current and high scores."""
	var score_manager = get_node_or_null("/root/ScoreManager")
	if score_manager:
		var current_score = score_manager.get_current_score()
		var high_score = score_manager.get_high_score()
		
		score_label.text = "Score: " + str(current_score)
		high_score_label.text = "High Score: " + str(high_score)
		
		# Check if this is a new high score
		if current_score > high_score:
			new_high_score_label.visible = true
			print("VictoryScreen: NEW HIGH SCORE! Current: ", current_score, " beats old: ", high_score)
		else:
			new_high_score_label.visible = false
			print("VictoryScreen: Updated score display - Current: ", current_score, ", High: ", high_score)
	else:
		print("WARNING: ScoreManager not found for VictoryScreen!")
		score_label.text = "Score: 0"
		high_score_label.text = "High Score: 0"
		new_high_score_label.visible = false

func _on_game_restart_requested():
	"""Called when game is restarting - hide victory screen"""
	hide()
	reset_animation_state()

func play_victory_animation():
	"""Show the victory screen immediately with no animations"""
	visible = true
	
	# Show everything immediately
	background.modulate.a = 0.8
	victory_label.modulate.a = 1.0
	score_label.modulate.a = 1.0
	high_score_label.modulate.a = 1.0
	level_select_button.modulate.a = 1.0
	stats_button.modulate.a = 1.0
	main_menu_button.modulate.a = 1.0
	
	# Show new high score label if it's visible (determined by _update_score_display)
	if new_high_score_label.visible:
		new_high_score_label.modulate.a = 1.0
	
	is_animating = false

func reset_animation_state():
	"""Reset animation state for next victory"""
	background.modulate.a = 0.0
	victory_label.modulate.a = 0.0
	score_label.modulate.a = 0.0
	high_score_label.modulate.a = 0.0
	new_high_score_label.modulate.a = 0.0
	new_high_score_label.visible = false
	level_select_button.modulate.a = 0.0
	stats_button.modulate.a = 0.0
	main_menu_button.modulate.a = 0.0
	is_animating = false
	visible = false

func _on_stats_pressed():
	"""Handle stats button press."""
	print("VictoryScreen: Stats button pressed")
	# Stop all gameplay SFX before leaving
	AudioManager.stop_all_sfx()
	# Call cleanup functions but don't resume time (keep mouse visible for stats)
	_call_game_cleanup_for_stats()
	get_tree().change_scene_to_file("res://scenes/ui/AnalyticsMenu.tscn")

func _on_level_select_pressed():
	"""Handle level select button press - go to level select."""
	print("VictoryScreen: Level select button pressed")
	# Stop all gameplay SFX before leaving
	AudioManager.stop_all_sfx()
	# Call cleanup and go to level selection
	_call_game_cleanup()
	get_tree().change_scene_to_file("res://scenes/ui/LevelSelection.tscn")

func _call_game_cleanup():
	"""Call the same cleanup functions as GameManager.return_to_main_menu()"""
	var game_state_manager = get_node_or_null("/root/GameStateManager")
	if game_state_manager:
		game_state_manager.reset_for_main_menu()
	else:
		# Fallback to individual cleanup if GameStateManager not available
		_cleanup_systems_fallback()
	
	print("VictoryScreen: Called game cleanup functions")

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
	
	print("VictoryScreen: Called game cleanup functions for stats")

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
	print("VictoryScreen: Main menu button pressed")
	# Stop all gameplay SFX before leaving
	AudioManager.stop_all_sfx()
	# Call the same cleanup functions and go to main menu
	_call_game_cleanup()
	get_tree().change_scene_to_file("res://scenes/ui/MainMenu.tscn")
