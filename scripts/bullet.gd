extends Area3D

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
@export var base_speed: float = 20.0  # Reduced from 40.0
@export var lifetime: float = 2.0
@export var travel_type: TravelType = TravelType.CONSTANT_FAST

# Time system integration
@export var time_resistance: float = 0.0  # 0.0 = fully affected by time, 1.0 = immune

# Visual properties
@export var tracer_color: Color = Color.YELLOW  # Default tracer color

# === TRAVEL BEHAVIOR SETTINGS ===
var max_speed: float = 40.0  # Reduced from 80.0
var min_speed: float = 5.0   # Reduced from 10.0
var acceleration_rate: float = 60.0  # Reduced from 120.0 (units/second^2)
var deceleration_rate: float = 30.0  # Reduced from 60.0
var pulse_frequency: float = 3.0  # pulses per second
var hitscan_delay: float = 0.1  # seconds before hitscan

# === STATE ===
var life_timer: float = 0.0
var has_been_fired: bool = false
var gun_reference: Node3D = null
var muzzle_marker: Node3D = null
var damage: int = 25  # Default damage value
var knockback: float = 1.0  # Default knockback value
var has_hit_target: bool = false  # Prevent multiple hits

# Time system
var time_affected: TimeAffected = null

# Tracer system
var tracer_id: int = -1

# Explosion properties
var is_explosive: bool = false
var explosion_radius: float = 0.0
var explosion_damage: int = 0

# Piercing properties
var piercing_value: float = 0.0  # How much piercing power the bullet has
var has_pierced: bool = false  # Track if bullet has pierced through anything

# Travel behavior state
var current_speed: float = 0.0
var travel_direction: Vector3 = Vector3.ZERO
var initial_position: Vector3 = Vector3.ZERO
var hitscan_timer: float = 0.0

# Gravity constant (same as player)
@onready var GRAVITY: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var forward_raycast : RayCast3D = $ForwardRaycast
@onready var backward_raycast : RayCast3D = $BackwardRaycast

# === SELF-ANIMATING EFFECTS SYSTEM ===
# Effects now animate themselves using timers instead of relying on bullet's _process

func _ready():
	# Add to bullets group for pickup detection
	add_to_group("bullets")
	
	# Add time system component
	time_affected = TimeAffected.new()
	time_affected.time_resistance = time_resistance
	add_child(time_affected)
	
	# Register with tracer system
	if TracerManager:
		tracer_id = TracerManager.register_bullet(self)
	
	# DON'T connect collision signal yet - wait until bullet is fired
	# This prevents prepared bullets from being destroyed by spawning enemies
	
	# Bullet ready with bouncy physics and time system

func _physics_process(delta):
	# If not fired yet, track the gun's muzzle position and rotation
	if not has_been_fired and muzzle_marker:
		global_position = muzzle_marker.global_position
		global_rotation = muzzle_marker.global_rotation
		return
	
	# Only count lifetime after being fired
	if has_been_fired:
		# Use time-adjusted delta for lifetime and travel behavior
		var time_delta = time_affected.get_time_adjusted_delta(delta) if time_affected else delta
		
		life_timer += time_delta
		if life_timer > lifetime:
			_cleanup_bullet()
			queue_free()
		
		# Handle travel behavior with time-adjusted delta
		_update_travel_behavior(time_delta)
		
		# Manual movement for Area3D
		if travel_type != TravelType.HITSCAN:
			var time_scale = time_affected.get_effective_time_scale() if time_affected else 1.0
			var movement = travel_direction * current_speed * time_scale * time_delta
			global_position += movement



func set_gun_reference(gun: Node3D, muzzle: Node3D):
	gun_reference = gun
	muzzle_marker = muzzle

func set_damage(new_damage: int):
	damage = new_damage

func set_knockback(new_knockback: float):
	knockback = new_knockback

func set_explosion_properties(radius: float, explosion_dmg: int):
	is_explosive = true
	explosion_radius = radius
	explosion_damage = explosion_dmg
	#print("Bullet configured as explosive - Radius: ", radius, " Damage: ", explosion_dmg)

