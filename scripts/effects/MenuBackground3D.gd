extends Node3D

# === MENU BACKGROUND 3D WITH MOUSE-CONTROLLED TIME DILATION ===
# Separate system from main game TimeManager to avoid conflicts
# Controls time dilation based on mouse motion speed

## === EXPORTED CONFIGURATION ===
@export_group("Mouse Motion Settings")
## Minimum time scale when mouse is moving fast
@export var min_time_scale: float = 0.05
## Maximum time scale when mouse is still
@export var max_time_scale: float = 1.0

@export_group("Rotation Settings")
## Rotation speed on X axis (degrees per second)
@export var rotation_speed_x: float = 10.0
## Rotation speed on Y axis (degrees per second)  
@export var rotation_speed_y: float = 15.0
## Rotation speed on Z axis (degrees per second)
@export var rotation_speed_z: float = 5.0

@onready var mesh_holder = $Node3D

## === RUNTIME STATE ===
var current_time_scale: float = 1.0
var last_mouse_position: Vector2
var mouse_motion_speed: float = 0.0
var is_mouse_moving: bool = false

# Mouse speed rolling average for smooth detection
var mouse_speed_history: Array[float] = []
var averaged_mouse_speed: float = 0.0

# Shader materials for time effects
var shader_materials: Array[ShaderMaterial] = []

# Random rotation system for mesh_holder
var rotation_targets: Array[float] = [0.0, 0.0, 0.0]
var rotation_directions: Array[int] = [1, 1, 1]
var rotation_speeds: Array[float] = [0.0, 0.0, 0.0]
var rotation_progress: Array[float] = [0.0, 0.0, 0.0]

# Total elapsed dilated time accumulator
var total_dilated_time: float = 0.0

func _ready():
	# Initialize mouse position
	last_mouse_position = get_viewport().get_mouse_position()
	
	# Start with normal time scale
	current_time_scale = max_time_scale
	
	# Find and setup shader materials
	_setup_shader_materials()
	
	# Initialize random rotation system for mesh_holder
	_initialize_random_rotation()

func _process(delta: float):
	# Update mouse motion detection
	_update_mouse_motion()
	
	# Update time scale based on mouse motion
	_update_time_scale(delta)
	
	# Apply rotation
	_apply_rotation(delta)
	
	# Apply random rotation to mesh_holder
	_apply_random_rotation(delta)
	
	# Update total dilated time
	_update_total_dilated_time(delta)
	

func _update_mouse_motion():
	"""Mouse motion detection with rolling average."""
	var current_mouse_pos = get_viewport().get_mouse_position()
	var mouse_delta = current_mouse_pos - last_mouse_position
	
	# Raw mouse speed calculation
	mouse_motion_speed = mouse_delta.length()
	
	# Add to rolling average history
	mouse_speed_history.append(mouse_motion_speed)
	
	# Keep only last 16 frames
	if mouse_speed_history.size() > 16:
		mouse_speed_history.pop_front()
	
	# Calculate averaged mouse speed
	averaged_mouse_speed = 0.0
	for speed in mouse_speed_history:
		averaged_mouse_speed += speed
	averaged_mouse_speed /= mouse_speed_history.size()
	
	# Update last position
	last_mouse_position = current_mouse_pos
	
	# Use averaged speed for threshold check - make it more sensitive
	is_mouse_moving = averaged_mouse_speed > 0.1
	

func _update_time_scale(delta: float):
	"""Time scale based on averaged mouse motion - DRAMATIC EFFECT."""
	# Use averaged mouse speed for smooth, dramatic effect
	if averaged_mouse_speed > 0.1:
		# Make the effect SUPER dramatic - multiply averaged speed by 10
		var dramatic_speed = averaged_mouse_speed * 10.0
		# Scale from 0.001 (super slow) to 0.1 (slow) based on dramatic speed
		current_time_scale = lerp(0.001, 0.1, clamp(dramatic_speed / 50.0, 0.0, 1.0))
	else:
		current_time_scale = max_time_scale

func _apply_rotation(delta: float):
	"""Apply perpetual rotation on all 3 axes."""
	# Convert degrees per second to radians per second
	var rotation_delta_x = deg_to_rad(rotation_speed_x) * delta * current_time_scale
	var rotation_delta_y = deg_to_rad(rotation_speed_y) * delta * current_time_scale  
	var rotation_delta_z = deg_to_rad(rotation_speed_z) * delta * current_time_scale
	
	# Apply rotation
	rotation.x += rotation_delta_x
	rotation.y += rotation_delta_y
	rotation.z += rotation_delta_z
	
	# Removed debug rotation output

func _setup_shader_materials():
	"""Find and setup shader materials in the background scene."""
	shader_materials.clear()
	
	# Search for shader materials in all children
	_find_shader_materials_recursive(self)
	
	# Removed debug material output

func _find_shader_materials_recursive(node: Node):
	"""Recursively find all shader materials in the node tree."""
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		if mesh_instance.mesh:
			# Check surface materials
			for i in range(mesh_instance.get_surface_override_material_count()):
				var material = mesh_instance.get_surface_override_material(i)
				if material is ShaderMaterial:
					shader_materials.append(material)
					# Removed debug output
	
	# Recursively search children
	for child in node.get_children():
		_find_shader_materials_recursive(child)


func _update_total_dilated_time(delta: float):
	"""Update total dilated time accumulator."""
	# Calculate how much dilated time to add this frame
	var dilated_time_this_frame = delta * current_time_scale
	
	# Accumulate time based on current time scale
	total_dilated_time += dilated_time_this_frame
	
	# Pass total_dilated_time to all shader materials
	for i in range(shader_materials.size()):
		var shader_mat = shader_materials[i]
		if shader_mat and is_instance_valid(shader_mat):
			shader_mat.set_shader_parameter("total_dilated_time", total_dilated_time)


func _initialize_random_rotation():
	"""Initialize the random rotation system for mesh_holder."""
	if not mesh_holder:
		return
	
	# Initialize random rotation parameters for all axes
	for axis in range(3):
		_set_new_rotation_target(axis)

func _set_new_rotation_target(axis_index: int):
	"""Set a new random rotation target for a given axis."""
	var random_degrees = randf_range(180.0, 540.0)
	rotation_targets[axis_index] = deg_to_rad(random_degrees)
	rotation_directions[axis_index] *= -1 # Flip direction
	rotation_speeds[axis_index] = randf_range(10.0, 30.0) # Random speed for this segment
	rotation_progress[axis_index] = 0.0 # Reset progress

func _apply_random_rotation(delta: float):
	"""Apply random rotation to the mesh_holder using dilated time scale."""
	if not mesh_holder:
		return
	
	for axis_index in range(3):
		var current_target = rotation_targets[axis_index]
		var current_direction = rotation_directions[axis_index]
		var current_speed = rotation_speeds[axis_index]
		
		# Calculate rotation amount for this frame, scaled by current_time_scale
		var rotation_amount = deg_to_rad(current_speed) * delta * current_time_scale * current_direction
		
		# Apply rotation
		match axis_index:
			0: mesh_holder.rotation.x += rotation_amount
			1: mesh_holder.rotation.y += rotation_amount
			2: mesh_holder.rotation.z += rotation_amount
		
		# Update progress (absolute value, as direction is handled by current_direction)
		rotation_progress[axis_index] += abs(rotation_amount)
		
		# Check if target reached
		if rotation_progress[axis_index] >= current_target:
			_set_new_rotation_target(axis_index)
