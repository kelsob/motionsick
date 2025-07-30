extends RigidBody3D

# === TRAVEL BEHAVIOR TYPES ===
enum TravelType {
	HITSCAN,           # Instant travel
	CONSTANT_SLOW,     # Constant slow speed
	CONSTANT_FAST,     # Constant fast speed  
	SLOW_ACCELERATE,   # Start slow, accelerate quickly
	FAST_DECELERATE,   # Start fast, slow down
	CURVE_ACCELERATE,  # Smooth acceleration curve
	PULSE_SPEED,       # Alternating fast/slow pulses
	DELAYED_HITSCAN    # Brief delay then instant
}

# === CONFIGURATION ===
@export var base_speed: float = 40.0
@export var lifetime: float = 2.0
@export var travel_type: TravelType = TravelType.CONSTANT_FAST

# Time system integration
@export var time_resistance: float = 0.0  # 0.0 = fully affected by time, 1.0 = immune

# === TRAVEL BEHAVIOR SETTINGS ===
var max_speed: float = 80.0
var min_speed: float = 10.0
var acceleration_rate: float = 120.0  # units/second^2
var deceleration_rate: float = 60.0
var pulse_frequency: float = 3.0  # pulses per second
var hitscan_delay: float = 0.1  # seconds before hitscan

# === STATE ===
var life_timer: float = 0.0
var has_been_fired: bool = false
var gun_reference: Node3D = null
var muzzle_marker: Node3D = null
var damage: int = 25  # Default damage value
var has_hit_target: bool = false  # Prevent multiple hits

# Time system
var time_affected: TimeAffected = null

# Explosion properties
var is_explosive: bool = false
var explosion_radius: float = 0.0
var explosion_damage: int = 0

# Travel behavior state
var current_speed: float = 0.0
var travel_direction: Vector3 = Vector3.ZERO
var initial_position: Vector3 = Vector3.ZERO
var hitscan_timer: float = 0.0

func _ready():
	# Ensure bullet starts with proper physics settings
	sleeping = false
	freeze = false
	gravity_scale = 1.0
	
	# Set bouncy physics for bullets using physics material
	var physics_material = PhysicsMaterial.new()
	physics_material.bounce = 0.8
	physics_material.friction = 0.1
	physics_material_override = physics_material
	
	# Connect collision signal - RigidBody3D uses body_entered when contact_monitor is enabled
	contact_monitor = true
	max_contacts_reported = 10
	body_entered.connect(_on_body_entered)
	
	# Add time system component
	time_affected = TimeAffected.new()
	time_affected.time_resistance = time_resistance
	add_child(time_affected)
	
	# Bullet ready with bouncy physics and time system

func _physics_process(delta):
	# If not fired yet, track the gun's muzzle position
	if not has_been_fired and muzzle_marker:
		global_position = muzzle_marker.global_position
		return
	
	# Only count lifetime after being fired
	if has_been_fired:
		# Use time-adjusted delta for lifetime and travel behavior
		var time_delta = time_affected.get_time_adjusted_delta(delta) if time_affected else delta
		
		life_timer += time_delta
		if life_timer > lifetime:
			queue_free()
		
		# Handle travel behavior with time-adjusted delta
		_update_travel_behavior(time_delta)

func set_gun_reference(gun: Node3D, muzzle: Node3D):
	gun_reference = gun
	muzzle_marker = muzzle

func set_damage(new_damage: int):
	damage = new_damage

func set_explosion_properties(radius: float, explosion_dmg: int):
	is_explosive = true
	explosion_radius = radius
	explosion_damage = explosion_dmg
	print("Bullet configured as explosive - Radius: ", radius, " Damage: ", explosion_dmg)

func set_time_resistance(resistance: float):
	"""Set time resistance for this bullet."""
	time_resistance = clamp(resistance, 0.0, 1.0)
	if time_affected:
		time_affected.set_time_resistance(time_resistance)

