extends Node

# === MENU TIME MANAGER ===
# Separate time management system for menu effects
# Completely independent from main game TimeManager to avoid conflicts
# Coordinates mouse-controlled time dilation for menu backgrounds

## === EXPORTED CONFIGURATION ===
@export_group("Menu Time Settings")
## Enable menu time effects
@export var enable_menu_time_effects: bool = true
## Global menu time scale multiplier (affects all menu time effects)
@export var global_menu_time_multiplier: float = 1.0

@export_group("Debug")
## Enable debug prints for menu time system
@export var debug_menu_time: bool = true

## === RUNTIME STATE ===
var is_active: bool = false
var menu_background: Node3D = null
var current_global_time_scale: float = 1.0

# Signals
signal menu_time_scale_changed(new_scale: float)

func _ready():
	# Set as autoload singleton
	set_process(true)
	
	print("menutimemanager: MenuTimeManager initialized")
	print("menutimemanager: Enable menu time effects: ", enable_menu_time_effects)
	print("menutimemanager: Global multiplier: ", global_menu_time_multiplier)

func _process(delta: float):
	# DISABLED - don't interfere with MenuBackground3D
	return

func _update_global_menu_time():
	"""Update global menu time scale based on background effects."""
	var new_scale = global_menu_time_multiplier
	
	# Get time scale from menu background if available
	if menu_background and menu_background.has_method("get_menu_time_scale"):
		var background_scale = menu_background.get_menu_time_scale()
		new_scale *= background_scale
		if debug_menu_time and Engine.get_process_frames() % 120 == 0:
			print("menutimemanager: Background time scale: ", "%.3f" % background_scale, " Global multiplier: ", "%.3f" % global_menu_time_multiplier)
	else:
		if debug_menu_time and Engine.get_process_frames() % 120 == 0:
			print("menutimemanager: No background or method not found - using global multiplier only: ", "%.3f" % global_menu_time_multiplier)
	
	# Update if changed
	if abs(current_global_time_scale - new_scale) > 0.01:
		var old_scale = current_global_time_scale
		current_global_time_scale = new_scale
		menu_time_scale_changed.emit(current_global_time_scale)
		
		if debug_menu_time:
			print("menutimemanager: Global time scale changed: ", "%.3f" % old_scale, " -> ", "%.3f" % current_global_time_scale)
			print("menutimemanager: Emitting menu_time_scale_changed signal with value: ", "%.3f" % current_global_time_scale)

## === PUBLIC API ===

func activate_for_menu():
	"""Activate menu time manager for menu scenes."""
	print("menutimemanager: Activating for menu")
	
	is_active = true
	
	# Find menu background
	_find_menu_background()
	
	print("menutimemanager: Active - background found: ", menu_background != null)
	if menu_background:
		print("menutimemanager: Background node name: ", menu_background.name, " Type: ", menu_background.get_class())

func deactivate_for_gameplay():
	"""Deactivate menu time manager when entering gameplay."""
	print("menutimemanager: Deactivating for gameplay")
	
	is_active = false
	menu_background = null
	current_global_time_scale = 1.0
	menu_time_scale_changed.emit(current_global_time_scale)

func _find_menu_background():
	"""Find the menu background node."""
	print("menutimemanager: Searching for menu background...")
	
	menu_background = get_tree().get_first_node_in_group("menu_background")
	print("menutimemanager: Group 'menu_background' search result: ", menu_background != null)
	
	if not menu_background:
		# Try to find Background3D node in current scene
		menu_background = get_tree().get_first_node_in_group("Background3D")
		print("menutimemanager: Group 'Background3D' search result: ", menu_background != null)
	
	if not menu_background:
		# Try to find by name
		menu_background = get_node_or_null("/root/MainMenu/Background3D")
		print("menutimemanager: Direct path search result: ", menu_background != null)
	
	if menu_background:
		print("menutimemanager: Found menu background: ", menu_background.name, " at path: ", menu_background.get_path())
	else:
		print("menutimemanager: WARNING - No menu background found!")
		print("menutimemanager: Available groups: ", get_tree().get_nodes_in_group("menu_background"))
		print("menutimemanager: Available Background3D groups: ", get_tree().get_nodes_in_group("Background3D"))

func get_menu_time_scale() -> float:
	"""Get current menu time scale."""
	return current_global_time_scale

func get_effective_delta(delta: float) -> float:
	"""Get delta scaled by menu time system."""
	if not is_active or not enable_menu_time_effects:
		return delta
	return delta * current_global_time_scale

func is_menu_time_active() -> bool:
	"""Check if menu time system is active."""
	return is_active and enable_menu_time_effects

func set_global_multiplier(multiplier: float):
	"""Set global time scale multiplier for menu effects."""
	global_menu_time_multiplier = clamp(multiplier, 0.0, 2.0)
	
	if debug_menu_time:
		print("MenuTimeManager: Global multiplier set to: ", global_menu_time_multiplier)

func force_menu_time_scale(scale: float):
	"""Force menu time scale for testing."""
	current_global_time_scale = clamp(scale, 0.0, 2.0)
	menu_time_scale_changed.emit(current_global_time_scale)
	
	if debug_menu_time:
		print("MenuTimeManager: Time scale forced to: ", current_global_time_scale)

func reset_menu_time():
	"""Reset menu time to normal."""
	current_global_time_scale = global_menu_time_multiplier
	menu_time_scale_changed.emit(current_global_time_scale)
	
	if debug_menu_time:
		print("MenuTimeManager: Time scale reset to: ", current_global_time_scale)
