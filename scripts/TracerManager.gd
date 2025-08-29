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

# === EXPLOSION AND IMPACT EFFECTS ===
@export var explosion_enabled: bool = true
@export var impact_enabled: bool = true

# === STATE ===
var tracer_container: Node3D = null
var active_tracers: Dictionary = {}  # bullet_id -> tracer_data
var active_explosions: Array = []
var active_impacts: Array = []
var next_bullet_id: int = 0

# === BULLET RECALL SYSTEM ===
var fired_bullets_queue: Array = []  # Array of bullet_ids in firing order (most recent last)

# === TIME SYSTEM INTEGRATION ===
var time_manager: Node = null

# === TRACER DATA STRUCTURE ===
class TracerData:
	var bullet: Area3D
	var trail_segments: Array = []
	var segment_ages: Array = []  # Track age of each segment for manual fadeout
	var last_update_time: float = 0.0
	var segment_positions: Array = []
	var is_active: bool = true
	var bullet_destroyed: bool = false  # Track if bullet is gone but tracers should persist
	var tracer_color: Color = Color.YELLOW  # Per-bullet tracer color
	var last_known_bounces: int = 0  # Track bounces to detect when bullet bounces
	
	func _init(bullet_ref: Area3D):
		bullet = bullet_ref
		# Get tracer color from bullet if available
		if bullet.has_method("get_tracer_color"):
			tracer_color = bullet.get_tracer_color()
		elif "tracer_color" in bullet:
			tracer_color = bullet.tracer_color
		else:
			tracer_color = Color.YELLOW  # Fallback color

func _ready():

	# Connect to TimeManager
	time_manager = get_node("/root/TimeManager")

	
	# Wait a frame to ensure GameManager is loaded
	await get_tree().process_frame
	
	# Connect to GameManager for restart events
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.game_restart_requested.connect(_on_game_restart_requested)
	
	# Create tracer container when main scene is ready
	call_deferred("_setup_tracer_container")

func _setup_tracer_container():
	"""Create tracer container in main scene."""

	var main_scene = get_tree().current_scene
	if main_scene:
		tracer_container = Node3D.new()
		tracer_container.name = "TracerContainer"
		main_scene.add_child(tracer_container)
		print("TracerManager: TracerContainer created in main scene")
		print("TracerManager: TracerContainer path: ", tracer_container.get_path())
	else:
		print("WARNING: Could not find main scene for TracerContainer!")

func _process(delta: float):
	"""Update all active tracers, explosions, and impacts."""
	if not tracer_enabled and not explosion_enabled and not impact_enabled:
		return
	if not tracer_container:
		# Try to recreate container if it's missing
		_setup_tracer_container()
		return
	
	# Use time-adjusted delta - tracers should respect time scale
	var time_adjusted_delta = delta
	if time_manager:
		time_adjusted_delta = time_manager.get_effective_delta(delta, 0.0)  # No time resistance for tracers

	
	var current_time = Time.get_ticks_msec() / 1000.0
	
	# Update tracers
	if tracer_enabled:
		# Update each active tracer with time-adjusted delta
		for bullet_id in active_tracers.keys():
			var tracer_data = active_tracers[bullet_id]
			_update_tracer(tracer_data, time_adjusted_delta, current_time)
			_update_segment_fadeout(tracer_data, time_adjusted_delta)
		
		# Clean up invalid bullets
		_cleanup_invalid_tracers()
	
	# Update explosions
	if explosion_enabled:
		var explosions_to_remove: Array = []
		for i in range(active_explosions.size()):
			var explosion_data = active_explosions[i]
			if _update_explosion_animation(explosion_data, time_adjusted_delta):
				explosions_to_remove.append(i)
		
		# Remove finished explosions (in reverse order)
		for i in range(explosions_to_remove.size() - 1, -1, -1):
			var index = explosions_to_remove[i]
			active_explosions.remove_at(index)
	
	# Update impacts
	if impact_enabled:
		var impacts_to_remove: Array = []
		for i in range(active_impacts.size()):
			var impact_data = active_impacts[i]
			if _update_impact_animation(impact_data, time_adjusted_delta):
				impacts_to_remove.append(i)
		
		# Remove finished impacts (in reverse order)
		for i in range(impacts_to_remove.size() - 1, -1, -1):
			var index = impacts_to_remove[i]
			active_impacts.remove_at(index)

