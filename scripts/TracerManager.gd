extends Node

# === BULLET TRACER MANAGER ===
# Autoload singleton that manages visual tracers for bullets
# Automatically creates tracer container and handles all tracer logic

# === CONFIGURATION ===
@export var tracer_enabled: bool = true
@export var tracer_length_seconds: float = 0.4  # How long the trail lasts
@export var tracer_segment_count: int = 100  # Number of trail segments (MUCH denser!)
@export var tracer_update_rate: float = 0.003  # How often to add new segments (seconds) (SUPER fast!)

# === TRACER VISUAL SETTINGS ===
@export var tracer_thickness: float = 0.05  # Bigger spheres for more overlap
@export var tracer_color: Color = Color.YELLOW
@export var tracer_emission_energy: float = 3.0  # Brighter for more visibility
@export var use_line_segments: bool = true  # Use continuous lines instead of spheres

# === STATE ===
var tracer_container: Node3D = null
var active_tracers: Dictionary = {}  # bullet_id -> tracer_data
var next_bullet_id: int = 0

# === TRACER DATA STRUCTURE ===
class TracerData:
	var bullet: RigidBody3D
	var trail_segments: Array[MeshInstance3D] = []
	var last_update_time: float = 0.0
	var segment_positions: Array[Vector3] = []
	var is_active: bool = true
	
	func _init(bullet_ref: RigidBody3D):
		bullet = bullet_ref

func _ready():
	print("TracerManager initialized")
	# Create tracer container when main scene is ready
	call_deferred("_setup_tracer_container")

func _setup_tracer_container():
	"""Create tracer container in main scene."""
	var main_scene = get_tree().current_scene
	if main_scene:
		tracer_container = Node3D.new()
		tracer_container.name = "TracerContainer"
		main_scene.add_child(tracer_container)
		print("TracerContainer created in main scene")
	else:
		print("WARNING: Could not find main scene for TracerContainer!")

func _process(delta: float):
	"""Update all active tracers."""
	if not tracer_enabled or not tracer_container:
		return
	
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Update each active tracer
	for bullet_id in active_tracers.keys():
		var tracer_data = active_tracers[bullet_id]
		_update_tracer(tracer_data, delta, current_time)
	
	# Clean up invalid bullets
	_cleanup_invalid_tracers()

func register_bullet(bullet: RigidBody3D) -> int:
	"""Register a bullet for tracer tracking. Returns bullet ID."""
	if not tracer_enabled or not bullet:
		return -1
	
	var bullet_id = next_bullet_id
	next_bullet_id += 1
	
	var tracer_data = TracerData.new(bullet)
	active_tracers[bullet_id] = tracer_data
	
	print("Registered bullet for tracer tracking: ID ", bullet_id)
	return bullet_id

func unregister_bullet(bullet_id: int):
	"""Unregister a bullet and clean up its tracer."""
	if not active_tracers.has(bullet_id):
		return
	
	var tracer_data = active_tracers[bullet_id]
	_cleanup_tracer_visuals(tracer_data)
	active_tracers.erase(bullet_id)
	
	print("Unregistered bullet tracer: ID ", bullet_id)

func _update_tracer(tracer_data: TracerData, delta: float, current_time: float):
	"""Update a single bullet's tracer."""
	if not is_instance_valid(tracer_data.bullet):
		tracer_data.is_active = false
		return
	
	# Check if bullet has been fired (has_been_fired property)
	if not tracer_data.bullet.get("has_been_fired"):
		return  # Don't show tracer until bullet is fired
	
	# Only update at specified intervals
	if current_time - tracer_data.last_update_time < tracer_update_rate:
		return
	
	tracer_data.last_update_time = current_time
	
	# Get bullet position using the raycast nodes
	var bullet_pos = tracer_data.bullet.global_position
	var bullet_rot = tracer_data.bullet.global_rotation
	var forward_raycast = tracer_data.bullet.get_node_or_null("ForwardRaycast")
	var backward_raycast = tracer_data.bullet.get_node_or_null("BackwardRaycast")
	
	if forward_raycast and backward_raycast:
		# Use raycast to determine tracer start/end points
		var forward_point = forward_raycast.global_position + forward_raycast.global_transform.basis.z * forward_raycast.target_position.z
		var backward_point = backward_raycast.global_position + backward_raycast.global_transform.basis.z * backward_raycast.target_position.z
		
		# Add new segment at bullet's current position
		_add_tracer_segment(tracer_data, bullet_pos, bullet_rot)
	else:
		# Fallback: use bullet position directly
		_add_tracer_segment(tracer_data, bullet_pos, bullet_rot)
	
	# Remove old segments
	_trim_old_segments(tracer_data)

