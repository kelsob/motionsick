extends Control

# === OPTIONS MENU MANAGER ===
# Handles game settings and options persistence

## === EXPORTED CONFIGURATION ===

@export_group("Scene Paths")
## Path to main menu scene
@export var main_menu_scene: String = "res://scenes/ui/MainMenu.tscn"

@export_group("Default Settings")
## Default master volume (0.0 to 1.0)
@export var default_master_volume: float = 0.8
## Default SFX volume (0.0 to 1.0)
@export var default_sfx_volume: float = 0.8
## Default fullscreen state
@export var default_fullscreen: bool = false
## Default VSync state
@export var default_vsync: bool = true
## Default mouse sensitivity (will be scaled to camera range)
@export var default_mouse_sensitivity: float = 0.5

@export_group("Audio Bus Names")
## Master audio bus name
@export var master_bus_name: String = "Master"
## SFX audio bus name
@export var sfx_bus_name: String = "SFX"

@export_group("Save System")
## Settings save file path
@export var settings_save_file: String = "user://settings.save"

@export_group("Animation Settings")
## Enable options menu animations
@export var enable_animations: bool = true
## Fade transition duration
@export var fade_duration: float = 0.3

@export_group("Debug Settings")
## Enable debug output for settings changes
@export var debug_settings: bool = true
## Enable debug output for save/load operations
@export var debug_save_load: bool = true
## Enable debug output for scene transitions
@export var debug_transitions: bool = false

## === RUNTIME STATE ===
# UI references - lazy loaded to avoid timing issues
var _master_volume_slider: HSlider
var _sfx_volume_slider: HSlider
var _fullscreen_checkbox: CheckBox
var _vsync_checkbox: CheckBox
var _mouse_sensitivity_slider: HSlider
var _back_button: Button

signal sfx_volume_changed(volume: float)
signal music_volume_changed(volume: float) 
signal ui_volume_changed(volume: float)

# Lazy-loaded getters for UI elements
var master_volume_slider: HSlider:
	get:
		if not _master_volume_slider:
			_master_volume_slider = get_node_or_null("OptionsContainer/SettingsContainer/AudioSection/MasterVolumeSlider")
		return _master_volume_slider

var sfx_volume_slider: HSlider:
	get:
		if not _sfx_volume_slider:
			_sfx_volume_slider = get_node_or_null("OptionsContainer/SettingsContainer/AudioSection/SFXVolumeSlider")
		return _sfx_volume_slider

var fullscreen_checkbox: CheckBox:
	get:
		if not _fullscreen_checkbox:
			_fullscreen_checkbox = get_node_or_null("OptionsContainer/SettingsContainer/GraphicsSection/FullscreenCheckbox")
		return _fullscreen_checkbox

var vsync_checkbox: CheckBox:
	get:
		if not _vsync_checkbox:
			_vsync_checkbox = get_node_or_null("OptionsContainer/SettingsContainer/GraphicsSection/VSyncCheckbox")
		return _vsync_checkbox

var mouse_sensitivity_slider: HSlider:
	get:
		if not _mouse_sensitivity_slider:
			_mouse_sensitivity_slider = get_node_or_null("OptionsContainer/SettingsContainer/ControlsSection/MouseSensitivitySlider")
		return _mouse_sensitivity_slider

var back_button: Button:
	get:
		if not _back_button:
			_back_button = get_node_or_null("OptionsContainer/BackButton")
		return _back_button

# Current settings
var current_settings: Dictionary = {}

# === SIGNALS ===
signal settings_changed(setting_name: String, value)
signal settings_saved()
signal settings_loaded()

func _ready():
	# Setup UI connections
	_setup_ui()
	
	# Load settings
	_load_settings()
	
	# Apply loaded settings
	_apply_settings()
	
	# Setup mouse mode
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	if debug_settings:
		print("OptionsManager: Options menu ready")

func _load_settings():
	"""Load settings from save file."""
	# Set defaults first
	current_settings = {
		"master_volume": default_master_volume,
		"sfx_volume": default_sfx_volume,
		"fullscreen": default_fullscreen,
		"vsync": default_vsync,
		"mouse_sensitivity": default_mouse_sensitivity
	}
	
	if debug_save_load:
		print("OptionsManager: Default settings: ", current_settings)
	
	# Try to load saved settings
	if FileAccess.file_exists(settings_save_file):
		var save_file = FileAccess.open(settings_save_file, FileAccess.READ)
		if save_file:
			var loaded_settings = save_file.get_var()
			save_file.close()
			
			if debug_save_load:
				print("OptionsManager: Loaded settings from file: ", loaded_settings)
			
			# Merge loaded settings with defaults
			for key in loaded_settings:
				current_settings[key] = loaded_settings[key]
			
			if debug_save_load:
				print("OptionsManager: Final merged settings: ", current_settings)
		else:
			if debug_save_load:
				print("OptionsManager: Failed to load settings file")
	else:
		if debug_save_load:
			print("OptionsManager: No settings file found, using defaults")
	
	settings_loaded.emit()

