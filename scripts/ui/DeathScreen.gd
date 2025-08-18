extends Control
class_name DeathScreen

# Animation properties
@export var fade_duration: float = 1.0
@export var text_animation_duration: float = 2.0

# UI elements
@onready var background: ColorRect = $Background
@onready var death_text: Label = $VBoxContainer/DeathText
@onready var score_text: Label = $VBoxContainer/ScoreText
@onready var high_score_text: Label = $VBoxContainer/HighScoreText
@onready var restart_button: Button = $VBoxContainer/RestartButton

# Animation state
var is_animating := false

func _ready():
	print("DeathScreen: _ready() called")
	# Set to process even when paused
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Initially hide everything
	background.modulate.a = 0.0
	death_text.modulate.a = 0.0
	score_text.modulate.a = 0.0
	high_score_text.modulate.a = 0.0
	restart_button.modulate.a = 0.0
	
	# Wait a frame to ensure GameManager is loaded
	await get_tree().process_frame
	
	# Connect to game manager
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		print("DeathScreen: Found GameManager, connecting signals")
		# Disconnect first to avoid duplicate connections
		if game_manager.player_died.is_connected(_on_player_died):
			game_manager.player_died.disconnect(_on_player_died)
		if game_manager.game_restart_requested.is_connected(_on_game_restart_requested):
			game_manager.game_restart_requested.disconnect(_on_game_restart_requested)
		
		game_manager.player_died.connect(_on_player_died)
		game_manager.game_restart_requested.connect(_on_game_restart_requested)
		print("DeathScreen: Successfully connected to GameManager signals")
	else:
		print("Warning: GameManager not found for DeathScreen")

func _on_player_died():
	"""Called when player dies - start death animation"""
	print("DeathScreen: Received player_died signal!")
	
	# Update score display
	_update_score_display()
	
	show()
	play_death_animation()

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
	"""Play the death screen animation sequence"""
	if is_animating:
		return
	
	visible = true
	
	is_animating = true
	
	# Fade in background
	var tween = create_tween()
	tween.set_parallel(true)
	
	# Background fade
	tween.tween_property(background, "modulate:a", 0.8, fade_duration)
	
	# Death text fade in
	tween.tween_property(death_text, "modulate:a", 1.0, fade_duration)
	
	# Score text fade in
	tween.tween_property(score_text, "modulate:a", 1.0, fade_duration)
	
	# High score text fade in
	tween.tween_property(high_score_text, "modulate:a", 1.0, fade_duration)
	
	# Wait for first tween to finish
	await tween.finished
	
	# Wait a bit more
	await get_tree().create_timer(0.5).timeout
	
	# Show restart elements
	var restart_tween = create_tween()
	restart_tween.set_parallel(true)
	restart_tween.tween_property(restart_button, "modulate:a", 1.0, text_animation_duration)
	
	await restart_tween.finished
	is_animating = false

func reset_animation_state():
	"""Reset animation state for next death"""
	background.modulate.a = 0.0
	death_text.modulate.a = 0.0
	score_text.modulate.a = 0.0
	high_score_text.modulate.a = 0.0
	restart_button.modulate.a = 0.0
	is_animating = false
	visible = false 
