extends Control

# === ANALYTICS MENU MANAGER ===
# Handles analytics menu functionality and navigation
# Follows the same pattern as MenuManager and DeathScreen

## === EXPORTED CONFIGURATION ===
@export_group("Scene Paths")
## Path to analytics menu scene
@export var analytics_menu_scene: String = "res://scenes/ui/AnalyticsMenu.tscn"

@export_group("Debug Settings")
## Enable debug output for menu events
@export var debug_menu_events: bool = false
## Enable debug output for scene transitions
@export var debug_transitions: bool = false

## === RUNTIME STATE ===
# Analytics menu instance
var analytics_menu_instance: Control = null

## === SIGNALS ===
signal analytics_menu_opened()
signal analytics_menu_closed()

func _ready():
	if debug_menu_events:
		print("AnalyticsMenuManager: Initialized")

func open_analytics_menu():
	"""Open the analytics menu."""
	if analytics_menu_instance:
		if debug_menu_events:
			print("AnalyticsMenuManager: Analytics menu already open")
		return
	
	if debug_menu_events:
		print("AnalyticsMenuManager: Opening analytics menu")
	
	# Load analytics menu if not already loaded
	if not analytics_menu_instance:
		_load_analytics_menu()
	
	# Show the menu
	if analytics_menu_instance:
		analytics_menu_instance.visible = true
		analytics_menu_opened.emit()

func close_analytics_menu():
	"""Close the analytics menu."""
	if not analytics_menu_instance:
		if debug_menu_events:
			print("AnalyticsMenuManager: Analytics menu not open")
		return
	
	if debug_menu_events:
		print("AnalyticsMenuManager: Closing analytics menu")
	
	# Hide the menu
	if analytics_menu_instance:
		analytics_menu_instance.visible = false
		analytics_menu_closed.emit()

func _load_analytics_menu():
	"""Load the analytics menu scene."""
	var menu_scene = load(analytics_menu_scene)
	if menu_scene:
		analytics_menu_instance = menu_scene.instantiate()
		get_tree().root.add_child(analytics_menu_instance)
		# Start hidden
		analytics_menu_instance.visible = false
		
		if debug_transitions:
			print("AnalyticsMenuManager: Analytics menu loaded")
	else:
		if debug_transitions:
			print("AnalyticsMenuManager: Failed to load analytics menu scene: ", analytics_menu_scene)

func cleanup_analytics_menu():
	"""Clean up analytics menu instance (for scene changes)."""
	if analytics_menu_instance:
		analytics_menu_instance.queue_free()
		analytics_menu_instance = null
		if debug_transitions:
			print("AnalyticsMenuManager: Analytics menu cleaned up")

## === PUBLIC API ===

func is_analytics_menu_open() -> bool:
	"""Check if analytics menu is currently open."""
	return analytics_menu_instance != null and analytics_menu_instance.visible

func toggle_analytics_menu():
	"""Toggle analytics menu open/closed state."""
	if is_analytics_menu_open():
		close_analytics_menu()
	else:
		open_analytics_menu()