func register_bullet(bullet: Area3D) -> int:
	"""Register a bullet for tracer tracking. Returns bullet ID."""
	if not tracer_enabled or not bullet:

		return -1
	
	# Check if tracer container exists, if not try to create it
	if not tracer_container:

		_setup_tracer_container()
		
		# If still no container, we can't register
		if not tracer_container:

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
	
	# Remove from recall queue
	_remove_from_recall_queue(bullet_id)
	
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
	
	# Check if bullet has bounced since last tracer segment
	var current_bounces = tracer_data.bullet.current_bounces if "current_bounces" in tracer_data.bullet else 0
	
	if current_bounces > tracer_data.last_known_bounces:
		# Bullet has bounced! Clear segment history to avoid connecting across the bounce
		tracer_data.segment_positions.clear()
		tracer_data.last_known_bounces = current_bounces

	
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
		var distance = prev_pos.distance_to(position)
		

		
		var segment = _create_line_segment(prev_pos, position, tracer_data)
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
		var segment = _create_sphere_segment(tracer_data)
		tracer_container.add_child(segment)
		
		# Now that it's in the tree, set position
		segment.global_position = position
		
		tracer_data.trail_segments.append(segment)
		tracer_data.segment_ages.append(0.0)  # Start with age 0

	

func _create_sphere_segment(tracer_data: TracerData) -> MeshInstance3D:
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
	material.albedo_color = tracer_data.tracer_color
	material.emission_enabled = true
	material.emission = tracer_data.tracer_color
	material.emission_energy = tracer_emission_energy
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	segment.material_override = material

	return segment

func _create_line_segment(start_pos: Vector3, end_pos: Vector3, tracer_data: TracerData) -> MeshInstance3D:
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
	material.albedo_color = tracer_data.tracer_color
	material.emission_enabled = true
	material.emission = tracer_data.tracer_color
	material.emission_energy = tracer_emission_energy
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	segment.material_override = material
		
	return segment

func _update_segment_fadeout(tracer_data: TracerData, time_adjusted_delta: float):
	"""Manually update segment fadeout using time-adjusted aging."""
	var segments_to_remove: Array = []
	
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
	var to_remove: Array = []
	
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

# === EXPLOSION AND IMPACT ANIMATION FUNCTIONS ===

func _update_explosion_animation(explosion_data: Dictionary, time_adjusted_delta: float) -> bool:
	"""Update a single explosion animation. Returns true if animation is complete."""
	var explosion = explosion_data.get("explosion")
	var age = explosion_data.get("age", 0.0)
	var total_duration = explosion_data.get("total_duration", 0.6)
	var phase = explosion_data.get("phase", "expand")  # expand, fade, scale_down
	
	if not is_instance_valid(explosion):
		return true  # Remove invalid explosions
	
	# Age the explosion using time-adjusted delta (same as tracers)
	age += time_adjusted_delta
	explosion_data["age"] = age
	
	# Calculate progress
	var progress = age / total_duration
	
	match phase:
		"expand":
			# Rapid expansion phase (0.0 to 0.33 of total time)
			var expand_progress = min(1.0, progress / 0.33)
			explosion.scale = Vector3.ONE * expand_progress
			
			if expand_progress >= 1.0:
				phase = "fade"
				explosion_data["phase"] = phase
		
		"fade":
			# Color fade phase (0.33 to 0.67 of total time)
			var fade_progress = (progress - 0.33) / 0.34
			if fade_progress >= 1.0:
				fade_progress = 1.0
			
			var material = explosion.material_override as StandardMaterial3D
			if material:
				material.emission_energy = 5.0 * (1.0 - fade_progress)
				material.albedo_color = Color.ORANGE_RED.lerp(Color.DARK_RED, fade_progress)
			
			if fade_progress >= 1.0:
				phase = "scale_down"
				explosion_data["phase"] = phase
		
		"scale_down":
			# Scale down and remove phase (0.67 to 1.0 of total time)
			var scale_progress = (progress - 0.67) / 0.33
			if scale_progress >= 1.0:
				scale_progress = 1.0
			
			explosion.scale = Vector3.ONE * (1.0 - scale_progress)
			
			if scale_progress >= 1.0:
				# Animation complete
				explosion.queue_free()
				return true
	
	return false

