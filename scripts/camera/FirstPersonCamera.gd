extends Camera3D

# Mouse look sensitivity
@export var mouse_sensitivity := 0.1
@export var vertical_look_limit := 89.0

var rotation_x := 0.0
var rotation_y := 0.0

func _ready():
	rotation_x = rotation_degrees.x
	rotation_y = get_parent().rotation_degrees.y
	
	# Load mouse sensitivity from saved settings
	_load_mouse_sensitivity()

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotation_x -= event.relative.y * mouse_sensitivity
		rotation_y -= event.relative.x * mouse_sensitivity
		rotation_x = clamp(rotation_x, -vertical_look_limit, vertical_look_limit)
		rotation_degrees.x = rotation_x
		get_parent().rotation_degrees.y = rotation_y

func add_recoil_offset(vertical_degrees: float):
	"""Add recoil offset to internal rotation tracking so mouse input doesn't snap back."""
	rotation_x += vertical_degrees
	rotation_x = clamp(rotation_x, -vertical_look_limit, vertical_look_limit)

func _load_mouse_sensitivity():
	"""Load mouse sensitivity from saved settings."""
	var settings_save_file = "user://settings.save"
	
	if FileAccess.file_exists(settings_save_file):
		var save_file = FileAccess.open(settings_save_file, FileAccess.READ)
		if save_file:
			var saved_settings = save_file.get_var()
			save_file.close()
			
			if saved_settings.has("mouse_sensitivity"):
				mouse_sensitivity = saved_settings.mouse_sensitivity 
