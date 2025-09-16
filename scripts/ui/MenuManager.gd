extends Control

# === MAIN MENU MANAGER ===
# Handles main menu functionality and navigation

## === EXPORTED CONFIGURATION ===

@export_group("Scene Paths")
## Path to level selection scene
@export var level_selection_scene: String = "res://scenes/ui/LevelSelection.tscn"
## Path to options menu scene
@export var options_menu_scene: String = "res://scenes/ui/OptionsMenu.tscn"

@export_group("Audio Settings")
## Enable button click sounds
@export var enable_button_sounds: bool = true
## Button hover sound effect
@export var button_hover_sound: AudioStream = null
## Button click sound effect
@export var button_click_sound: AudioStream = null

@export_group("Animation Settings")
## Enable menu transition animations
@export var enable_animations: bool = true
## Fade transition duration
@export var fade_duration: float = 0.3

@export_group("Debug Settings")
## Enable debug output for menu events
@export var debug_menu_events: bool = false
## Enable debug output for scene transitions
@export var debug_transitions: bool = false
## Enable debug output for button connections
@export var debug_connections: bool = false

## === RUNTIME STATE ===
# Button references
@onready var new_game_button: Button = $MenuContainer/ButtonContainer/NewGameButton
@onready var options_button: Button = $MenuContainer/ButtonContainer/OptionsButton
@onready var exit_button: Button = $MenuContainer/ButtonContainer/ExitButton
# Audio player for menu sounds
var audio_player: AudioStreamPlayer = null

# === SIGNALS ===
signal menu_transition_started(target_scene: String)
signal menu_transition_completed()

func _ready():
	# Setup button connections
	_setup_buttons()
	
	# Setup audio
	_setup_audio()
	
	# Setup mouse mode
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if debug_menu_events:
		print("MenuManager: Main menu ready")

func _setup_buttons():
	"""Connect menu buttons."""
	# Connect New Game button
	if new_game_button:
		new_game_button.pressed.connect(_on_new_game_pressed)
		if enable_button_sounds:
			new_game_button.mouse_entered.connect(_on_button_hover)
		if debug_connections:
			print("MenuManager: Connected New Game button")
	
	# Connect Options button
	if options_button:
		options_button.pressed.connect(_on_options_pressed)
		if enable_button_sounds:
			options_button.mouse_entered.connect(_on_button_hover)
		if debug_connections:
			print("MenuManager: Connected Options button")
	
	# Connect Exit button
	if exit_button:
		exit_button.pressed.connect(_on_exit_pressed)
		if enable_button_sounds:
			exit_button.mouse_entered.connect(_on_button_hover)
		if debug_connections:
			print("MenuManager: Connected Exit button")

func _setup_audio():
	"""Setup audio player for menu sounds."""
	if enable_button_sounds:
		audio_player = AudioStreamPlayer.new()
		add_child(audio_player)

func _on_new_game_pressed():
	"""Handle New Game button press."""
	if debug_menu_events:
		print("MenuManager: New Game pressed")
	
	_play_click_sound()
	_transition_to_scene(level_selection_scene)

func _on_options_pressed():
	"""Handle Options button press."""
	if debug_menu_events:
		print("MenuManager: Options pressed")
	
	_play_click_sound()
	_transition_to_scene(options_menu_scene)

func _on_exit_pressed():
	"""Handle Exit button press."""
	if debug_menu_events:
		print("MenuManager: Exit pressed")
	
	_play_click_sound()
	
	# Wait a moment for sound to play, then quit
	if enable_button_sounds and button_click_sound:
		await get_tree().create_timer(0.2).timeout
	
	get_tree().quit()

func _on_button_hover():
	"""Handle button hover sound."""
	if enable_button_sounds and button_hover_sound and audio_player:
		audio_player.stream = button_hover_sound
		audio_player.play()

func _play_click_sound():
	"""Play button click sound."""
	if enable_button_sounds and button_click_sound and audio_player:
		audio_player.stream = button_click_sound
		audio_player.play()

func _transition_to_scene(scene_path: String):
	"""Transition to another scene with optional fade effect."""
	menu_transition_started.emit(scene_path)
	
	if debug_transitions:
		print("MenuManager: Transitioning to: ", scene_path)
	
	if enable_animations:
		# Simple fade out effect
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, fade_duration)
		await tween.finished
	
	# Change scene
	var error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		if debug_transitions:
			print("MenuManager: Failed to load scene: ", scene_path, " Error: ", error)
		# Restore visibility if scene load failed
		modulate.a = 1.0
	else:
		menu_transition_completed.emit()

# === PUBLIC API ===

func set_button_sounds(hover_sound: AudioStream, click_sound: AudioStream):
	"""Set button sound effects."""
	button_hover_sound = hover_sound
	button_click_sound = click_sound

func enable_button_sound_effects(enabled: bool):
	"""Enable or disable button sound effects."""
	enable_button_sounds = enabled

func force_transition_to_level_select():
	"""Force transition to level selection (for external calls)."""
	_transition_to_scene(level_selection_scene)

func force_transition_to_options():
	"""Force transition to options menu (for external calls)."""
	_transition_to_scene(options_menu_scene)

# === DEBUG ===

func print_menu_status():
	"""Debug function to print menu state."""
	print("\n=== MENU MANAGER STATUS ===")
	print("New Game button: ", "Connected" if new_game_button else "Missing")
	print("Options button: ", "Connected" if options_button else "Missing")
	print("Exit button: ", "Connected" if exit_button else "Missing")
	print("Audio enabled: ", enable_button_sounds)
	print("Animations enabled: ", enable_animations)
	print("===========================\n")