func _add_tracer_segment(tracer_data: TracerData, position: Vector3, rotation):
	"""Add a new tracer segment at the given position."""
	if not tracer_container:
		return
		
	# Add position to history first
	tracer_data.segment_positions.append(position)
	
	# Create visual segment
	if use_line_segments and tracer_data.segment_positions.size() >= 2:
		# Create line segment from previous position to current position
		var prev_pos = tracer_data.segment_positions[tracer_data.segment_positions.size() - 2]
		var segment = _create_line_segment(prev_pos, position)
		tracer_container.add_child(segment)
		
		# Now that it's in the tree, set position and orientation
		var center_pos = (prev_pos + position) / 2.0
		segment.global_position = center_pos
		
		var line_direction = (position - prev_pos).normalized()
		if line_direction.length() > 0.001:
			# Create proper orientation transform for cylinder
			var up = Vector3.UP
			if abs(line_direction.dot(up)) > 0.99:
				up = Vector3.FORWARD
			
			# Create basis where Y-axis points along line direction
			var new_y = line_direction
			var new_x = up.cross(new_y).normalized()
			var new_z = new_x.cross(new_y).normalized()
			
			segment.transform.basis = Basis(new_x, new_y, new_z)
		
		tracer_data.trail_segments.append(segment)
		_animate_segment_fadeout(segment)
	else:
		# Create sphere segment (fallback or first segment)
		var segment = _create_sphere_segment(position)
		tracer_container.add_child(segment)
		
		# Now that it's in the tree, set position
		segment.global_position = position
		
		tracer_data.trail_segments.append(segment)
		_animate_segment_fadeout(segment)

	

func _create_sphere_segment(position: Vector3) -> MeshInstance3D:
	"""Create a sphere segment for tracer."""
	var segment = MeshInstance3D.new()
	
	# Create small sphere mesh for segment
	var sphere = SphereMesh.new()
	sphere.radius = tracer_thickness
	sphere.height = tracer_thickness * 2
	segment.mesh = sphere
	
	# Position will be set after adding to tree
	
	# Create glowing material
	var material = StandardMaterial3D.new()
	material.albedo_color = tracer_color
	material.emission_enabled = true
	material.emission = tracer_color
	material.emission_energy = tracer_emission_energy
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	segment.material_override = material

	return segment

func _create_line_segment(start_pos: Vector3, end_pos: Vector3) -> MeshInstance3D:
	"""Create a line segment between two points."""
	var segment = MeshInstance3D.new()
	
	# Create cylinder mesh for line
	var cylinder = CylinderMesh.new()
	var distance = start_pos.distance_to(end_pos)
	cylinder.height = distance
	cylinder.top_radius = tracer_thickness * 0.7  # Slightly thinner than spheres
	cylinder.bottom_radius = tracer_thickness * 0.7
	segment.mesh = cylinder
	
	# Position and orientation will be set after adding to tree
	
	# Create glowing material
	var material = StandardMaterial3D.new()
	material.albedo_color = tracer_color
	material.emission_enabled = true
	material.emission = tracer_color
	material.emission_energy = tracer_emission_energy
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	segment.material_override = material
		
	return segment

func _animate_segment_fadeout(segment: MeshInstance3D):
	"""Animate a tracer segment to fade out over time."""
	if not is_instance_valid(segment):
		return
	
	var tween = get_tree().create_tween()
	
	# Fade out over tracer lifetime - no callback needed, cleanup handled by segment trimming
	tween.tween_property(segment, "scale", Vector3.ZERO, tracer_length_seconds)

func _trim_old_segments(tracer_data: TracerData):
	"""Remove segments that exceed the maximum count."""
	# Trim visual segments
	while tracer_data.trail_segments.size() > tracer_segment_count:
		var old_segment = tracer_data.trail_segments.pop_front()
		if is_instance_valid(old_segment):
			old_segment.queue_free()
	
	# Trim position history (keep a few extra for line segment generation)
	while tracer_data.segment_positions.size() > tracer_segment_count + 5:
		tracer_data.segment_positions.pop_front()

func _cleanup_tracer_visuals(tracer_data: TracerData):
	"""Clean up all visual elements for a tracer."""
	for segment in tracer_data.trail_segments:
		if is_instance_valid(segment):
			segment.queue_free()
	
	tracer_data.trail_segments.clear()
	tracer_data.segment_positions.clear()

func _cleanup_invalid_tracers():
	"""Remove tracers for bullets that no longer exist."""
	var to_remove: Array[int] = []
	
	for bullet_id in active_tracers.keys():
		var tracer_data = active_tracers[bullet_id]
		if not tracer_data.is_active or not is_instance_valid(tracer_data.bullet):
			to_remove.append(bullet_id)
	
	for bullet_id in to_remove:
		unregister_bullet(bullet_id)

# === PUBLIC API ===

func set_tracer_enabled(enabled: bool):
	"""Enable or disable tracer system."""
	tracer_enabled = enabled
	if not enabled:
		_clear_all_tracers()

func set_tracer_color(color: Color):
	"""Change tracer color."""
	tracer_color = color

func set_tracer_thickness(thickness: float):
	"""Change tracer thickness."""
	tracer_thickness = thickness

func _clear_all_tracers():
	"""Clear all active tracers."""
	for bullet_id in active_tracers.keys():
		unregister_bullet(bullet_id)

# === DEBUG ===

func print_tracer_state():
	"""Debug function to print current tracer state."""
	print("=== TRACER MANAGER STATE ===")
	print("Enabled: ", tracer_enabled)
	print("Active tracers: ", active_tracers.size())
	print("Container valid: ", is_instance_valid(tracer_container))
	print("============================")