func fire(direction: Vector3):
	# Mark as fired so it stops tracking muzzle
	has_been_fired = true
	life_timer = 0.0
	travel_direction = direction.normalized()
	initial_position = global_position
	
	# Bullet fired and configured
	
	# Initialize travel behavior based on type
	var initial_time_scale = time_affected.get_effective_time_scale() if time_affected else 1.0
	
	match travel_type:
		TravelType.HITSCAN:
			_fire_hitscan()
		TravelType.CONSTANT_SLOW:
			current_speed = min_speed
			linear_velocity = travel_direction * current_speed * initial_time_scale
		TravelType.CONSTANT_FAST:
			current_speed = max_speed
			linear_velocity = travel_direction * current_speed * initial_time_scale
		TravelType.SLOW_ACCELERATE:
			current_speed = min_speed
			linear_velocity = travel_direction * current_speed * initial_time_scale
		TravelType.FAST_DECELERATE:
			current_speed = max_speed
			linear_velocity = travel_direction * current_speed * initial_time_scale
		TravelType.CURVE_ACCELERATE:
			current_speed = min_speed
			linear_velocity = travel_direction * current_speed * initial_time_scale
		TravelType.PULSE_SPEED:
			current_speed = base_speed
			linear_velocity = travel_direction * current_speed * initial_time_scale
		TravelType.DELAYED_HITSCAN:
			current_speed = 0.0
			linear_velocity = Vector3.ZERO
			hitscan_timer = 0.0
	
	# Orient the bullet to face its travel direction
	if travel_direction.length() > 0.01:  # More robust length check
		var up_vector = Vector3.UP
		# If travel direction is too close to UP, use FORWARD as up vector
		if abs(travel_direction.dot(Vector3.UP)) > 0.99:
			up_vector = Vector3.FORWARD
		look_at(global_position + travel_direction, up_vector)
	
	# Clear references to avoid holding onto the gun
	gun_reference = null
	muzzle_marker = null

func set_travel_config(type: TravelType, config: Dictionary = {}):
	"""Configure travel behavior and parameters."""
	travel_type = type
	
	# Apply configuration overrides
	if config.has("max_speed"):
		max_speed = config.max_speed
	if config.has("min_speed"):
		min_speed = config.min_speed
	if config.has("acceleration_rate"):
		acceleration_rate = config.acceleration_rate
	if config.has("deceleration_rate"):
		deceleration_rate = config.deceleration_rate
	if config.has("pulse_frequency"):
		pulse_frequency = config.pulse_frequency
	if config.has("hitscan_delay"):
		hitscan_delay = config.hitscan_delay

func _update_travel_behavior(time_delta: float):
	"""Update bullet movement based on travel type with time-adjusted delta."""
	# Get current time scale for velocity scaling
	var time_scale = time_affected.get_effective_time_scale() if time_affected else 1.0
	
	match travel_type:
		TravelType.HITSCAN:
			# Already handled in _fire_hitscan()
			pass
		TravelType.CONSTANT_SLOW, TravelType.CONSTANT_FAST:
			# Apply time scale to velocity for smooth slowdown/speedup
			linear_velocity = travel_direction * current_speed * time_scale
		TravelType.SLOW_ACCELERATE:
			current_speed = min(max_speed, current_speed + acceleration_rate * time_delta)
			linear_velocity = travel_direction * current_speed * time_scale
		TravelType.FAST_DECELERATE:
			current_speed = max(min_speed, current_speed - deceleration_rate * time_delta)
			linear_velocity = travel_direction * current_speed * time_scale
		TravelType.CURVE_ACCELERATE:
			# Smooth acceleration curve using easing
			var progress = min(1.0, life_timer / 1.0)  # 1 second to reach max speed
			var ease_factor = ease_out_cubic(progress)
			current_speed = lerp(min_speed, max_speed, ease_factor)
			linear_velocity = travel_direction * current_speed * time_scale
		TravelType.PULSE_SPEED:
			# Pulsing speed pattern
			var pulse_factor = 0.5 + 0.5 * sin(life_timer * pulse_frequency * TAU)
			current_speed = lerp(min_speed, max_speed, pulse_factor)
			linear_velocity = travel_direction * current_speed * time_scale
		TravelType.DELAYED_HITSCAN:
			hitscan_timer += time_delta
			if hitscan_timer >= hitscan_delay:
				_fire_hitscan()
				travel_type = TravelType.HITSCAN  # Prevent repeated firing

