extends Node3D

const DEBUG_AFTERIMAGE = false

enum AfterImageState {
	INVISIBLE,
	FADING_IN,
	VISIBLE,
	FADING_OUT
}

## Delay before fade-in starts (seconds)
@export var fade_in_delay: float = 0.03
## Duration of fade-in animation (seconds)
@export var fade_in_duration: float = 0.05
## Duration of visible state (seconds)
@export var visible_duration: float = 0.05
## Duration of fade-out animation (seconds)
@export var fade_out_duration: float = 0.25

## Proximity fade settings
@export var proximity_fade_threshold: float = 8.0  # Distance above which proximity has no effect
@export var proximity_fade_min_distance: float = 2.0  # Distance below which afterimage is fully invisible

var mesh_data: Dictionary = {}
var state: AfterImageState = AfterImageState.INVISIBLE
var time_counter: float = 0.0
var mesh_instances: Array[MeshInstance3D] = []
var afterimage_color: Color = Color.WHITE
var player_node: Node = null

func setup_afterimage(data: Dictionary, color: Color = Color.WHITE, player: Node = null):
	"""Set up the afterimage with captured mesh data."""
	if DEBUG_AFTERIMAGE:
		print("afterimage: Setup called with ", data.meshes.size(), " meshes, color: ", color)
	mesh_data = data
	afterimage_color = color
	player_node = player
	state = AfterImageState.INVISIBLE
	time_counter = 0.0
	
	# Enable processing
	set_process(true)
	if DEBUG_AFTERIMAGE:
		print("afterimage: Enabled processing")
	
	# Add skeleton node if present (for animated character)
	if mesh_data.has("skeleton_node") and mesh_data.skeleton_node:
		var skeleton = mesh_data.skeleton_node
		
		# Add to scene tree first
		add_child(skeleton)
		
		# Force visibility on for the skeleton and all children (ignore source visibility)
		skeleton.visible = true
		_force_visibility_recursive(skeleton)
		
		# Set global transform after adding to tree
		# Use the captured skeleton position and rotation (includes any offsets)
		if mesh_data.has("skeleton_position") and mesh_data.has("skeleton_rotation"):
			skeleton.global_position = mesh_data.skeleton_position
			skeleton.global_rotation = mesh_data.skeleton_rotation
		elif player_node:
			# Fallback to player position if skeleton position not captured
			skeleton.global_position = player_node.global_position
			skeleton.global_rotation = player_node.global_rotation + Vector3(0, deg_to_rad(-180), 0)
		
		# Find all MeshInstance3D children and apply afterimage material
		_apply_material_to_skeleton_meshes(skeleton)
		
		if DEBUG_AFTERIMAGE:
			print("afterimage: Added skeleton at position: ", skeleton.global_position, " rotation: ", skeleton.global_rotation)
	
	# Create materials for non-skeleton meshes (like gun)
	for mesh_info in mesh_data.meshes:
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.mesh = mesh_info.mesh
		
		# Create material with assigned color (start invisible)
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(afterimage_color.r, afterimage_color.g, afterimage_color.b, 0.0)  # Start invisible
		material.flags_transparent = true
		material.flags_unshaded = true
		material.flags_do_not_receive_shadows = true
		
		mesh_instance.material_override = material
		mesh_instances.append(mesh_instance)
		
		# Add to scene tree first
		add_child(mesh_instance)
		
		# Set global transform after adding to tree
		mesh_instance.global_transform = mesh_info.transform
		
		if DEBUG_AFTERIMAGE:
			print("afterimage: Added gun mesh at position: ", mesh_instance.global_position)
	
	if DEBUG_AFTERIMAGE:
		print("afterimage: Setup complete, state: ", state, " mesh_instances: ", mesh_instances.size())

func _apply_material_to_skeleton_meshes(node: Node):
	"""Recursively find MeshInstance3D children and apply afterimage material."""
	if node is MeshInstance3D:
		var mesh_instance = node as MeshInstance3D
		
		# Create material with assigned color (start invisible)
		var material = StandardMaterial3D.new()
		material.albedo_color = Color(afterimage_color.r, afterimage_color.g, afterimage_color.b, 0.0)
		material.flags_transparent = true
		material.flags_unshaded = true
		material.flags_do_not_receive_shadows = true
		
		mesh_instance.material_override = material
		mesh_instances.append(mesh_instance)
		
		if DEBUG_AFTERIMAGE:
			print("afterimage: Applied material to skeleton mesh: ", mesh_instance.name)
	
	# Recursively process children
	for child in node.get_children():
		_apply_material_to_skeleton_meshes(child)

func _force_visibility_recursive(node: Node):
	"""Recursively force all nodes to be visible, ignoring source visibility state."""
	if node.has_method("set_visible"):
		node.visible = true
	
	for child in node.get_children():
		_force_visibility_recursive(child)