func set_piercing_properties(piercing: float):
	"""Set piercing properties for this bullet."""
	piercing_value = piercing
	has_pierced = false

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
	
	# NOW connect collision signal - bullet is active and should detect collisions
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	
	# Bullet fired and configured
	
	# Initialize travel behavior based on type
	var initial_time_scale = time_affected.get_effective_time_scale() if time_affected else 1.0
	
	match travel_type:
		TravelType.HITSCAN:
			_fire_hitscan()
		TravelType.CONSTANT_SLOW:
			current_speed = min_speed
		TravelType.CONSTANT_FAST:
			current_speed = max_speed
		TravelType.SLOW_ACCELERATE:
			current_speed = min_speed
		TravelType.FAST_DECELERATE:
			current_speed = max_speed
		TravelType.CURVE_ACCELERATE:
			current_speed = min_speed
		TravelType.PULSE_SPEED:
			current_speed = base_speed
		TravelType.DELAYED_HITSCAN:
			current_speed = 0.0
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
	# Get current time scale for speed scaling
	var time_scale = time_affected.get_effective_time_scale() if time_affected else 1.0
	
	match travel_type:
		TravelType.HITSCAN:
			# Already handled in _fire_hitscan()
			pass
		TravelType.CONSTANT_SLOW, TravelType.CONSTANT_FAST:
			# Speed is already set in fire() function
			pass
		TravelType.SLOW_ACCELERATE:
			current_speed = min(max_speed, current_speed + acceleration_rate * time_delta)
		TravelType.FAST_DECELERATE:
			current_speed = max(min_speed, current_speed - deceleration_rate * time_delta)
		TravelType.CURVE_ACCELERATE:
			# Smooth acceleration curve using easing
			var progress = min(1.0, life_timer / 1.0)  # 1 second to reach max speed
			var ease_factor = ease_out_cubic(progress)
			current_speed = lerp(min_speed, max_speed, ease_factor)
		TravelType.PULSE_SPEED:
			# Pulsing speed pattern
			var pulse_factor = 0.5 + 0.5 * sin(life_timer * pulse_frequency * TAU)
			current_speed = lerp(min_speed, max_speed, pulse_factor)
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
		_cleanup_bullet()
		queue_free()
	else:
		print("No damage to apply - no target hit")
		_cleanup_bullet()
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
	
	# Get current time scale to adjust animation speed
	var time_manager = get_node_or_null("/root/TimeManager")
	var time_scale = time_manager.get_time_scale() if time_manager else 1.0
	
	# Scale animation duration by time scale (slower when time is slowed)
	var fade_duration = 3.0 * time_scale
		
	var tween = get_tree().create_tween()
	
	# Scale down to zero so it completely disappears
	tween.tween_property(tracer, "scale", Vector3.ZERO, fade_duration)
	
	# Remove after animation with safer callback
	tween.tween_callback(_safe_cleanup_tracer.bind(tracer))



func _animate_impact_fadeout(impact: MeshInstance3D):
	"""Animate impact effect fade out over 2 seconds."""
	if not impact or not is_instance_valid(impact):
		return
	
	# Get current time scale to adjust animation speed
	var time_manager = get_node_or_null("/root/TimeManager")
	var time_scale = time_manager.get_time_scale() if time_manager else 1.0
	
	# Scale animation durations by time scale (slower when time is slowed)
	var burst_duration = 0.1 * time_scale
	var shrink_duration = 0.5 * time_scale
	
	var tween = get_tree().create_tween()
	
	# Big burst then shrink - no material manipulation
	tween.tween_property(impact, "scale", Vector3.ONE * 3.0, burst_duration)
	tween.tween_property(impact, "scale", Vector3.ZERO, shrink_duration)
	
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



func _cleanup_bullet():
	"""Clean up bullet resources including tracer registration."""
	# Unregister from tracer system
	if TracerManager and tracer_id != -1:
		TracerManager.unregister_bullet(tracer_id)
		tracer_id = -1

func _on_body_entered(body):
	# Calculate proper impact position using raycast
	var impact_position = _get_surface_impact_position(body)
	
	print("=== BULLET COLLISION ===")
	print("Hit body: ", body.name)
	print("Body type: ", body.get_class())
	print("Body collision layer: ", body.collision_layer)
	print("Impact position: ", impact_position)
	print("Bullet position: ", global_position)
	
	# Check if we hit an enemy (has take_damage method)
	if body.has_method("take_damage"):
		print("Bullet hit enemy for ", damage, " damage")
		body.take_damage(damage)
		
		# Apply knockback if enemy supports it
		if body.has_method("apply_knockback"):
			var knockback_direction = travel_direction.normalized()
			body.apply_knockback(knockback_direction, knockback)
		
		has_hit_target = true
		
		# Handle piercing logic
		if piercing_value > 0.0:
			_handle_piercing(body, impact_position)
		else:
			# No piercing - create explosion and destroy bullet
			if is_explosive:
				_create_bullet_explosion(impact_position)
			_cleanup_bullet()
			queue_free()
	
	# Check if we hit environment (walls/floor) - bullets ALWAYS stop at environment
	elif _is_environment(body):
		print("Bullet hit environment: ", body.name)
		
		# Create impact effect
		_create_environment_impact_effect(impact_position)
		
		# Create explosion if this bullet is explosive
		if is_explosive:
			_create_bullet_explosion(impact_position)
		
		_cleanup_bullet()
		queue_free()
	
	# Ignore any other collisions (player, etc.)