func ease_out_cubic(t: float) -> float:
	"""Cubic ease-out function for smooth acceleration."""
	return 1.0 - pow(1.0 - t, 3.0)

func _fire_hitscan():
	"""Instant travel implementation with visual effects."""
	var start_pos = global_position
	
	# Cast ray to find hit point
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		start_pos,
		start_pos + travel_direction * 1000.0  # Long range
	)
	
	# Hit Environment (layer 3, bit value 4) + Enemy (layer 8, bit value 128) = 132
	query.collision_mask = 132 + 1  # Environment (layer 3, bit 4) + Enemy (layer 8, bit 128) + Player layer (bit 1) = 133
	# Note: Including Player layer temporarily since environment might be on layer 1 instead of layer 3 
	query.exclude = [get_tree().get_first_node_in_group("player")]  # Exclude player
	
	print("RAYCAST QUERY DEBUG:")
	print("Query from: ", query.from)
	print("Query to: ", query.to)
	print("Query direction vector: ", (query.to - query.from).normalized())
	
	print("=== HITSCAN DEBUG ===")
	print("Firing from: ", start_pos)
	print("Direction: ", travel_direction)
	print("Direction normalized: ", travel_direction.normalized())
	print("Direction length: ", travel_direction.length())
	print("End point would be: ", start_pos + travel_direction * 1000.0)
	
	var result = space_state.intersect_ray(query)
	var end_pos: Vector3
	var hit_body = null
	
	if result:
		end_pos = result.position
		hit_body = result.collider
		print("RAY HIT: ", hit_body.name)
		print("Hit position: ", end_pos)
		print("Hit body class: ", hit_body.get_class())
		print("Hit body collision layer: ", hit_body.collision_layer)
		print("Hit body groups: ", hit_body.get_groups())
		print("Has take_damage method: ", hit_body.has_method("take_damage"))
		print("Distance from start: ", start_pos.distance_to(end_pos))
		
		# Move to hit position
		global_position = result.position
	else:
		print("RAY MISSED - no collision found")
		# No hit, travel max distance
		end_pos = start_pos + travel_direction * 1000.0
		global_position = end_pos
	
	# Create visual effects
	_create_hitscan_visuals(start_pos, end_pos, hit_body != null)
	
	# Handle collision if we hit something
	if hit_body:
		print("Attempting to apply damage to: ", hit_body.name)
		# Apply damage directly for hitscan
		if hit_body.has_method("take_damage"):
			print("SUCCESS: Applying hitscan damage: ", damage)
			hit_body.take_damage(damage)
		else:
			print("ERROR: Target has no take_damage method!")
		has_hit_target = true
		queue_free()
	else:
		print("No damage to apply - no target hit")
		queue_free()
	
	print("=== END HITSCAN DEBUG ===\n")

func _create_hitscan_visuals(start_pos: Vector3, end_pos: Vector3, hit_target: bool):
	"""Create visual effects for hitscan weapons."""
	# Create tracer line
	_create_tracer_line(start_pos, end_pos)
	
	# Muzzle flash now handled by Gun.gd
	
	# Create impact effect if we hit something
	if hit_target:
		_create_impact_effect(end_pos)