func _apply_settings():
	"""Apply current settings to the game and UI."""
	# Update UI elements WITHOUT triggering signals (set_value_no_signal doesn't exist in Godot)
	# So we manually disconnect/reconnect to avoid triggering callbacks
	
	if master_volume_slider:
		if master_volume_slider.value_changed.is_connected(_on_master_volume_changed):
			master_volume_slider.value_changed.disconnect(_on_master_volume_changed)
		master_volume_slider.value = current_settings.master_volume
		master_volume_slider.value_changed.connect(_on_master_volume_changed)
	
	if sfx_volume_slider:
		if sfx_volume_slider.value_changed.is_connected(_on_sfx_volume_changed):
			sfx_volume_slider.value_changed.disconnect(_on_sfx_volume_changed)
		sfx_volume_slider.value = current_settings.sfx_volume
		sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	
	if fullscreen_checkbox:
		fullscreen_checkbox.button_pressed = current_settings.fullscreen
	if vsync_checkbox:
		vsync_checkbox.button_pressed = current_settings.vsync
	
	if mouse_sensitivity_slider:
		if mouse_sensitivity_slider.value_changed.is_connected(_on_mouse_sensitivity_changed):
			mouse_sensitivity_slider.value_changed.disconnect(_on_mouse_sensitivity_changed)
		mouse_sensitivity_slider.value = current_settings.mouse_sensitivity
		mouse_sensitivity_slider.value_changed.connect(_on_mouse_sensitivity_changed)
	
	# DON'T call _apply_audio_settings() here - AudioManager already loaded from file!
	# Only apply graphics and input
	_apply_graphics_settings()
	_apply_input_settings()

func _apply_audio_settings():
	"""Apply audio settings to the game."""
	# Use AudioManager to set volumes (it handles bus conversion properly)
	if AudioManager:
		AudioManager.set_sfx_volume(current_settings.sfx_volume)
		
		if debug_settings:
			print("OptionsManager: Applied audio settings via AudioManager")
			print("  SFX volume: ", current_settings.sfx_volume)
	else:
		# Fallback: Set bus volume directly if AudioManager not available
		var master_bus_idx = AudioServer.get_bus_index(master_bus_name)
		if master_bus_idx >= 0:
			var volume_db = linear_to_db(current_settings.master_volume)
			AudioServer.set_bus_volume_db(master_bus_idx, volume_db)
		
		var sfx_bus_idx = AudioServer.get_bus_index(sfx_bus_name)
		if sfx_bus_idx >= 0:
			var volume_db = linear_to_db(current_settings.sfx_volume)
			AudioServer.set_bus_volume_db(sfx_bus_idx, volume_db)

func _apply_graphics_settings():
	"""Apply graphics settings to the game."""
	if debug_settings:
		print("OptionsManager: Applying graphics settings")
		print("  Fullscreen setting: ", current_settings.fullscreen)
		print("  Current window mode: ", DisplayServer.window_get_mode())
	
	# Simple fullscreen toggle
	if current_settings.fullscreen:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	
	if debug_settings:
		print("  Window mode after change: ", DisplayServer.window_get_mode())
	
	# Set VSync
	if current_settings.vsync:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _apply_input_settings():
	"""Apply input settings to the game."""
	# Mouse sensitivity will be handled by camera script
	# We'll emit a signal that camera can listen to
	settings_changed.emit("mouse_sensitivity", current_settings.mouse_sensitivity)

# === UI EVENT HANDLERS ===

func _on_master_volume_changed(value: float):
	"""Handle master volume slider change."""
	print("OptionsManager: _on_master_volume_changed CALLED with value: ", value)
	
	current_settings.master_volume = value
	
	# Apply master volume to AudioManager (affects all categories)
	print("OptionsManager: Calling AudioManager.set_master_volume(", value, ")")
	if AudioManager:
		AudioManager.set_master_volume(value)
		print("OptionsManager: Master volume applied")
	else:
		print("OptionsManager: ERROR - AudioManager is null!")
	
	_save_settings()
	
	if debug_settings:
		print("OptionsManager: Master volume changed to: ", "%.2f" % value)

func _on_sfx_volume_changed(value: float):
	"""Handle SFX volume slider change."""
	print("OptionsManager: _on_sfx_volume_changed CALLED with value: ", value)
	
	current_settings.sfx_volume = value
	
	print("OptionsManager: Calling AudioManager.set_sfx_volume(", value, ")")
	if AudioManager:
		AudioManager.set_sfx_volume(value)
		print("OptionsManager: AudioManager.set_sfx_volume() completed")
	else:
		print("OptionsManager: ERROR - AudioManager is null!")
	
	_save_settings()
	
	if debug_settings:
		print("OptionsManager: SFX volume changed to: ", "%.2f" % value)