func _update_impact_animation(impact_data: Dictionary, time_adjusted_delta: float) -> bool:
	"""Update a single impact animation. Returns true if animation is complete."""
	var impact = impact_data.get("impact")
	var age = impact_data.get("age", 0.0)
	var total_duration = impact_data.get("total_duration", 0.7)
	var phase = impact_data.get("phase", "scale_up")  # scale_up, scale_down
	
	if not is_instance_valid(impact):
		return true  # Remove invalid impacts
	
	# Age the impact using time-adjusted delta (same as tracers)
	age += time_adjusted_delta
	impact_data["age"] = age
	
	# Calculate progress
	var progress = age / total_duration
	
	match phase:
		"scale_up":
			# Scale up phase (0.0 to 0.21 of total time)
			var scale_up_progress = min(1.0, progress / 0.21)
			impact.scale = Vector3.ONE * (1.0 + scale_up_progress)  # Scale from 1.0 to 2.0
			
			if scale_up_progress >= 1.0:
				phase = "scale_down"
				impact_data["phase"] = phase
		
		"scale_down":
			# Scale down and remove phase (0.21 to 1.0 of total time)
			var scale_down_progress = (progress - 0.21) / 0.79
			if scale_down_progress >= 1.0:
				scale_down_progress = 1.0
			
			impact.scale = Vector3.ONE * (2.0 - scale_down_progress * 2.0)  # Scale from 2.0 to 0.0
			
			if scale_down_progress >= 1.0:
				# Animation complete
				impact.queue_free()
				return true
	
	return false

# === PUBLIC API FOR EXPLOSIONS AND IMPACTS ===

func create_explosion(position: Vector3, radius: float = 1.0):
	"""Create an explosion effect at the given position."""
	if not explosion_enabled or not tracer_container:
		return
	
	var explosion = MeshInstance3D.new()
	tracer_container.add_child(explosion)
	
	# Create sphere mesh for explosion
	var sphere = SphereMesh.new()
	sphere.radius = radius * 0.3  # Start smaller
	sphere.height = radius * 0.6
	explosion.mesh = sphere
	explosion.global_position = position
	
	# Create bright explosion material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.ORANGE_RED
	material.emission_enabled = true
	material.emission = Color.ORANGE_RED
	material.emission_energy = 5.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	explosion.material_override = material
	
	# Start with scale 0
	explosion.scale = Vector3.ZERO
	
	# Add to active explosions list for animation
	var explosion_data = {
		"explosion": explosion,
		"age": 0.0,
		"total_duration": 0.6,
		"phase": "expand"
	}
	active_explosions.append(explosion_data)

func create_impact(position: Vector3, color: Color = Color.YELLOW, size: float = 0.25):
	"""Create an impact effect at the given position."""
	if not impact_enabled or not tracer_container:
		return
	
	var impact = MeshInstance3D.new()
	tracer_container.add_child(impact)
	
	# Create sphere for impact
	var sphere = SphereMesh.new()
	sphere.radius = size
	sphere.height = size * 2.0
	impact.mesh = sphere
	impact.global_position = position
	
	# Create bright material
	var material = StandardMaterial3D.new()
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = color
	material.emission_energy = 8.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	impact.material_override = material
	
	# Start with normal scale
	impact.scale = Vector3.ONE
	
	# Add to active impacts list for animation
	var impact_data = {
		"impact": impact,
		"age": 0.0,
		"total_duration": 0.7,
		"phase": "scale_up"
	}
	active_impacts.append(impact_data)

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

func _on_game_restart_requested():
	"""Called when game is restarting - reset tracer system"""

	reset_tracer_system()