func _create_tracer_line(start_pos: Vector3, end_pos: Vector3):
	"""Create a bright tracer line that fades quickly."""
	var tracer = MeshInstance3D.new()
	get_tree().current_scene.add_child(tracer)
	
	# Use a simple cylinder mesh for the line
	var cylinder_mesh = CylinderMesh.new()
	var distance = start_pos.distance_to(end_pos)
	cylinder_mesh.height = distance
	cylinder_mesh.top_radius = 0.02
	cylinder_mesh.bottom_radius = 0.02
	tracer.mesh = cylinder_mesh
	
	# Position and orient the tracer
	var center_pos = (start_pos + end_pos) / 2.0
	var line_direction = (end_pos - start_pos).normalized()
	
	print("TRACER DEBUG:")
	print("Start: ", start_pos)
	print("End: ", end_pos)
	print("Center: ", center_pos)
	print("Line direction: ", line_direction)
	
	# Set position
	tracer.global_position = center_pos
	
	# Create a transform that orients the cylinder along the line direction (Y-axis aligned)
	if line_direction.length() > 0.001:
		var new_y = line_direction.normalized()
		var new_x = Vector3.RIGHT
		
		# Make sure X is perpendicular to Y
		if abs(new_y.dot(new_x)) > 0.9:
			new_x = Vector3.FORWARD
		
		new_x = (new_x - new_y * new_y.dot(new_x)).normalized()
		var new_z = new_x.cross(new_y).normalized()
		
		# Additional safety checks to prevent singular matrix
		if new_x.length() > 0.01 and new_y.length() > 0.01 and new_z.length() > 0.01:
			var determinant = new_x.cross(new_y).dot(new_z)
			if abs(determinant) > 0.001:  # Ensure non-singular matrix
				var new_basis = Basis(new_x, new_y, new_z)
				tracer.global_transform.basis = new_basis
				print("Tracer oriented with manual basis")
			else:
				print("WARNING: Determinant too small, skipping basis assignment")
		else:
			print("WARNING: Invalid basis vectors, skipping orientation")
	else:
		print("WARNING: Zero length line direction!")
	
	# Create glowing material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.CYAN
	material.emission_enabled = true
	material.emission = Color.CYAN
	material.emission_energy = 3.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	tracer.material_override = material
	
	# Add fallback timer cleanup
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 4.0  # Longer than animation duration
	cleanup_timer.one_shot = true
	cleanup_timer.timeout.connect(_cleanup_tracer.bind(tracer, cleanup_timer))
	get_tree().current_scene.add_child(cleanup_timer)
	cleanup_timer.start()
	
	# Animate the tracer to fade out
	_animate_tracer_fadeout(tracer)



func _create_impact_effect(pos: Vector3):
	"""Create impact effect at hit location."""
	var impact = MeshInstance3D.new()
	get_tree().current_scene.add_child(impact)
	impact.global_position = pos
	
	# Create small bright sphere
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.1
	sphere_mesh.height = 0.2
	impact.mesh = sphere_mesh
	
	# Bright impact material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.ORANGE
	material.emission_enabled = true
	material.emission = Color.ORANGE
	material.emission_energy = 3.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	impact.material_override = material
	
	# Add fallback cleanup
	var cleanup_timer = Timer.new()
	cleanup_timer.wait_time = 2.5  # Longer than animation duration
	cleanup_timer.one_shot = true
	cleanup_timer.timeout.connect(_cleanup_impact.bind(impact, cleanup_timer))
	get_tree().current_scene.add_child(cleanup_timer)
	cleanup_timer.start()
	
	# Quick fade out
	_animate_impact_fadeout(impact)

func _animate_tracer_fadeout(tracer: MeshInstance3D):
	"""Animate tracer line fade out over 3 seconds."""
	if not tracer or not is_instance_valid(tracer):
		return
		
	var tween = get_tree().create_tween()
	
	# Scale down to zero so it completely disappears
	tween.tween_property(tracer, "scale", Vector3.ZERO, 3.0)
	
	# Remove after animation with safer callback
	tween.tween_callback(_safe_cleanup_tracer.bind(tracer))



func _animate_impact_fadeout(impact: MeshInstance3D):
	"""Animate impact effect fade out over 2 seconds."""
	if not impact or not is_instance_valid(impact):
		return
	
	var tween = get_tree().create_tween()
	
	# Big burst then shrink - no material manipulation
	tween.tween_property(impact, "scale", Vector3.ONE * 3.0, 0.1)
	tween.tween_property(impact, "scale", Vector3.ZERO, 0.5)
	
	# Safe removal
	tween.tween_callback(_safe_cleanup_impact.bind(impact))

func _cleanup_tracer(tracer: MeshInstance3D, timer: Timer):
	"""Safe cleanup function for tracer effects."""
	if is_instance_valid(tracer):
		tracer.queue_free()
	if is_instance_valid(timer):
		timer.queue_free()


	if is_instance_valid(timer):
		timer.queue_free()

func _cleanup_impact(impact: MeshInstance3D, timer: Timer):
	"""Safe cleanup function for impact effects."""
	if is_instance_valid(impact):
		impact.queue_free()
	if is_instance_valid(timer):
		timer.queue_free()