func _is_environment(body: Node3D) -> bool:
	"""Check if the body is environment (walls, floors, etc.) based on collision layer."""
	# Environment should be on collision layer 3 (bit value 4)
	return (body.collision_layer & 4) != 0

func _get_surface_impact_position(hit_body: Node3D) -> Vector3:
	"""Calculate the actual surface impact position using raycast."""
	# Cast a ray from slightly behind the bullet to slightly ahead to find surface intersection
	var space_state = get_world_3d().direct_space_state
	var ray_start = global_position - travel_direction * 0.5  # Start slightly behind bullet
	var ray_end = global_position + travel_direction * 0.5    # End slightly ahead
	
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collision_mask = hit_body.collision_layer  # Only hit the specific body
	query.exclude = [self]  # Don't hit the bullet itself
	
	var result = space_state.intersect_ray(query)
	
	if result and result.collider == hit_body:
		# Found the exact surface hit point
		print("Surface impact found via raycast: ", result.position)
		return result.position
	else:
		# Fallback: move bullet position slightly back along travel direction
		var fallback_position = global_position - travel_direction.normalized() * 0.1
		print("Using fallback impact position: ", fallback_position)
		return fallback_position

func _handle_piercing(enemy: Node3D, impact_position: Vector3):
	"""Handle piercing logic when bullet hits an enemy."""
	print("=== PIERCING LOGIC ===")
	print("Bullet piercing value: ", piercing_value)
	
	# Get enemy piercability
	var enemy_piercability = 1.0  # Default
	if enemy.has_method("get_piercability"):
		enemy_piercability = enemy.get_piercability()
	elif enemy.has("piercability"):
		enemy_piercability = enemy.piercability
	
	print("Enemy piercability: ", enemy_piercability)
	
	# Reduce piercing value by enemy's piercability
	piercing_value = max(0.0, piercing_value - enemy_piercability)
	has_pierced = true
	
	print("Piercing value after hit: ", piercing_value)
	
	# Create piercing impact effect (red to distinguish from regular impacts)
	if TracerManager:
		TracerManager.create_impact(impact_position, Color.RED, 0.15)
	
	# Check if piercing is exhausted
	if piercing_value <= 0.0:
		print("Bullet stopped - piercing exhausted")
		if is_explosive:
			_create_bullet_explosion(impact_position)
		_cleanup_bullet()
		queue_free()
	else:
		print("Bullet continues with ", piercing_value, " piercing power remaining")
		# Area3D naturally passes through - no additional code needed

func _create_environment_impact_effect(position: Vector3):
	"""Create impact effect when bullet hits environment (walls, floor, etc.)."""
	print("Creating impact effect at: ", position)
	
	# Use TracerManager to create impact effect
	if TracerManager:
		TracerManager.create_impact(position, Color.YELLOW, 0.25)
	
	print("Impact effect created and should be visible!")



func _create_bullet_explosion(position: Vector3):
	"""Create explosion effect from bullet impact."""
	if not is_explosive or explosion_radius <= 0.0:
		return
	
	#print("BULLET EXPLOSION at ", position, " - Radius: ", explosion_radius, " Damage: ", explosion_damage)
	
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
			
			#print("Bullet explosion damaged ", enemy.name, " for ", final_damage, " damage (distance: ", "%.1f" % distance, ")")
			enemy.take_damage(final_damage)



func _create_bullet_explosion_visual(position: Vector3):
	"""Create visual explosion effect at bullet impact position."""
	# Use TracerManager to create explosion effect
	if TracerManager:
		TracerManager.create_explosion(position, explosion_radius)



# === UTILITY FUNCTIONS ===
func get_tracer_color() -> Color:
	"""Get the tracer color for this bullet."""
	return tracer_color