func reset_tracer_system():
	"""Reset the tracer system for a new game session"""
	print("TracerManager: Resetting tracer system...")
	print("TracerManager: Active tracers before reset: ", active_tracers.size())
	print("TracerManager: Active explosions before reset: ", active_explosions.size())
	print("TracerManager: Active impacts before reset: ", active_impacts.size())
	
	# Immediately disable systems to prevent new registrations
	tracer_enabled = false
	explosion_enabled = false
	impact_enabled = false
	
	# Clear all active tracers immediately
	for bullet_id in active_tracers.keys():
		print("TracerManager: Unregistering bullet ID: ", bullet_id)
		var tracer_data = active_tracers[bullet_id]
		# Force cleanup of all visual elements immediately
		_cleanup_tracer_visuals(tracer_data)
	
	# Clear all active explosions immediately
	for explosion_data in active_explosions:
		var explosion = explosion_data.get("explosion")
		if is_instance_valid(explosion):
			explosion.queue_free()
	
	# Clear all active impacts immediately
	for impact_data in active_impacts:
		var impact = impact_data.get("impact")
		if is_instance_valid(impact):
			impact.queue_free()
	
	# Clear all arrays
	active_tracers.clear()
	active_explosions.clear()
	active_impacts.clear()
	
	# Reset bullet ID counter
	next_bullet_id = 0
	print("TracerManager: Reset bullet ID counter to 0")
	
	# Clear tracer container
	if tracer_container:
		print("TracerManager: Destroying old tracer container")
		tracer_container.queue_free()
		tracer_container = null
	else:
		print("TracerManager: No tracer container to destroy")
	
	# Re-enable systems
	tracer_enabled = true
	explosion_enabled = true
	impact_enabled = true
	
	# Wait a frame to ensure scene is reloaded, then recreate tracer container
	print("TracerManager: Waiting for scene reload, then recreating container")
	await get_tree().process_frame
	await get_tree().process_frame  # Wait a bit more to ensure scene is fully loaded
	
	# Try to recreate tracer container immediately
	_setup_tracer_container()
	print("TracerManager: Tracer system reset complete")

# === BULLET RECALL SYSTEM ===

func notify_bullet_fired(bullet_id: int):
	"""Notify that a bullet was fired (add to recall queue)."""
	if bullet_id >= 0 and active_tracers.has(bullet_id):
		fired_bullets_queue.append(bullet_id)
		print("TracerManager: Bullet ", bullet_id, " added to recall queue (queue size: ", fired_bullets_queue.size(), ")")

func recall_most_recent_bullet() -> bool:
	"""Recall the most recently fired bullet that's still active."""
	# Remove invalid bullets from the end of the queue
	while fired_bullets_queue.size() > 0:
		var bullet_id = fired_bullets_queue[-1]  # Most recent bullet
		
		# Check if bullet still exists and is recallable
		if active_tracers.has(bullet_id) and active_tracers[bullet_id].bullet:
			var bullet = active_tracers[bullet_id].bullet
			if is_instance_valid(bullet) and bullet.has_method("recall_to_player"):
				if bullet.recall_to_player():
					# Successfully recalled - remove from queue
					fired_bullets_queue.pop_back()
					print("TracerManager: Successfully recalled bullet ", bullet_id)
					return true
				else:
					print("TracerManager: Bullet ", bullet_id, " could not be recalled")
					fired_bullets_queue.pop_back()
			else:
				print("TracerManager: Bullet ", bullet_id, " is invalid or doesn't support recall")
				fired_bullets_queue.pop_back()
		else:
			print("TracerManager: Bullet ", bullet_id, " no longer exists, removing from queue")
			fired_bullets_queue.pop_back()
	
	print("TracerManager: No bullets available for recall")
	return false

func _remove_from_recall_queue(bullet_id: int):
	"""Remove a bullet from the recall queue."""
	var index = fired_bullets_queue.find(bullet_id)
	if index >= 0:
		fired_bullets_queue.remove_at(index)
		print("TracerManager: Removed bullet ", bullet_id, " from recall queue")

func update_bullet_color(bullet_id: int):
	"""Update tracer color for a bullet (call after bullet configuration)."""
	if not active_tracers.has(bullet_id):
		return
	
	var tracer_data = active_tracers[bullet_id]
	if not tracer_data.bullet or not is_instance_valid(tracer_data.bullet):
		return
	
	# Re-read the bullet's color
	if tracer_data.bullet.has_method("get_tracer_color"):
		tracer_data.tracer_color = tracer_data.bullet.get_tracer_color()
	elif "tracer_color" in tracer_data.bullet:
		tracer_data.tracer_color = tracer_data.bullet.tracer_color

# === DEBUG ===

func print_tracer_state():
	"""Debug function to print current tracer state."""
	print("=== TRACER MANAGER STATE ===")
	print("Enabled: ", tracer_enabled)
	print("Active tracers: ", active_tracers.size())
	print("Container valid: ", is_instance_valid(tracer_container))
	print("============================")