func _safe_cleanup_tracer(tracer: MeshInstance3D):
	"""Safe cleanup for tween callbacks."""
	if is_instance_valid(tracer):
		tracer.queue_free()



func _safe_cleanup_impact(impact: MeshInstance3D):
	"""Safe cleanup for tween callbacks."""
	if is_instance_valid(impact):
		impact.queue_free()

func _on_body_entered(body):
	# Check if we hit an enemy
	if body.has_method("take_damage"):
		print("Bullet hit enemy for ", damage, " damage")
		body.take_damage(damage)
		has_hit_target = true
		
		# Create explosion if this bullet is explosive
		if is_explosive:
			_create_bullet_explosion(global_position)
		
		queue_free()
	# Check if we hit environment (walls/floor) - let bullets bounce naturally
	elif body != get_tree().get_first_node_in_group("player"):
		print("Bullet bounced off ", body.name)
		
		# Create explosion if this bullet is explosive (even on environment hits)
		if is_explosive:
			_create_bullet_explosion(global_position)
			queue_free()  # Explosive bullets don't bounce
		else:
			# Let RigidBody3D physics handle the bounce automatically
			# Don't destroy bullet on environment hits
			pass
	# Ignore player collisions

func _create_bullet_explosion(position: Vector3):
	"""Create explosion effect from bullet impact."""
	if not is_explosive or explosion_radius <= 0.0:
		return
	
	print("BULLET EXPLOSION at ", position, " - Radius: ", explosion_radius, " Damage: ", explosion_damage)
	
	# Apply area damage
	_apply_bullet_explosion_damage(position)
	
	# Create visual explosion effect
	_create_bullet_explosion_visual(position)

func _apply_bullet_explosion_damage(explosion_pos: Vector3):
	"""Apply explosion damage to all enemies within radius."""
	var space_state = get_world_3d().direct_space_state
	
	# Find all enemies within radius using sphere collision
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = explosion_radius
	query.shape = sphere
	query.transform.origin = explosion_pos
	query.collision_mask = 128  # Enemy layer (bit 8)
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var enemy = result.collider
		if enemy.has_method("take_damage"):
			# Calculate distance-based damage falloff
			var distance = explosion_pos.distance_to(enemy.global_position)
			var damage_multiplier = 1.0 - (distance / explosion_radius)  # Linear falloff
			var final_damage = int(explosion_damage * damage_multiplier)
			
			print("Bullet explosion damaged ", enemy.name, " for ", final_damage, " damage (distance: ", "%.1f" % distance, ")")
			enemy.take_damage(final_damage)

func _create_bullet_explosion_visual(position: Vector3):
	"""Create visual explosion effect at bullet impact position."""
	var explosion = MeshInstance3D.new()
	get_tree().current_scene.add_child(explosion)
	
	# Create sphere mesh for explosion
	var sphere = SphereMesh.new()
	sphere.radius = explosion_radius * 0.3  # Start smaller
	sphere.height = explosion_radius * 0.6
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
	
	# Animate explosion
	_animate_bullet_explosion_effect(explosion)

func _animate_bullet_explosion_effect(explosion: MeshInstance3D):
	"""Animate bullet explosion - rapid expansion then fade."""
	if not explosion or not is_instance_valid(explosion):
		return
	
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	
	# Rapid expansion
	explosion.scale = Vector3.ZERO
	tween.tween_property(explosion, "scale", Vector3.ONE, 0.2)
	
	# Color fade (from bright orange to dark red)
	var material = explosion.material_override as StandardMaterial3D
	if material:
		tween.tween_method(
			func(energy): material.emission_energy = energy,
			5.0, 0.0, 0.4
		).set_delay(0.1)
		tween.tween_property(material, "albedo_color", Color.DARK_RED, 0.4).set_delay(0.1)
	
	# Scale down and remove
	tween.tween_property(explosion, "scale", Vector3.ZERO, 0.3).set_delay(0.3)
	tween.tween_callback(func(): if is_instance_valid(explosion): explosion.queue_free()).set_delay(0.6)