func _process(delta):
	"""Process afterimage animation using time scale."""
	if DEBUG_AFTERIMAGE:
		print("afterimage: _process called, delta: ", delta, " state: ", state)
	# Get current time scale from TimeManager
	var time_manager = get_node_or_null("/root/TimeManager")
	var time_scale = 1.0
	if time_manager:
		time_scale = time_manager.custom_time_scale
	
	# Add dilated time to counter
	time_counter += delta * time_scale
	if DEBUG_AFTERIMAGE:
		print("afterimage: time_counter: ", time_counter, " time_scale: ", time_scale)
	
	# Handle state transitions
	match state:
		AfterImageState.INVISIBLE:
			if DEBUG_AFTERIMAGE:
				print("afterimage: INVISIBLE state, time_counter: ", time_counter, " fade_in_delay: ", fade_in_delay)
			if time_counter >= fade_in_delay:
				state = AfterImageState.FADING_IN
				time_counter = 0.0
				if DEBUG_AFTERIMAGE:
					print("afterimage: Transitioning to FADING_IN")
		
		AfterImageState.FADING_IN:
			var fade_progress = time_counter / fade_in_duration
			var alpha = lerp(0.0, 0.6, fade_progress)
			_set_alpha(alpha)
			if DEBUG_AFTERIMAGE:
				print("afterimage: FADING_IN, progress: ", fade_progress, " alpha: ", alpha)
			
			if time_counter >= fade_in_duration:
				state = AfterImageState.VISIBLE
				time_counter = 0.0
				if DEBUG_AFTERIMAGE:
					print("afterimage: Transitioning to VISIBLE")
		
		AfterImageState.VISIBLE:
			if DEBUG_AFTERIMAGE:
				print("afterimage: VISIBLE state, time_counter: ", time_counter, " visible_duration: ", visible_duration)
			if time_counter >= visible_duration:
				state = AfterImageState.FADING_OUT
				time_counter = 0.0
				if DEBUG_AFTERIMAGE:
					print("afterimage: Transitioning to FADING_OUT")
		
		AfterImageState.FADING_OUT:
			var fade_progress = time_counter / fade_out_duration
			var alpha = lerp(0.6, 0.0, fade_progress)
			_set_alpha(alpha)
			if DEBUG_AFTERIMAGE:
				print("afterimage: FADING_OUT, progress: ", fade_progress, " alpha: ", alpha)
			
			if time_counter >= fade_out_duration:
				if DEBUG_AFTERIMAGE:
					print("afterimage: Fade-out complete, freeing")
				queue_free()

func _get_proximity_alpha() -> float:
	"""Calculate proximity-based alpha multiplier."""
	if not player_node:
		if DEBUG_AFTERIMAGE:
			print("afterimage: No player node for proximity calculation")
		return 1.0
	
	var distance = global_position.distance_to(player_node.global_position)
	
	if DEBUG_AFTERIMAGE:
		print("afterimage: Distance to player: ", distance, " (threshold: ", proximity_fade_threshold, ", min: ", proximity_fade_min_distance, ")")
	
	# Above threshold: no proximity effect
	if distance >= proximity_fade_threshold:
		if DEBUG_AFTERIMAGE:
			print("afterimage: Above threshold, no proximity effect")
		return 1.0
	
	# Below min distance: fully invisible
	if distance <= proximity_fade_min_distance:
		if DEBUG_AFTERIMAGE:
			print("afterimage: Below min distance, fully invisible")
		return 0.0
	
	# Linear interpolation between min distance and threshold
	var proximity_factor = (distance - proximity_fade_min_distance) / (proximity_fade_threshold - proximity_fade_min_distance)
	if DEBUG_AFTERIMAGE:
		print("afterimage: Proximity factor: ", proximity_factor)
	return proximity_factor

func _set_alpha(alpha: float):
	"""Set alpha for all mesh instances with proximity consideration."""
	if DEBUG_AFTERIMAGE:
		print("afterimage: Setting alpha to: ", alpha, " for ", mesh_instances.size(), " mesh instances")
	
	# Apply proximity-based alpha reduction
	var proximity_alpha = _get_proximity_alpha()
	var final_alpha = alpha * proximity_alpha
	
	if DEBUG_AFTERIMAGE:
		print("afterimage: Final alpha calculation: base=", alpha, " * proximity=", proximity_alpha, " = ", final_alpha)
	
	for mesh_instance in mesh_instances:
		if mesh_instance and mesh_instance.material_override:
			mesh_instance.material_override.albedo_color = Color(afterimage_color.r, afterimage_color.g, afterimage_color.b, final_alpha)
			if DEBUG_AFTERIMAGE:
				print("afterimage: Applied final alpha: ", mesh_instance.material_override.albedo_color.a)
		else:
			if DEBUG_AFTERIMAGE:
				print("afterimage: Mesh instance or material_override not found!")

func time_scale_resumes_despawn():
	"""Clean up the afterimage when time scale returns to normal."""
	queue_free()