func _on_fullscreen_toggled(pressed: bool):
	"""Handle fullscreen checkbox toggle."""
	if debug_settings:
		print("OptionsManager: Fullscreen checkbox toggled to: ", pressed)
		print("OptionsManager: Previous fullscreen setting: ", current_settings.fullscreen)
	
	current_settings.fullscreen = pressed
	_apply_graphics_settings()
	_save_settings()
	
	if debug_settings:
		print("OptionsManager: Fullscreen setting updated and saved")

func _on_vsync_toggled(pressed: bool):
	"""Handle VSync checkbox toggle."""
	current_settings.vsync = pressed
	_apply_graphics_settings()
	_save_settings()
	
	if debug_settings:
		print("OptionsManager: VSync changed to: ", pressed)

func _on_mouse_sensitivity_changed(value: float):
	"""Handle mouse sensitivity slider change."""
	current_settings.mouse_sensitivity = value
	_apply_input_settings()
	_save_settings()
	
	if debug_settings:
		print("OptionsManager: Mouse sensitivity changed to: ", "%.2f" % value)

func _on_back_pressed():
	"""Handle back button press."""
	if debug_transitions:
		print("OptionsManager: Returning to main menu")
	
	_transition_to_main_menu()

func _transition_to_main_menu():
	"""Transition back to main menu immediately."""
	# Change scene immediately - no fade animations
	var error = get_tree().change_scene_to_file(main_menu_scene)
	if error != OK:
		if debug_transitions:
			print("OptionsManager: Failed to load main menu: ", error)

func _save_settings():
	"""Save current settings to file."""
	if debug_save_load:
		print("OptionsManager: Saving settings to: ", settings_save_file)
		print("OptionsManager: Settings to save: ", current_settings)
	
	var save_file = FileAccess.open(settings_save_file, FileAccess.WRITE)
	if save_file:
		save_file.store_var(current_settings)
		save_file.close()
		settings_saved.emit()
		
		if debug_save_load:
			print("OptionsManager: Settings saved successfully")
	else:
		if debug_save_load:
			print("OptionsManager: Failed to save settings - could not open file")

# === PUBLIC API ===

func get_setting(setting_name: String):
	"""Get a specific setting value."""
	return current_settings.get(setting_name)

func set_setting(setting_name: String, value):
	"""Set a specific setting value and apply it."""
	current_settings[setting_name] = value
	_apply_settings()
	_save_settings()
	settings_changed.emit(setting_name, value)

func reset_to_defaults():
	"""Reset all settings to default values."""
	current_settings = {
		"master_volume": default_master_volume,
		"sfx_volume": default_sfx_volume,
		"fullscreen": default_fullscreen,
		"vsync": default_vsync,
		"mouse_sensitivity": default_mouse_sensitivity
	}
	_apply_settings()
	_save_settings()
	
	if debug_settings:
		print("OptionsManager: Settings reset to defaults")

func get_all_settings() -> Dictionary:
	"""Get all current settings."""
	return current_settings.duplicate()

# === DEBUG ===

func print_settings_status():
	"""Debug function to print current settings."""
	print("\n=== OPTIONS MANAGER STATUS ===")
	print("Current settings:")
	for key in current_settings:
		print("  ", key, ": ", current_settings[key])
	print("UI connections:")
	print("  Master volume slider: ", "Connected" if master_volume_slider else "Missing")
	print("  SFX volume slider: ", "Connected" if sfx_volume_slider else "Missing")
	print("  Fullscreen checkbox: ", "Connected" if fullscreen_checkbox else "Missing")
	print("  VSync checkbox: ", "Connected" if vsync_checkbox else "Missing")
	print("  Mouse sensitivity slider: ", "Connected" if mouse_sensitivity_slider else "Missing")
	print("  Back button: ", "Connected" if back_button else "Missing")
	print("===============================\n")

func _setup_ui():
	"""Connect UI elements."""
	# Configure slider ranges
	if master_volume_slider:
		master_volume_slider.min_value = 0.0
		master_volume_slider.max_value = 1.0
		master_volume_slider.step = 0.05
	
	if sfx_volume_slider:
		sfx_volume_slider.min_value = 0.0
		sfx_volume_slider.max_value = 1.0
		sfx_volume_slider.step = 0.05
	
	if mouse_sensitivity_slider:
		mouse_sensitivity_slider.min_value = 0.01
		mouse_sensitivity_slider.max_value = 1.0
		mouse_sensitivity_slider.step = 0.05
	
	# Connect signals
	if master_volume_slider:
		master_volume_slider.value_changed.connect(_on_master_volume_changed)
	if sfx_volume_slider:
		sfx_volume_slider.value_changed.connect(_on_sfx_volume_changed)
	if fullscreen_checkbox:
		fullscreen_checkbox.toggled.connect(_on_fullscreen_toggled)
	if vsync_checkbox:
		vsync_checkbox.toggled.connect(_on_vsync_toggled)
	if mouse_sensitivity_slider:
		mouse_sensitivity_slider.value_changed.connect(_on_mouse_sensitivity_changed)
	if back_button:
		back_button.pressed.connect(_on_back_pressed)
