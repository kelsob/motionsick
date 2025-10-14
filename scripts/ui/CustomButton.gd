@tool
extends Button

# === CUSTOM BUTTON WITH UNIVERSAL SFX ===
# This button automatically plays hover/click sounds from AudioManager

## === EXPORTED PROPERTIES ===
@export_group("Button Configuration")
## Text to display on the button
@export var button_text: String = "Button"

@export_group("Audio Configuration")
## Enable hover sound effect
@export var enable_hover_sfx: bool = true
## Enable click sound effect
@export var enable_click_sfx: bool = true
## Volume modifier for hover sound (0.0 to 1.0)
@export var hover_volume: float = 1.0
## Volume modifier for click sound (0.0 to 1.0)
@export var click_volume: float = 1.0

func _ready():
	# Apply button text from export
	text = button_text
	
	# Connect to button signals for SFX
	if enable_hover_sfx:
		mouse_entered.connect(_on_mouse_entered)
	
	if enable_click_sfx:
		pressed.connect(_on_pressed)

func _on_mouse_entered():
	"""Play hover sound when mouse enters button."""
	if AudioManager:
		AudioManager.play_sfx("ui_tick", hover_volume)

func _on_pressed():
	"""Play click sound when button is pressed."""
	if AudioManager:
		AudioManager.play_sfx("ui_accept", click_volume)
