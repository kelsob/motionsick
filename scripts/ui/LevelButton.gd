extends PanelContainer

# === LEVEL BUTTON COMPONENT ===
# A reusable level selection button that you design as a scene

@export_group("Debug Settings")
## Enable debug output for button events
@export var debug_button: bool = false

## === RUNTIME STATE ===
# UI references
@onready var select_button: Button = $SelectButton
@onready var content_container: VBoxContainer = $VBoxContainer
@onready var title_label: Label = $VBoxContainer/LevelTitleLabel
@onready var description_label: Label = $VBoxContainer/DescriptionLabel
@onready var preview_image: TextureRect = $VBoxContainer/LevelImage

# Level data
var level_data = null

# === SIGNALS ===
signal level_button_pressed(level_data)

func _ready():
	# Connect the invisible button that spans the whole panel
	if select_button:
		select_button.pressed.connect(_on_button_pressed)
		if debug_button:
			print("LevelButton: Connected select button")
	else:
		if debug_button:
			print("LevelButton: Select button not found")

func _on_button_pressed():
	"""Handle button press - emit signal with level data."""
	if debug_button:
		print("LevelButton: Button pressed for: ", level_data.display_name if level_data else "No data")
	
	if level_data:
		level_button_pressed.emit(level_data)

func setup_level(data):
	"""Setup this button with level data."""
	print("level", data)
	level_data = data
	
	# Set title
	if title_label and level_data:
		title_label.text = level_data.display_name
	
	# Set description
	if description_label and level_data:
		description_label.text = level_data.description
	
	# Set preview image
	if preview_image and level_data and level_data.preview_texture:
		preview_image.texture = level_data.preview_texture
	
	# Set button state based on unlock status
	if level_data and select_button:
		select_button.disabled = not level_data.is_unlocked
		if not level_data.is_unlocked:
			modulate = Color(0.5, 0.5, 0.5, 1.0)  # Gray out if locked
	
	if debug_button:
		print("LevelButton: Setup complete for: ", level_data.display_name if level_data else "No data")

# === PUBLIC API ===

func set_locked(locked: bool):
	"""Set the locked state of this level button."""
	if select_button:
		select_button.disabled = locked
	modulate = Color(0.5, 0.5, 0.5, 1.0) if locked else Color.WHITE

func get_level_data():
	"""Get the level data for this button."""
	return level_data

func update_level_info(new_data):
	"""Update the level information."""
	setup_level(new_data)
