extends Node

const DEBUG_AFTERIMAGE_MANAGER = false

## Real-time interval between afterimage spawns (seconds)
@export var spawn_interval: float = 0.05
## Time scale threshold - afterimages only spawn when time scale is below this value
@export var time_scale_threshold: float = 0.5

var player_node: Node = null
var spawn_timer: float = 0.0
var color_index: int = 0

func _ready():
	# Connect to TimeManager for time scale changes
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager and time_manager.has_signal("time_scale_changed"):
		time_manager.time_scale_changed.connect(_on_time_scale_changed)

func activate_system(player: Node):
	"""Activate the afterimage system for a player."""
	player_node = player
	color_index = 0  # Reset color progression
	if DEBUG_AFTERIMAGE_MANAGER:
		print("afterimagemanager: Activated for player: ", player.name)
		print("afterimagemanager: Spawn interval: ", spawn_interval)

func deactivate_system():
	"""Deactivate the afterimage system."""
	player_node = null
	print("AfterImageManager: Deactivated")

func _process(delta):
	"""Process real-time spawning."""
	if not player_node:
		if DEBUG_AFTERIMAGE_MANAGER:
			print("afterimagemanager: No player node")
		return
	
	# Check current time scale
	var time_manager = get_node_or_null("/root/TimeManager")
	var current_time_scale = 1.0
	if time_manager:
		current_time_scale = time_manager.custom_time_scale
	
	# Only spawn if time scale is below threshold
	if current_time_scale >= time_scale_threshold:
		if DEBUG_AFTERIMAGE_MANAGER:
			print("afterimagemanager: Time scale (", current_time_scale, ") above threshold (", time_scale_threshold, "), not spawning")
		return
	
	# Track real-time (not affected by time dilation)
	spawn_timer += delta
	
	# Check if we should spawn an afterimage
	if spawn_timer >= spawn_interval:
		spawn_timer = 0.0
		if DEBUG_AFTERIMAGE_MANAGER:
			print("afterimagemanager: Spawn timer reached, spawning afterimage")
		_spawn_afterimage()

func _spawn_afterimage():
	"""Spawn a new afterimage."""
	if not player_node:
		if DEBUG_AFTERIMAGE_MANAGER:
			print("afterimagemanager: No player node for spawning")
		return
	
	if DEBUG_AFTERIMAGE_MANAGER:
		print("afterimagemanager: Getting mesh data from player")
	# Get mesh data from player
	var mesh_data = player_node.capture_afterimage_data()
	if not mesh_data:
		if DEBUG_AFTERIMAGE_MANAGER:
			print("afterimagemanager: No mesh data returned from player")
		return
	
	if DEBUG_AFTERIMAGE_MANAGER:
		print("afterimagemanager: Mesh data received, meshes: ", mesh_data.meshes.size())
	
	# Generate color for this afterimage
	var afterimage_color = _get_color_for_index(color_index)
	color_index += 1
	
	# Create afterimage node
	var afterimage = Node3D.new()
	afterimage.name = "AfterImage_" + str(get_child_count())
	if DEBUG_AFTERIMAGE_MANAGER:
		print("afterimagemanager: Creating afterimage: ", afterimage.name, " with color: ", afterimage_color)
	add_child(afterimage)
	
	# Add the AfterImage script
	var afterimage_script = preload("res://scripts/AfterImage.gd")
	afterimage.set_script(afterimage_script)
	if DEBUG_AFTERIMAGE_MANAGER:
		print("afterimagemanager: Script added to afterimage")
	
	# Set up the afterimage with captured data, color, and player reference
	afterimage.setup_afterimage(mesh_data, afterimage_color, player_node)
	if DEBUG_AFTERIMAGE_MANAGER:
		print("afterimagemanager: Afterimage setup complete")

func _get_color_for_index(index: int) -> Color:
	"""Generate color for afterimage based on index (full spectrum cycle)."""
	# Create a smooth progression through the full color spectrum
	# Green -> Blue -> Purple -> Red -> Orange -> Yellow -> Green
	# Even slower progression: cycle every 240 afterimages (2x slower than before)
	var progress = float(index % 240) / 240.0  # Cycle every 240 afterimages
	
	# Use HSV color space for smooth spectrum transitions
	# Start at green (120 degrees) and rotate through full spectrum
	var hue = fmod(progress * 360.0 + 120.0, 360.0)  # Start at green, full 360 degree rotation
	var saturation = 1.0
	var value = 1.0
	
	# Convert HSV to RGB
	return Color.from_hsv(hue / 360.0, saturation, value, 1.0)

func _on_time_scale_changed(time_scale: float):
	"""Handle time scale changes."""
	# When time scale returns to normal, reset color progression but let afterimages fade naturally
	if time_scale >= 1.0:
		color_index = 0  # Reset color progression
