extends Node

# === BULLET TRACER MANAGER ===
# Autoload singleton that manages visual tracers for bullets
# Automatically creates tracer container and handles all tracer logic

# === CONFIGURATION ===
@export var tracer_enabled: bool = true
@export var tracer_length_seconds: float = 0.6  # How long the trail lasts (increased by 50%)
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

# === TIME SYSTEM INTEGRATION ===
var time_manager: Node = null

# === TRACER DATA STRUCTURE ===
class TracerData:
	var bullet: RigidBody3D
	var trail_segments: Array[MeshInstance3D] = []
	var segment_ages: Array[float] = []  # Track age of each segment for manual fadeout
	var last_update_time: float = 0.0
	var segment_positions: Array[Vector3] = []
	var is_active: bool = true
	var bullet_destroyed: bool = false  # Track if bullet is gone but tracers should persist
	
	func _init(bullet_ref: RigidBody3D):
		bullet = bullet_ref

func _ready():
	print("TracerManager initialized")
	# Connect to TimeManager
	time_manager = get_node("/root/TimeManager")
	if time_manager:
		print("TracerManager connected to TimeManager")
	else:
		print("WARNING: TracerManager can't find TimeManager!")
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
	
	# Use time-adjusted delta - tracers should respect time scale
	var time_adjusted_delta = delta
	if time_manager:
		time_adjusted_delta = time_manager.get_effective_delta(delta, 0.0)  # No time resistance for tracers
	
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Update each active tracer with time-adjusted delta
	for bullet_id in active_tracers.keys():
		var tracer_data = active_tracers[bullet_id]
		_update_tracer(tracer_data, time_adjusted_delta, current_time)
		_update_segment_fadeout(tracer_data, time_adjusted_delta)
	
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
	
	# Bullet registered for tracer tracking
	return bullet_id

func unregister_bullet(bullet_id: int):
	"""Unregister a bullet but let tracers fade out naturally."""
	if not active_tracers.has(bullet_id):
		return
	
	var tracer_data = active_tracers[bullet_id]
	
	# Mark bullet as destroyed but don't clean up visuals immediately
	tracer_data.bullet_destroyed = true
	tracer_data.bullet = null  # Clear reference to help with memory
	
	# Let the tracer fade out naturally - cleanup will happen in _cleanup_invalid_tracers()
	# when all segments are fully faded
	
	# Bullet tracer marked for natural fadeout

func _update_tracer(tracer_data: TracerData, time_adjusted_delta: float, current_time: float):
	"""Update a single bullet's tracer."""
	# Check if bullet still exists
	if not is_instance_valid(tracer_data.bullet):
		tracer_data.bullet_destroyed = true
		# Don't return here - let existing segments continue fading
	
	# If bullet is destroyed, skip creating new segments but continue fadeout
	if tracer_data.bullet_destroyed:
		return
	
	# Check if bullet has been fired (has_been_fired property)
	if not tracer_data.bullet.get("has_been_fired"):
		return  # Don't show tracer until bullet is fired
	
	# Use time-adjusted delta for update intervals instead of real time
	tracer_data.last_update_time += time_adjusted_delta
	if tracer_data.last_update_time < tracer_update_rate:
		return
	
	# Reset interval timer
	tracer_data.last_update_time = 0.0
	
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
		tracer_data.segment_ages.append(0.0)  # Start with age 0
	else:
		# Create sphere segment (fallback or first segment)
		var segment = _create_sphere_segment(position)
		tracer_container.add_child(segment)
		
		# Now that it's in the tree, set position
		segment.global_position = position
		
		tracer_data.trail_segments.append(segment)
		tracer_data.segment_ages.append(0.0)  # Start with age 0

	

func _create_sphere_segment(position: Vector3) -> MeshInstance3D:
	"""Create a sphere segment for tracer."""
	var segment = MeshInstance3D.new()
	
	# Create small sphere mesh for segment
	var sphere = SphereMesh.new()
	sphere.radius = tracer_thickness * 4
	sphere.height = tracer_thickness * 4
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
	cylinder.height = distance * 1.75
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

func _update_segment_fadeout(tracer_data: TracerData, time_adjusted_delta: float):
	"""Manually update segment fadeout using time-adjusted aging."""
	var segments_to_remove: Array[int] = []
	
	for i in range(tracer_data.trail_segments.size()):
		if i >= tracer_data.segment_ages.size():
			continue
			
		# Age the segment using time-adjusted delta
		tracer_data.segment_ages[i] += time_adjusted_delta
		
		# Calculate fade progress (0.0 = new, 1.0 = fully faded)
		var fade_progress = tracer_data.segment_ages[i] / tracer_length_seconds
		
		# Apply scaling based on fade progress
		var segment = tracer_data.trail_segments[i]
		if is_instance_valid(segment):
			if fade_progress >= 1.0:
				# Segment is fully faded, mark for removal
				segments_to_remove.append(i)
				segment.queue_free()
			else:
				# Scale from 1.0 to 0.0 over the fadeout duration
				var scale_factor = max(0.0, 1.0 - fade_progress)
				segment.scale = Vector3.ONE * scale_factor
	
	# Remove fully faded segments (in reverse order to maintain indices)
	for i in range(segments_to_remove.size() - 1, -1, -1):
		var index = segments_to_remove[i]
		tracer_data.trail_segments.remove_at(index)
		tracer_data.segment_ages.remove_at(index)

func _trim_old_segments(tracer_data: TracerData):
	"""Remove segments that exceed the maximum count."""
	# Trim visual segments and their ages
	while tracer_data.trail_segments.size() > tracer_segment_count:
		var old_segment = tracer_data.trail_segments.pop_front()
		if is_instance_valid(old_segment):
			old_segment.queue_free()
		# Remove corresponding age
		if tracer_data.segment_ages.size() > 0:
			tracer_data.segment_ages.pop_front()
	
	# Trim position history (keep a few extra for line segment generation)
	while tracer_data.segment_positions.size() > tracer_segment_count + 5:
		tracer_data.segment_positions.pop_front()

func _cleanup_tracer_visuals(tracer_data: TracerData):
	"""Clean up all visual elements for a tracer."""
	for segment in tracer_data.trail_segments:
		if is_instance_valid(segment):
			segment.queue_free()
	
	tracer_data.trail_segments.clear()
	tracer_data.segment_ages.clear()
	tracer_data.segment_positions.clear()

func _cleanup_invalid_tracers():
	"""Remove tracers that are fully faded out."""
	var to_remove: Array[int] = []
	
	for bullet_id in active_tracers.keys():
		var tracer_data = active_tracers[bullet_id]
		
		# Check if tracer should be removed
		var should_remove = false
		
		# Remove if explicitly marked as inactive
		if not tracer_data.is_active:
			should_remove = true
		# Remove if bullet is destroyed AND all segments are fully faded out
		elif tracer_data.bullet_destroyed and _all_segments_faded(tracer_data):
			should_remove = true
		
		if should_remove:
			to_remove.append(bullet_id)
	
	# Clean up tracers that are fully faded (use direct cleanup, not unregister)
	for bullet_id in to_remove:
		var tracer_data = active_tracers[bullet_id]
		_cleanup_tracer_visuals(tracer_data)
		active_tracers.erase(bullet_id)

func _all_segments_faded(tracer_data: TracerData) -> bool:
	"""Check if all segments in a tracer have fully faded out."""
	# Since we remove fully faded segments immediately, just check if no segments remain
	return tracer_data.trail_segments.size() == 0

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
