extends Node

# === BOOT MANAGER ===
# Simple autoload that applies saved settings on game startup

@export_group("Settings")
## Settings save file path
@export var settings_save_file: String = "user://settings.save"

@export_group("Debug")
## Enable debug output
@export var debug_boot: bool = false

func _ready():
	# Apply saved settings immediately on game boot
	_apply_boot_settings()

func _apply_boot_settings():
	"""Apply saved settings on game startup."""
	if debug_boot:
		print("BootManager: Checking for saved settings")
	
	# Load settings if they exist
	if FileAccess.file_exists(settings_save_file):
		var save_file = FileAccess.open(settings_save_file, FileAccess.READ)
		if save_file:
			var saved_settings = save_file.get_var()
			save_file.close()
			
			if debug_boot:
				print("BootManager: Found saved settings: ", saved_settings)
			
			# Apply fullscreen setting immediately
			if saved_settings.has("fullscreen"):
				var should_be_fullscreen = saved_settings.fullscreen
				if debug_boot:
					print("BootManager: Applying fullscreen setting: ", should_be_fullscreen)
				
				if should_be_fullscreen:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
				else:
					DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
				
				if debug_boot:
					print("BootManager: Window mode set to: ", DisplayServer.window_get_mode())
			
			# Apply other settings
			if saved_settings.has("vsync"):
				if saved_settings.vsync:
					DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
				else:
					DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		else:
			if debug_boot:
				print("BootManager: Failed to load settings file")
	else:
		if debug_boot:
			print("BootManager: No saved settings found, using defaults")
