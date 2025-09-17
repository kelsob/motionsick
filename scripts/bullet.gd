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

## === EXPORTED CONFIGURATION ===
@export_group("Basic Properties")
## Base speed for bullet movement
@export var base_speed: float = 20.0
## Maximum time bullet can exist before self-destructing
@export var lifetime: float = 30.0
## Travel behavior type for this bullet
@export var travel_type: TravelType = TravelType.CONSTANT_FAST

@export_group("Time System Integration")
## Time resistance (0.0 = fully affected by time, 1.0 = immune to time effects)
@export var time_resistance: float = 0.0

@export_group("Visual Properties")
## Tracer color for this bullet
@export var tracer_color: Color = Color.YELLOW
## Spinning speed in degrees per second around z-axis
@export var spin_speed: float = 720.0

@export_group("Travel Behavior Settings")
## Maximum speed the bullet can reach
@export var max_speed: float = 40.0
## Minimum speed the bullet can have
@export var min_speed: float = 5.0
## Acceleration rate for speed changes (units/second²)
@export var acceleration_rate: float = 60.0
## Deceleration rate for speed changes (units/second²)
@export var deceleration_rate: float = 30.0
## Frequency of speed pulses for PULSE_SPEED travel type (pulses per second)
@export var pulse_frequency: float = 3.0
## Delay before hitscan activation for DELAYED_HITSCAN travel type (seconds)
@export var hitscan_delay: float = 0.1

@export_group("Bounce Properties")
## Whether this bullet can bounce off surfaces
@export var can_bounce: bool = false
## Maximum number of bounces before bullet dies
@export var max_bounces: int = 3
## Energy lost per bounce (0.0 = no loss, 1.0 = all energy lost)
@export_range(0.0, 1.0) var bounce_energy_loss: float = 0.2

@export_group("Combat Properties")
## Default damage value for this bullet
@export var default_damage: int = 25
## Default knockback force applied to targets
@export var default_knockback: float = 1.0

@export_group("Recall System")
## Speed multiplier when bullet is being recalled to player
@export var recall_speed_multiplier: float = 2.0
## How fast bullet turns toward player during recall (0.0-1.0, higher = faster)
@export_range(0.0, 1.0) var recall_turn_speed: float = 0.8
## Distance from player position to target when recalling (Y offset)
@export var recall_target_offset_y: float = 1.0
## Distance at which recalled bullet is considered to have reached player
@export var recall_completion_distance: float = 1.5

@export_group("Collision Detection")
## Hitscan maximum range for instant travel bullets
@export var hitscan_max_range: float = 1000.0
## Environment collision layer bit value
@export var environment_collision_mask: int = 4
## Enemy collision layer bit value  
@export var enemy_collision_mask: int = 128
## Player collision layer bit value
@export var player_collision_mask: int = 1

@export_group("Effects and Visual")
## Effect duration for impact effects
@export var impact_effect_duration: float = 0.25
## Effect duration for bounce impact effects
@export var bounce_effect_duration: float = 0.2
## Effect duration for piercing impact effects
@export var pierce_effect_duration: float = 0.15

@export_group("Curve Acceleration Settings")
## Time to reach maximum speed for CURVE_ACCELERATE travel type
@export var curve_acceleration_time: float = 1.0

@export_group("Safety and Collision Prevention")
## Distance to move bullet away from surfaces after deflection
@export var deflection_safety_distance: float = 0.3
## Minimum check distance for surface tunneling prevention
@export var tunneling_check_distance: float = 0.5
## Corner detection radius for bounce calculations
@export var corner_detection_radius: float = 0.5
## Maximum corner detection distance for emergency situations
@export var corner_danger_distance: float = 0.3
## Distance to check ahead for immediate corner collisions
@export var corner_check_distance: float = 0.2
## Small offset from wall after corner bounce
@export var corner_bounce_offset: float = 0.1

@export_group("Debug Settings")
## Enable debug output for explosion events
@export var debug_explosions: bool = false
## Enable debug output for piercing events  
@export var debug_piercing: bool = false
## Enable debug output for bounce events
@export var debug_bouncing: bool = false
## Enable debug output for deflection events
@export var debug_deflection: bool = false
## Enable debug output for collision events
@export var debug_collisions: bool = false
## Enable debug output for recall events
@export var debug_recall: bool = false

## === RUNTIME STATE ===
# Timing and lifecycle
var life_timer: float = 0.0
var has_been_fired: bool = false
var has_hit_target: bool = false

# References
var gun_reference: Node3D = null
var muzzle_marker: Node3D = null
var shooter: Node = null
var time_affected: TimeAffected = null

# Combat properties (runtime)
var damage: int = 25
var knockback: float = 1.0
var is_player_bullet: bool = false

# Tracer system
var tracer_id: int = -1

# Explosion properties (runtime)
var is_explosive: bool = false
var explosion_radius: float = 0.0
var explosion_damage: int = 0

# Piercing properties (runtime)
var piercing_value: float = 0.0
var has_pierced: bool = false

# Recall properties (runtime)
var is_being_recalled: bool = false
var recall_target_position: Vector3 = Vector3.ZERO

# Deflection properties (runtime)
var has_been_deflected: bool = false

# Bounce properties (runtime)
var current_bounces: int = 0

# Bounce exclusion system
var bounce_exclusion_array: Array = []
var bounce_exclusion_positions: Dictionary = {}  # body -> position

# Travel behavior state (runtime)
var current_speed: float = 0.0
var travel_direction: Vector3 = Vector3.ZERO
var initial_position: Vector3 = Vector3.ZERO
var hitscan_timer: float = 0.0

# Gravity constant (same as player)
@onready var GRAVITY: float = ProjectSettings.get_setting("physics/3d/default_gravity")

@onready var forward_raycast : RayCast3D = $Raycasts/ForwardRayCast3D
@onready var backward_raycast : RayCast3D = $Raycasts/BackwardRayCast3D
@onready var left_raycast : RayCast3D = $Raycasts/LeftRayCast3D
@onready var right_raycast : RayCast3D = $Raycasts/RightRayCast3D
@onready var up_raycast : RayCast3D = $Raycasts/UpRayCast3D
@onready var down_raycast : RayCast3D = $Raycasts/DownRayCast3D

# === SELF-ANIMATING EFFECTS SYSTEM ===
# Effects now animate themselves using timers instead of relying on bullet's _process

func _ready():
	# Initialize runtime values from defaults
	damage = default_damage
	knockback = default_knockback
	
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

func _process(delta):
	# If not fired yet, track the gun's muzzle position and rotation (ONLY FOR PLAYER BULLETS!)
	if not has_been_fired and muzzle_marker and is_player_bullet:
		global_position = muzzle_marker.global_position
		global_rotation = muzzle_marker.global_rotation
		return

func _physics_process(delta):
	# Skip if we're tracking muzzle in _process
	if not has_been_fired and muzzle_marker and is_player_bullet:
		return
	
	# Update bounce exclusion list
	if bounce_exclusion_array.size() > 0:
		var bodies_to_remove = []
		
		for excluded_body in bounce_exclusion_array:
			if not is_instance_valid(excluded_body):
				bodies_to_remove.append(excluded_body)
				continue
				
			# Check if we're still overlapping with this body
			var still_overlapping = false
			var overlapping_bodies = get_overlapping_bodies()
			
			for body in overlapping_bodies:
				if body == excluded_body:
					still_overlapping = true
					break
			
			# Calculate distance from bounce point
			var distance = 999.0  # Large default
			if bounce_exclusion_positions.has(excluded_body):
				var bounce_pos = bounce_exclusion_positions[excluded_body]
				distance = global_position.distance_to(bounce_pos)
			
			# SAFETY: Keep excluded if overlapping OR too close to bounce point
			var min_safe_distance = 0.5  # Minimum distance before considering removal
			
			if still_overlapping or distance < min_safe_distance:
				if debug_bouncing:
					print("EXCLUSION: Maintaining exclusion for ", excluded_body.name, 
						" (overlapping: ", still_overlapping, ", distance: ", distance, ")")
			else:
				# Not overlapping AND far enough away, safe to remove
				bodies_to_remove.append(excluded_body)
				if debug_bouncing:
					print("EXCLUSION: Removing ", excluded_body.name, " from exclusion",
						" (no overlap, distance: ", distance, " > ", min_safe_distance, ")")
		
		# Remove bodies that are no longer excluded
		for body in bodies_to_remove:
			bounce_exclusion_array.erase(body)
			if bounce_exclusion_positions.has(body):
				bounce_exclusion_positions.erase(body)
		
		if debug_bouncing and bodies_to_remove.size() > 0:
			print("EXCLUSION ARRAY after cleanup: ", _get_exclusion_array_names())

	
	# Only count lifetime after being fired
	if has_been_fired:
		# Use time-adjusted delta for lifetime and travel behavior
		var time_delta = time_affected.get_time_adjusted_delta(delta) if time_affected else delta
		
		life_timer += time_delta
		if life_timer > lifetime:
			# Create impact effect when bullet times out
			_create_environment_impact_effect(global_position)
			_cleanup_bullet()
			queue_free()
		
		# Handle travel behavior with time-adjusted delta
		_update_travel_behavior(time_delta)
		
		# Manual movement for Area3D
		if travel_type != TravelType.HITSCAN:
			var time_scale = time_affected.get_effective_time_scale() if time_affected else 1.0
			
			# Handle recalled bullet movement
			if is_being_recalled:
				_update_recalled_movement(time_scale, time_delta)
			else:
				# Normal bullet movement
				var movement = travel_direction * current_speed * time_scale * time_delta
				var old_pos = global_position
				global_position += movement
				

		
		# Apply spinning rotation around z-axis (respects time scale)
		if spin_speed > 0.0:
			var effective_time_scale = time_affected.get_effective_time_scale() if time_affected else 1.0
			var spin_delta = deg_to_rad(spin_speed) * effective_time_scale * time_delta
			rotate_object_local(Vector3.FORWARD, spin_delta)



func set_gun_reference(gun: Node3D, muzzle: Node3D):
	gun_reference = gun
	muzzle_marker = muzzle

func set_spawn_point(spawn_marker: Node3D):
	"""Set bullet position and rotation from enemy spawn point marker."""
	if spawn_marker:
		global_position = spawn_marker.global_position
		global_rotation = spawn_marker.global_rotation

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

func set_spin_speed(speed: float):
	"""Set the spinning speed for this bullet (degrees per second)."""
	spin_speed = max(0.0, speed)

func set_as_player_bullet():
	"""Mark this bullet as fired by the player (enables recall ability)."""
	is_player_bullet = true

func set_as_enemy_bullet():
	"""Mark this bullet as fired by an enemy."""
	is_player_bullet = false
	
	# Clear muzzle tracking for enemy bullets - they should NOT follow gun muzzles
	muzzle_marker = null
	gun_reference = null
	
	# Ensure enemy bullets can hit other enemies (friendly fire)
	# Add enemy layer (bit 7, value 128) to collision mask if not already present
	if (collision_mask & 128) == 0:
		collision_mask |= 128

func set_shooter(shooting_entity: Node):
	"""Set the entity that fired this bullet for self-collision prevention."""
	shooter = shooting_entity

func recall_to_player():
	"""Start recalling this bullet back to the player."""
	if not has_been_fired or has_hit_target or not is_player_bullet:
		return false  # Can't recall unfired, already hit, or non-player bullets
	
	is_being_recalled = true
	
	# Find player position
	var player = get_tree().get_first_node_in_group("player")
	if player:
		recall_target_position = player.global_position + Vector3(0, recall_target_offset_y, 0)
		return true
	else:
		if debug_recall:
			print("WARNING: Could not find player for bullet recall")
		is_being_recalled = false
		return false

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
	
	# Notify TracerManager that bullet was fired (for recall system)
	if TracerManager and tracer_id != -1:
		TracerManager.notify_bullet_fired(tracer_id)
	
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
			var progress = min(1.0, life_timer / curve_acceleration_time)
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

func _update_recalled_movement(time_scale: float, time_delta: float):
	"""Handle movement when bullet is being recalled to player."""
	# Update player position continuously
	var player = get_tree().get_first_node_in_group("player")
	if player:
		recall_target_position = player.global_position + Vector3(0, recall_target_offset_y, 0)
	else:
		# Player not found, stop recall
		is_being_recalled = false
		return
	
	# Calculate direction to player
	var to_player = (recall_target_position - global_position).normalized()
	
	# Turn toward player FAST
	travel_direction = travel_direction.lerp(to_player, recall_turn_speed).normalized()
	
	# Move faster when recalled
	var recall_speed = current_speed * recall_speed_multiplier
	var movement = travel_direction * recall_speed * time_scale * time_delta
	global_position += movement
	
	# Check if bullet reached player
	var distance_to_player = global_position.distance_to(recall_target_position)
	if distance_to_player < recall_completion_distance:
		_handle_bullet_return_to_player()

func _handle_bullet_return_to_player():
	"""Handle what happens when recalled bullet reaches the player."""
	# Give player back ammo
	var player = get_tree().get_first_node_in_group("player")
	if player and player.gun and player.gun.has_method("add_ammo"):
		player.gun.add_ammo(1)
	
	# Clean up and destroy bullet
	_cleanup_bullet()
	queue_free()

func _fire_hitscan():
	"""Instant travel implementation with visual effects."""
	var start_pos = global_position
	
	# Cast ray to find hit point
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		start_pos,
		start_pos + travel_direction * hitscan_max_range
	)
	
	# Combine collision masks for environment, enemies, and player
	query.collision_mask = environment_collision_mask + enemy_collision_mask + player_collision_mask
	query.exclude = [get_tree().get_first_node_in_group("player")]  # Exclude player
	

	
	var result = space_state.intersect_ray(query)
	var end_pos: Vector3
	var hit_body = null
	
	if result:
		end_pos = result.position
		hit_body = result.collider

		
		# Move to hit position
		global_position = result.position
	else:
		# No hit, travel max distance
		end_pos = start_pos + travel_direction * hitscan_max_range
		global_position = end_pos
	
	# Visual effects handled by TracerManager
	
	# Handle collision if we hit something
	if hit_body:
		if debug_collisions:
			print("Attempting to apply damage to: ", hit_body.name)
		# Apply damage directly for hitscan
		if hit_body.has_method("take_damage"):
			if debug_collisions:
				print("SUCCESS: Applying hitscan damage: ", damage)
			hit_body.take_damage(damage)
		has_hit_target = true
		_cleanup_bullet()
		queue_free()
	else:
		if debug_collisions:
			print("No damage to apply - no target hit")
		_cleanup_bullet()
		queue_free()
	


# Tracer visuals handled by TracerManager

# Material configuration removed - using different bullet scenes instead

func _cleanup_bullet():
	"""Clean up bullet resources including tracer registration."""
	# Unregister from tracer system
	if TracerManager and tracer_id != -1:
		TracerManager.unregister_bullet(tracer_id)
		tracer_id = -1

func _on_body_entered(body):
	# Force ShapeCast update at the very start of collision handling
	var shapecast = get_node_or_null("ShapeCast3D")
	if shapecast:
		shapecast.force_shapecast_update()
		if debug_bouncing:
			print("COLLISION: Force-updated ShapeCast3D at _on_body_entered start.")
	
	# Debug: Always print exclusion state at collision entry
	if debug_bouncing:
		print("\n=== COLLISION DETECTED ===")
		print("Body: ", body.name)
		print("EXCLUSION ARRAY: ", _get_exclusion_array_names())
		print("Bullet position: ", global_position)
		print("Bullet direction: ", travel_direction)
		print("Current bounces: ", current_bounces, "/", max_bounces)
	
	# Check if this body is in our exclusion list
	if body in bounce_exclusion_array:
		if debug_bouncing:
			print("EXCLUSION: IGNORING collision with ", body.name, " (in exclusion list)")
			if bounce_exclusion_positions.has(body):
				var bounce_pos = bounce_exclusion_positions[body]
				var distance = global_position.distance_to(bounce_pos)
				print("  Distance from original bounce: ", distance)
		return
	
	# Check if we hit an enemy first (has take_damage method)
	if body.has_method("take_damage"):
		# Check if this is friendly fire (enemy bullet hitting enemy)
		var is_enemy_target = body.is_in_group("enemies")
		var is_player_target = body.is_in_group("player")
				
		# Determine if we should damage this target
		var should_damage = false
		
		if is_player_bullet and is_enemy_target:
			# Player bullet hitting enemy - always damage
			should_damage = true
		elif is_player_bullet and is_player_target:
			# Player bullet hitting player - no damage (shouldn't happen but safe)
			should_damage = false
		elif not is_player_bullet and is_enemy_target:
			# Enemy bullet hitting another enemy - FRIENDLY FIRE!
			should_damage = true
		elif not is_player_bullet and is_player_target:
			# Enemy bullet hitting player - always damage
			should_damage = true
		else:
			# Unknown combination - default to damage
			should_damage = true
		
		if should_damage:
			var damage_applied = body.take_damage(damage)
			# If damage was prevented on player (time dilation), don't free the bullet
			if is_player_target and damage_applied == false:  # Explicitly check for false
				if debug_collisions:
					print("⏰ BULLET: Player damage prevented, bullet continues")
				return  # Don't free bullet, let it continue
			
			# Apply knockback if enemy supports it
			if body.has_method("apply_knockback"):
				var knockback_direction = travel_direction.normalized()
				body.apply_knockback(knockback_direction, knockback)

		
		is_being_recalled = false  # Stop any active recall
		
		# Handle piercing logic (regardless of damage)
		if piercing_value > 0.0:
			if debug_piercing:
				print("IMPACT Piercing through target, continuing bullet")
			_handle_piercing(body, global_position)
			# DON'T set has_hit_target = true for piercing bullets - they should remain deflectable
		else:
			# No piercing - mark as hit and destroy bullet
			has_hit_target = true
			if is_explosive:
				_create_bullet_explosion(global_position)
			_cleanup_bullet()
			queue_free()
		return  # Done with target collision
	
	# Check if we hit environment (walls/floor) - only if not an enemy
	elif _is_environment(body):
		if debug_bouncing:
			print("COLLISION: Hit environment body: ", body.name)
			print("COLLISION: Can bounce: ", can_bounce, " Current bounces: ", current_bounces, "/", max_bounces)
		
		# Use ShapeCast3D for precise collision detection
		var impact_data = _find_shapecast_impact(body)
		
		if debug_bouncing:
			print("COLLISION: Impact data keys: ", impact_data.keys())
			if impact_data.has("position"):
				print("COLLISION: Impact position: ", impact_data.position)
			if impact_data.has("normal"):
				print("COLLISION: Impact normal: ", impact_data.normal)
		
		# Store the collision shape we just hit for later comparison
		if impact_data.has("shape_index"):
			set_meta("bounced_from_shape", impact_data.shape_index)
		
		# Check for detonation fallback first
		if impact_data.has("detonate") and impact_data.detonate:
			if debug_bouncing:
				print("COLLISION: Detonation triggered by impact data")
			_create_environment_impact_effect(impact_data.position)
			has_hit_target = true
			_cleanup_bullet()
			queue_free()
			return
		
		if impact_data.has("position") and impact_data.has("normal"):
			if debug_bouncing:
				print("COLLISION: Valid impact data found, checking bounce conditions")
			
			# Create wall ripple effect
			_create_wall_ripple(impact_data.position, impact_data.normal)
			
			# Try bouncing if bouncing is enabled  
			if can_bounce and current_bounces <= max_bounces:
				if debug_bouncing:
					print("COLLISION: Bouncing enabled and under max bounces - calling _handle_vertex_bounce")
				_handle_vertex_bounce(impact_data.position, impact_data.normal, body)
				return  # Don't destroy bullet - let it continue bouncing
			else:
				if debug_bouncing:
					print("COLLISION: Bouncing disabled or at max bounces - destroying bullet")
					print("COLLISION: can_bounce=", can_bounce, " current_bounces=", current_bounces, " max_bounces=", max_bounces)
				# Create impact effect when bullet stops
				_create_environment_impact_effect(impact_data.position)
				# Mark as hit and cleanup
				has_hit_target = true
				_cleanup_bullet()
				queue_free()
				return
		else:
			if debug_bouncing:
				print("VERTEX IMPACT could not determine precise impact")
			
			# Create wall ripple with fallback data
			_create_wall_ripple_fallback(body)
			
			# Fallback - try simple bounce if we're supposed to bounce
			if debug_bouncing:
				print("BOUNCE CHECK (fallback): current_bounces=", current_bounces, " max_bounces=", max_bounces, " can_bounce=", can_bounce)
			if can_bounce and current_bounces <= max_bounces:
				if debug_bouncing:
					print("VERTEX FALLBACK: Attempting simple bounce without vertex data")
				_handle_simple_fallback_bounce()
				return  # Don't destroy bullet
			else:
				# Create impact effect when bullet stops (fallback)
				_create_environment_impact_effect(global_position)
				# Mark as hit and cleanup
				has_hit_target = true
				_cleanup_bullet()
				queue_free()
				return
		
		# Environment hit but no bouncing - stop bullet
		if debug_collisions:
			print("IMPACT Environment hit - stopping bullet")
		if is_explosive:
			_create_bullet_explosion(global_position)
		else:
			# Create impact effect for final collision
			_create_environment_impact_effect(global_position)
		has_hit_target = true
		_cleanup_bullet()
		queue_free()
		
	# If we get here, unknown collision - stop the bullet
	else:
		if debug_collisions:
			print("IMPACT Unknown collision with: ", body.name, " - stopping bullet")
		# Create impact effect for unknown collision
		_create_environment_impact_effect(global_position)
		has_hit_target = true
		_cleanup_bullet()
		queue_free()
	
	if debug_collisions:
		print("=== END COLLISION INFO ===")

func _handle_vertex_bounce(impact_position: Vector3, surface_normal: Vector3, bounced_from_body: Node3D):
	"""Handle bouncing using multi-collision approach for corners."""
	if debug_bouncing:
		print("\n=== VERTEX BOUNCE START ===")
		print("EXCLUSION ARRAY before bounce: ", _get_exclusion_array_names())
	
	# Get ShapeCast3D for multi-collision detection
	var shapecast = get_node_or_null("ShapeCast3D")
	if not shapecast:
		if debug_bouncing:
			print("BOUNCE: No ShapeCast3D found, using single bounce")
		_handle_single_surface_bounce(surface_normal, bounced_from_body)
		return
	
	# Force update to get all current collisions
	shapecast.force_shapecast_update()
	var collision_count = shapecast.get_collision_count()
	
	if debug_bouncing:
		print("MULTI-BOUNCE: Starting multi-collision bounce")
		print("MULTI-BOUNCE: Collision count: ", collision_count)
		print("MULTI-BOUNCE: Original direction: ", travel_direction)
	
	# If only one collision, use simple bounce
	if collision_count <= 1:
		_handle_single_surface_bounce(surface_normal, bounced_from_body)
		return
	
	# MULTI-COLLISION HANDLING
	# Collect all collision data and sort by distance
	var collisions = []
	for i in range(collision_count):
		var col_point = shapecast.get_collision_point(i)
		var col_normal = shapecast.get_collision_normal(i)
		var col_object = shapecast.get_collider(i)
		var col_distance = global_position.distance_to(col_point)
		
		# Skip if this object is in the exclusion array
		if col_object in bounce_exclusion_array:
			if debug_bouncing:
				print("MULTI-BOUNCE: Skipping excluded body: ", col_object.name)
			continue
		
		# Only process environment collisions
		if _is_environment(col_object):
			collisions.append({
				"point": col_point,
				"normal": col_normal,
				"object": col_object,
				"distance": col_distance
			})
	
	# Sort by distance (closest first)
	collisions.sort_custom(func(a, b): return a.distance < b.distance)
	
	if debug_bouncing:
		print("MULTI-BOUNCE: Processing ", collisions.size(), " environment collisions (after exclusion)")
		for i in range(collisions.size()):
			var col = collisions[i]
			print("  Collision ", i, ": ", col.object.name, " at distance ", "%.3f" % col.distance, " normal: ", col.normal)
	
	# If no valid collisions after filtering, fall back to single bounce
	if collisions.is_empty():
		if debug_bouncing:
			print("MULTI-BOUNCE: No valid collisions after exclusion filtering")
		_handle_single_surface_bounce(surface_normal, bounced_from_body)
		return

	# Process all collisions to get final trajectory
	var current_direction = travel_direction.normalized()
	var total_energy_loss = 0.0
	
	# Iterate through each collision and adjust trajectory
	for i in range(collisions.size()):
		var col = collisions[i]
		var incident = current_direction
		var normal = col.normal.normalized()
		
		# Check if normal might be inverted (pointing into the surface instead of out)
		# This can happen with some collision shapes or edge cases
		var to_bullet = (global_position - col.point).normalized()
		var normal_dot_to_bullet = normal.dot(to_bullet)
		
		# If normal is pointing away from bullet (negative dot), it might be inverted
		if normal_dot_to_bullet < -0.1:
			if debug_bouncing:
				print("MULTI-BOUNCE: Detected inverted normal, flipping it")
				print("  Original normal: ", normal)
			normal = -normal
			if debug_bouncing:
				print("  Flipped normal: ", normal)
		
		var dot_product = incident.dot(normal)
		
		if debug_bouncing:
			print("MULTI-BOUNCE: Collision ", i, " dot product: ", dot_product)
			print("  Incident: ", incident)
			print("  Normal: ", normal)
			print("  Normal dot to bullet: ", normal_dot_to_bullet)
		
		# Always reflect, regardless of dot product sign
		# This handles edge cases like hitting undersides of surfaces
		var reflected = incident - 2.0 * dot_product * normal
		current_direction = reflected.normalized()
		
		# Accumulate energy loss
		total_energy_loss += bounce_energy_loss * (1.0 - total_energy_loss)
		
		if debug_bouncing:
			print("MULTI-BOUNCE: Bounce ", i, " - reflected: ", current_direction)
	
	# Apply final trajectory
	travel_direction = current_direction
	current_bounces += 1
	current_speed *= (1.0 - total_energy_loss)
	
	# Move bullet slightly away from all surfaces
	var safety_offset = Vector3.ZERO
	for col in collisions:
		if col.distance < 0.2:  # Very close to surface
			safety_offset += col.normal * 0.05
	
	global_position += safety_offset
	
	# Update orientation
	if travel_direction.length() > 0.01:
		var up_vector = Vector3.UP
		if abs(travel_direction.dot(Vector3.UP)) > 0.99:
			up_vector = Vector3.FORWARD
		look_at(global_position + travel_direction, up_vector)
	
	if debug_bouncing:
		print("MULTI-BOUNCE: Final direction: ", travel_direction)
		print("MULTI-BOUNCE: Final position: ", global_position)
		print("MULTI-BOUNCE: Total energy loss: ", total_energy_loss)
		print("MULTI-BOUNCE: Bounce count: ", current_bounces, "/", max_bounces)
	
	# Add ALL collided bodies to exclusion list
	for col in collisions:
		if not col.object in bounce_exclusion_array:
			bounce_exclusion_array.append(col.object)
			bounce_exclusion_positions[col.object] = col.point
			if debug_bouncing:
				print("EXCLUSION: Added ", col.object.name, " to exclusion list at position ", col.point)
	
	if debug_bouncing:
		print("EXCLUSION ARRAY after bounce: ", _get_exclusion_array_names())
		print("=== VERTEX BOUNCE END ===\n")

func _handle_single_surface_bounce(surface_normal: Vector3, bounced_from_body: Node3D):
	"""Handle simple single-surface bounce."""
	if debug_bouncing:
		print("\n=== SINGLE BOUNCE START ===")
		print("EXCLUSION ARRAY before bounce: ", _get_exclusion_array_names())
	
	var original_direction = travel_direction.normalized()
	
	if debug_bouncing:
		print("SINGLE BOUNCE: Starting bounce calculation")
		print("SINGLE BOUNCE: Original trajectory: ", original_direction)
		print("SINGLE BOUNCE: Surface normal: ", surface_normal)
	
	# Calculate reflection
	var incident_direction = travel_direction.normalized()
	var dot_product = incident_direction.dot(surface_normal)
	var reflected_direction = incident_direction - 2.0 * dot_product * surface_normal
	
	# Update bullet properties
	var old_position = global_position
	var old_speed = current_speed
	
	# Apply small safety offset
	var safety_offset = surface_normal * 0.05
	global_position = old_position + safety_offset
	travel_direction = reflected_direction.normalized()
	current_bounces += 1
	current_speed *= (1.0 - bounce_energy_loss)
	
	# Update orientation
	if travel_direction.length() > 0.01:
		var up_vector = Vector3.UP
		if abs(travel_direction.dot(Vector3.UP)) > 0.99:
			up_vector = Vector3.FORWARD
		look_at(global_position + travel_direction, up_vector)
	
	if debug_bouncing:
		print("SINGLE BOUNCE: Direction change: ", original_direction, " -> ", travel_direction)
		print("SINGLE BOUNCE: Speed change: ", old_speed, " -> ", current_speed)
		print("SINGLE BOUNCE: Bounce count: ", current_bounces, "/", max_bounces)
	
	# Add to exclusion list
	if not bounced_from_body in bounce_exclusion_array:
		bounce_exclusion_array.append(bounced_from_body)
		bounce_exclusion_positions[bounced_from_body] = global_position
		if debug_bouncing:
			print("EXCLUSION: Added ", bounced_from_body.name, " to exclusion list at position ", global_position)
	
	if debug_bouncing:
		print("EXCLUSION ARRAY after bounce: ", _get_exclusion_array_names())
		print("=== SINGLE BOUNCE END ===\n")

func _handle_corner_bounce_check():
	"""Removed - no longer needed with multi-collision approach."""
	pass

func _handle_emergency_corner_bounce(hit_body: Node3D):
	"""Removed - no longer needed with multi-collision approach."""
	pass

func _handle_simple_fallback_bounce():
	"""Smart fallback bounce when vertex raycasts fail - works for floors AND walls."""


	
	# SMART NORMAL DETECTION: Cast a ray in travel direction to find surface normal
	var space_state = get_world_3d().direct_space_state
	var ray_start = global_position - travel_direction.normalized() * 0.3
	var ray_end = global_position + travel_direction.normalized() * 0.3
	
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collision_mask = environment_collision_mask
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	var surface_normal: Vector3
	
	if result and result.has("normal"):
		surface_normal = result.normal
	else:
		# Ultimate fallback - assume floor
		surface_normal = Vector3.UP
	
	# Calculate reflection using the detected/assumed normal
	var incident_direction = travel_direction.normalized()
	var dot_product = incident_direction.dot(surface_normal)
	var reflected_direction = incident_direction - 2.0 * dot_product * surface_normal
	
		# ATOMIC UPDATE: Update properties and orientation atomically to prevent tracer artifacts
	travel_direction = reflected_direction.normalized()
	current_bounces += 1
	current_speed *= (1.0 - bounce_energy_loss)
	
	# Update orientation immediately as part of atomic update
	if travel_direction.length() > 0.01:
		var up_vector = Vector3.UP
		if abs(travel_direction.dot(Vector3.UP)) > 0.99:
			up_vector = Vector3.FORWARD
		look_at(global_position + travel_direction, up_vector)
	
	if debug_bouncing:
		print("FALLBACK Smart bounce complete - new direction: ", travel_direction)
		print("FALLBACK New position: ", global_position)
	
	# CORNER HANDLING: Check for additional bounces after fallback bounce
	_handle_corner_bounce_check()

func _is_environment(body: Node3D) -> bool:
	"""Check if the body is environment (walls, floors, etc.) based on collision layer."""
	return (body.collision_layer & environment_collision_mask) != 0

func _get_surface_impact_position(hit_body: Node3D) -> Vector3:
	"""Calculate the actual surface impact position using raycast with debugging."""
	#print("BOUNCE === IMPACT POSITION CALCULATION ===")
	#print("BOUNCE Hit body: ", hit_body.name)
	#print("BOUNCE Bullet position: ", global_position)
	#print("BOUNCE Travel direction: ", travel_direction)
	
	# Cast a ray from slightly behind the bullet to slightly ahead to find surface intersection
	var space_state = get_world_3d().direct_space_state
	var ray_start = global_position - travel_direction * 0.5  # Start slightly behind bullet
	var ray_end = global_position + travel_direction * 0.5    # End slightly ahead
	
	#print("BOUNCE Impact raycast start: ", ray_start)
	#print("BOUNCE Impact raycast end: ", ray_end)
	#print("BOUNCE Impact raycast direction: ", (ray_end - ray_start).normalized())
	
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collision_mask = hit_body.collision_layer  # Only hit the specific body
	query.exclude = [self]  # Don't hit the bullet itself
	
	#print("BOUNCE Impact raycast mask: ", query.collision_mask)
	#print("BOUNCE Hit body layer: ", hit_body.collision_layer)
	
	var result = space_state.intersect_ray(query)
	
	if result and result.collider == hit_body:
		# Found the exact surface hit point
		#print("BOUNCE Impact position found via raycast: ", result.position)
		#print("BOUNCE Impact normal from raycast: ", result.normal)
		return result.position
	else:
		# Fallback: move bullet position slightly back along travel direction
		var fallback_position = global_position - travel_direction.normalized() * 0.1
		return fallback_position

func _handle_piercing(enemy: Node3D, impact_position: Vector3):
	"""Handle piercing logic when bullet hits an enemy."""
	if debug_piercing:
		print("=== PIERCING LOGIC ===")
		print("Bullet piercing value: ", piercing_value)
	
	# Get enemy piercability
	var enemy_piercability = 1.0  # Default
	if enemy.has_method("get_piercability"):
		enemy_piercability = enemy.get_piercability()
	elif enemy.has("piercability"):
		enemy_piercability = enemy.piercability
	
	if debug_piercing:
		print("Enemy piercability: ", enemy_piercability)
	
	# Reduce piercing value by enemy's piercability
	piercing_value = max(0.0, piercing_value - enemy_piercability)
	has_pierced = true
	
	if debug_piercing:
		print("Piercing value after hit: ", piercing_value)
	
	# Create piercing impact effect (red to distinguish from regular impacts)
	if TracerManager:
		TracerManager.create_impact(impact_position, Color.RED, pierce_effect_duration)
	
	# Check if piercing is exhausted
	if piercing_value <= 0.0:
		if debug_piercing:
			print("Bullet stopped - piercing exhausted")
		if is_explosive:
			_create_bullet_explosion(impact_position)
		_cleanup_bullet()
		queue_free()


func _get_collision_normal_direct(surface_body: Node3D, impact_position: Vector3) -> Vector3:
	"""Get collision normal using a direct raycast at the impact position - WORKS FOR ANY SURFACE."""
	#print("BOUNCE === DIRECT COLLISION NORMAL ===")
	var space_state = get_world_3d().direct_space_state
	
	# PERFECT LOGIC: Cast ray in the OPPOSITE direction of bullet travel
	# This ensures we hit the surface we just collided with, regardless of orientation
	var ray_distance = 0.5
	var ray_start = impact_position - travel_direction.normalized() * ray_distance  # Start behind impact (where bullet came from)
	var ray_end = impact_position + travel_direction.normalized() * ray_distance    # End ahead of impact (where bullet was going)
	
	#print("BOUNCE Direct normal raycast - start: ", ray_start)
	#print("BOUNCE Direct normal raycast - end: ", ray_end)
	#print("BOUNCE Raycast direction (bullet travel): ", travel_direction.normalized())
	
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collision_mask = surface_body.collision_layer
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	
	if result and result.collider == surface_body:
		#print("BOUNCE SUCCESS: Got collision normal directly: ", result.normal)
		#print("BOUNCE Normal type: ", "Floor" if abs(result.normal.y) > 0.7 else "Wall")
		return result.normal
	else:
		#print("BOUNCE FAILED: Direct raycast missed, will use fallback")
		return Vector3.ZERO  # Signal to use fallback

func _handle_surface_bounce(surface_body: Node3D, impact_position: Vector3, direct_normal: Vector3 = Vector3.ZERO):
	"""Handle bullet bouncing off a surface with EXTENSIVE debugging."""
	#print("BOUNCE ================================")
	#print("BOUNCE === BOUNCE ATTEMPT #", current_bounces + 1, " of ", max_bounces, " ===")
	#print("BOUNCE ================================")
	#print("BOUNCE Impact position: ", impact_position)
	#print("BOUNCE Bullet position: ", global_position)
	#print("BOUNCE Travel direction BEFORE: ", travel_direction)
	#print("BOUNCE Travel direction normalized: ", travel_direction.normalized())
	#print("BOUNCE Travel direction length: ", travel_direction.length())
	#print("BOUNCE Current speed: ", current_speed)
	#print("BOUNCE Surface body: ", surface_body.name)
	#print("BOUNCE Surface body class: ", surface_body.get_class())
	#print("BOUNCE Surface collision layer: ", surface_body.collision_layer)
	
	# Get surface normal - use direct normal first, fallback if needed
	var surface_normal: Vector3
	if direct_normal != Vector3.ZERO:
		#print("BOUNCE Using direct collision normal: ", direct_normal)
		surface_normal = direct_normal
	else:
		#print("BOUNCE Using fallback normal detection")
		surface_normal = _get_surface_normal(surface_body, impact_position)
	
	if surface_normal.length() < 0.1:
		#print("BOUNCE ERROR: Could not determine surface normal, stopping bullet")
		#print("BOUNCE Surface normal length: ", surface_normal.length())
		#print("BOUNCE Surface normal value: ", surface_normal)
		has_hit_target = true
		_create_environment_impact_effect(impact_position)
		_cleanup_bullet()
		queue_free()
		return
	
	#print("BOUNCE Surface normal: ", surface_normal)
	#print("BOUNCE Surface normal normalized: ", surface_normal.normalized())
	#print("BOUNCE Surface normal length: ", surface_normal.length())
	
	# Calculate reflection: new_direction = incident - 2 * (incident · normal) * normal
	var incident_direction = travel_direction.normalized()
	#print("BOUNCE Incident direction: ", incident_direction)
	
	var dot_product = incident_direction.dot(surface_normal)
	#print("BOUNCE Dot product (incident · normal): ", dot_product)
	#print("BOUNCE Angle of incidence (degrees): ", rad_to_deg(acos(abs(dot_product))))
	
	var reflection_component = 2.0 * dot_product * surface_normal
	#print("BOUNCE Reflection component (2 * dot * normal): ", reflection_component)
	
	var reflected_direction = incident_direction - reflection_component
	#print("BOUNCE Reflected direction (raw): ", reflected_direction)
	#print("BOUNCE Reflected direction normalized: ", reflected_direction.normalized())
	#print("BOUNCE Reflected direction length: ", reflected_direction.length())
	
	# Validate reflection
	var reflected_dot = reflected_direction.normalized().dot(surface_normal)
	#print("BOUNCE Reflected dot with normal: ", reflected_dot)
	#print("BOUNCE Angle of reflection (degrees): ", rad_to_deg(acos(abs(reflected_dot))))
	
	# Update bullet properties
	travel_direction = reflected_direction.normalized()
	current_bounces += 1
	
	#print("BOUNCE Travel direction AFTER: ", travel_direction)
	#print("BOUNCE Bounce count updated to: ", current_bounces)
	
	# Apply energy loss
	var old_speed = current_speed
	current_speed *= (1.0 - bounce_energy_loss)
	#print("BOUNCE Speed change: ", old_speed, " -> ", current_speed, " (loss: ", bounce_energy_loss, ")")
	

	
	# Orient bullet to new direction
	if travel_direction.length() > 0.01:
		var up_vector = Vector3.UP
		if abs(travel_direction.dot(Vector3.UP)) > 0.99:
			up_vector = Vector3.FORWARD
		#print("BOUNCE Orienting bullet - up_vector: ", up_vector)
		look_at(global_position + travel_direction, up_vector)
		#print("BOUNCE Bullet rotation after look_at: ", global_rotation)
	
	# Create bounce impact effect (different color to show bounce)
	_create_bounce_impact_effect(impact_position)
	
	#print("BOUNCE ================================")
	#print("BOUNCE === BOUNCE COMPLETE ===")
	#print("BOUNCE ================================")

func _get_surface_normal(surface_body: Node3D, impact_position: Vector3) -> Vector3:
	"""Get the surface normal at the impact point using raycast with EXTENSIVE debugging."""
	#print("BOUNCE === SURFACE NORMAL DETECTION ===")
	#print("BOUNCE Impact position: ", impact_position)
	#print("BOUNCE Impact Y value: ", impact_position.y)
	#print("BOUNCE Bullet position: ", global_position)
	#print("BOUNCE Bullet Y value: ", global_position.y)
	#print("BOUNCE Y difference (impact - bullet): ", impact_position.y - global_position.y)
	
	var space_state = get_world_3d().direct_space_state
	
	# BETTER APPROACH: Raycast FROM the impact position to get accurate surface normal
	# This gets the actual normal at the collision point, not some estimated position
	var ray_start = impact_position + travel_direction.normalized() * 0.1  # Start slightly ahead of impact
	var ray_end = impact_position - travel_direction.normalized() * 0.1    # End slightly behind impact
	
	#print("BOUNCE Raycasting FROM impact position for accurate normal")
	#print("BOUNCE Impact position: ", impact_position)
	#print("BOUNCE Raycast for normal - start: ", ray_start)
	#print("BOUNCE Raycast for normal - end: ", ray_end)
	#print("BOUNCE Raycast direction: ", (ray_end - ray_start).normalized())
	#print("BOUNCE Raycast distance: ", ray_start.distance_to(ray_end))
	
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collision_mask = surface_body.collision_layer
	query.exclude = [self]
	
	#print("BOUNCE Raycast collision mask: ", query.collision_mask)
	#print("BOUNCE Surface body collision layer: ", surface_body.collision_layer)
	#print("BOUNCE Mask & Layer match: ", (query.collision_mask & surface_body.collision_layer) != 0)
	
	var result = space_state.intersect_ray(query)
	
	if result and result.collider == surface_body:
		#print("BOUNCE SUCCESS: Surface normal found via raycast")
		#print("BOUNCE Normal: ", result.normal)
		#print("BOUNCE Hit position: ", result.position)
		#print("BOUNCE Hit collider: ", result.collider.name)
		#print("BOUNCE Normal length: ", result.normal.length())
		#print("BOUNCE Normal Y component: ", result.normal.y)
		return result.normal
	else:
		#print("BOUNCE FALLBACK: Using smart fallback normal")

		
		# SIMPLE FALLBACK: Calculate normal from impact position to surface center
		var surface_center = surface_body.global_position
		var surface_name = surface_body.name.to_lower()
		
		#print("BOUNCE Simple fallback - impact to surface center")
		#print("BOUNCE Surface center: ", surface_center)
		#print("BOUNCE Surface name: ", surface_name)
		
		# Calculate vector from surface center to impact point = outward normal direction
		var outward_normal = (impact_position - surface_center).normalized()
		#print("BOUNCE Calculated outward normal: ", outward_normal)
		return outward_normal

func _create_bounce_impact_effect(position: Vector3):
	"""Create impact effect when bullet bounces off a surface."""
	if debug_bouncing:
		print("BOUNCE Creating bounce impact effect at: ", position)
	
	# Use TracerManager to create bounce impact effect (cyan color to distinguish from regular impacts)
	if TracerManager:
		TracerManager.create_impact(position, Color.CYAN, bounce_effect_duration)

func _create_environment_impact_effect(position: Vector3):
	"""Create impact effect when bullet hits environment (walls, floor, etc.)."""
	if debug_collisions:
		print("Creating impact effect at: ", position)
	
	# Use TracerManager to create impact effect
	if TracerManager:
		TracerManager.create_impact(position, Color.YELLOW, impact_effect_duration)
	
	if debug_collisions:
		print("Impact effect created and should be visible!")



func _create_bullet_explosion(position: Vector3):
	"""Create explosion effect from bullet impact."""
	if not is_explosive or explosion_radius <= 0.0:
		return
	
	if debug_explosions:
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
	query.collision_mask = enemy_collision_mask
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var enemy = result.collider
		if enemy.has_method("take_damage"):
			# Calculate distance-based damage falloff
			var distance = explosion_pos.distance_to(enemy.global_position)
			var damage_multiplier = 1.0 - (distance / explosion_radius)  # Linear falloff
			var final_damage = int(explosion_damage * damage_multiplier)
			
			if debug_explosions:
				print("Bullet explosion damaged ", enemy.name, " for ", final_damage, " damage (distance: ", "%.1f" % distance, ")")
			enemy.take_damage(final_damage)



func _create_bullet_explosion_visual(position: Vector3):
	"""Create visual explosion effect at bullet impact position."""
	# Use TracerManager to create explosion effect
	if TracerManager:
		TracerManager.create_explosion(position, explosion_radius)



# === WALL RIPPLE EFFECTS ===

func _create_wall_ripple(impact_position: Vector3, surface_normal: Vector3):
	"""Create wall ripple effect at impact position."""
	# Load the wall ripple scene
	var wall_ripple_scene = load("res://scenes/effects/WallRipple.tscn")
	if not wall_ripple_scene:
		if debug_collisions:
			print("WARNING: Could not load WallRipple.tscn")
		return
	
	# Instantiate the ripple effect
	var ripple = wall_ripple_scene.instantiate()
	get_tree().current_scene.add_child(ripple)
	
	# Setup the ripple position and orientation
	if ripple.has_method("setup_ripple"):
		ripple.setup_ripple(impact_position, surface_normal)
	else:
		# Fallback setup
		ripple.global_position = impact_position
	
	if debug_collisions:
		print("Wall ripple created at: ", impact_position, " with normal: ", surface_normal)

func _create_wall_ripple_fallback(hit_body: Node3D):
	"""Create wall ripple with fallback surface normal calculation."""
	var impact_position = global_position
	
	# Calculate fallback surface normal
	var surface_normal = _get_surface_normal(hit_body, impact_position)
	if surface_normal.length() < 0.1:
		surface_normal = Vector3.UP  # Ultimate fallback
	
	_create_wall_ripple(impact_position, surface_normal)

# === BULLET DEFLECTION SYSTEM ===

func deflect_bullet(new_direction: Vector3, speed_boost: float = 1.0):
	"""Deflect the bullet in a new direction with optional speed boost."""
	if not has_been_fired or has_hit_target:
		return  # Can't deflected unfired or already hit bullets
	
	if debug_deflection:
		print("DEFLECTION: Bullet deflected!")
		print("DEFLECTION: Old direction: ", travel_direction)
		print("DEFLECTION: New direction: ", new_direction)
		print("DEFLECTION: Speed boost: ", speed_boost)
	
	# Change direction
	travel_direction = new_direction.normalized()
	
	# Apply speed boost
	current_speed *= speed_boost
	
	# Mark as deflected
	has_been_deflected = true
	
	# Stop any recall if active
	is_being_recalled = false
	
	# Create BulletDeflect effect at current position
	_create_bullet_deflect_effect(global_position)
	
	# SAFETY CHECK: If deflected toward nearby surface, move bullet away slightly
	_prevent_surface_tunneling_on_deflection()
	
	# Orient bullet to new direction
	if travel_direction.length() > 0.01:
		var up_vector = Vector3.UP
		if abs(travel_direction.dot(Vector3.UP)) > 0.99:
			up_vector = Vector3.FORWARD
		look_at(global_position + travel_direction, up_vector)
	
	if debug_deflection:
		print("DEFLECTION: New speed: ", current_speed)
		print("DEFLECTION: Bullet reoriented")

func _create_bullet_deflect_effect(position: Vector3):
	"""Create BulletDeflect effect when bullet is deflected by player."""
	var deflect_scene = load("res://scenes/effects/BulletDeflect.tscn")
	if not deflect_scene:
		print("WARNING: Could not load BulletDeflect.tscn")
		return
	
	var effect = deflect_scene.instantiate()
	get_tree().current_scene.add_child(effect)
	effect.global_position = position
	
	print("BulletDeflect effect spawned at: ", position)

func _prevent_surface_tunneling_on_deflection():
	"""Prevent bullet from tunneling through surfaces after deflection."""
	# Cast a short ray in the new travel direction to check for immediate collision
	var space_state = get_world_3d().direct_space_state
	var ray_end = global_position + travel_direction * tunneling_check_distance
	
	var query = PhysicsRayQueryParameters3D.create(global_position, ray_end)
	query.collision_mask = environment_collision_mask
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	if result:
		# Surface detected in travel direction - move bullet away from it
		var surface_normal = result.normal
		var safety_offset = surface_normal * deflection_safety_distance
		global_position += safety_offset
		if debug_deflection:
			print("DEFLECTION SAFETY: Moved bullet away from surface by ", safety_offset)

# === UTILITY FUNCTIONS ===
func get_tracer_color() -> Color:
	"""Get the tracer color for this bullet."""
	return tracer_color

# === DEBUG FUNCTIONS ===




func _will_be_inside_geometry(position: Vector3) -> bool:
	"""Check if a position would be inside geometry."""
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 0.1  # Small sphere
	query.shape = sphere
	query.transform.origin = position
	query.collision_mask = environment_collision_mask
	
	var results = space_state.intersect_shape(query)
	return results.size() > 0

func _debug_rapid_bounce_detection():
	"""Track and detect rapid bounces."""
	var current_time = Time.get_time_dict_from_system()
	
	if not has_meta("last_bounce_time"):
		set_meta("last_bounce_time", current_time)
		return
	
	var last_bounce = get_meta("last_bounce_time")
	var time_diff = (current_time.hour * 3600 + current_time.minute * 60 + current_time.second) - \
					(last_bounce.hour * 3600 + last_bounce.minute * 60 + last_bounce.second)
	
	set_meta("last_bounce_time", current_time)

func _calculate_corner_safe_position(impact_position: Vector3, primary_normal: Vector3) -> Vector3:
	"""Calculate a safe position that avoids all nearby walls in corner situations."""
	#print("SAFE === CALCULATING CORNER-SAFE POSITION ===")
	
	# Start with standard positioning
	var base_offset = 0.15
	var safe_position = impact_position + primary_normal * base_offset
	
	# Check for nearby walls and accumulate additional offsets
	var corner_radius = 1.0
	var additional_offset = Vector3.ZERO
	var directions = [
		Vector3.RIGHT, Vector3.LEFT, 
		Vector3.FORWARD, Vector3.BACK,
		Vector3.UP, Vector3.DOWN
	]
	
	var walls_found = 0
	for direction in directions:
		var space_state = get_world_3d().direct_space_state
		var query = PhysicsRayQueryParameters3D.create(
			safe_position, 
			safe_position + direction * corner_detection_radius
		)
		query.collision_mask = environment_collision_mask
		query.exclude = [self]
		
		var result = space_state.intersect_ray(query)
		if result:
			var wall_distance = safe_position.distance_to(result.position)
			var wall_normal = result.normal
			
			# If wall is very close, add offset away from it
			if wall_distance < corner_danger_distance:
				var safety_offset = (corner_danger_distance - wall_distance) * wall_normal
				additional_offset += safety_offset
				walls_found += 1
				if debug_bouncing:
					print("SAFE   Wall close at distance ", wall_distance, " normal: ", wall_normal, " adding offset: ", safety_offset)
	
	safe_position += additional_offset
	
	if debug_bouncing:
		print("SAFE Original position: ", impact_position)
		print("SAFE Standard position: ", impact_position + primary_normal * base_offset)
		print("SAFE Final safe position: ", safe_position)
		print("SAFE Additional offset applied: ", additional_offset)
		print("SAFE Walls avoided: ", walls_found)
	
	# Final verification - make sure we're not still inside geometry
	if _will_be_inside_geometry(safe_position):
		if debug_bouncing:
			print("SAFE ⚠️ STILL INSIDE GEOMETRY! Applying emergency offset...")
		# Emergency: move further away from primary surface
		safe_position = impact_position + primary_normal * deflection_safety_distance * 1.67  # ~0.5
		
		if _will_be_inside_geometry(safe_position):
			if debug_bouncing:
				print("SAFE ⚠️ EMERGENCY OFFSET FAILED! Using maximum offset...")
			safe_position = impact_position + primary_normal * deflection_safety_distance * 3.33  # ~1.0
	
	return safe_position

func _force_raycast_updates():
	"""Force all raycasts to update immediately."""
	var raycasts = [forward_raycast, backward_raycast, left_raycast, right_raycast, up_raycast, down_raycast]
	for raycast in raycasts:
		if raycast:
			raycast.force_raycast_update()

func _find_shapecast_impact(target_body: Node3D) -> Dictionary:
	"""Use ShapeCast3D for consistent collision detection."""
	var shapecast = get_node_or_null("ShapeCast3D")
	if not shapecast:
		if debug_bouncing:
			print("SHAPECAST: ERROR - No ShapeCast3D found! Using fallback.")
		return _fallback_collision_detection(target_body)
	
	# Force update to get fresh collision data
	shapecast.force_shapecast_update()
	
	var collision_count = shapecast.get_collision_count()
	
	if debug_bouncing:
		print("SHAPECAST: === COLLISION DETECTION START ===")
		print("SHAPECAST: Collision count: ", collision_count)
		print("SHAPECAST: Bullet position: ", global_position)
		print("SHAPECAST: Travel direction: ", travel_direction.normalized())
		print("SHAPECAST: EXCLUSION ARRAY: ", _get_exclusion_array_names())
	
	if collision_count == 0:
		if debug_bouncing:
			print("SHAPECAST: NO COLLISIONS DETECTED")
		return {}
	
	# Filter out excluded bodies
	var valid_collisions = []
	
	# Print all collision data if debugging
	if debug_bouncing:
		print("SHAPECAST: ========== ALL COLLISION DATA ==========")
		for i in range(collision_count):
			var col_point = shapecast.get_collision_point(i)
			var col_normal = shapecast.get_collision_normal(i)
			var col_object = shapecast.get_collider(i)
			var col_shape_idx = shapecast.get_collider_shape(i)
			var col_distance = global_position.distance_to(col_point)
			
			var is_excluded = col_object in bounce_exclusion_array
			
			print("SHAPECAST: Collision ", i, ":")
			print("  Object: ", col_object.name, " [EXCLUDED]" if is_excluded else "")
			print("  Position: ", col_point)
			print("  Normal: ", col_normal)
			print("  Distance: ", "%.3f" % col_distance)
			print("  Shape Index: ", col_shape_idx)
			print("  Object Layer: ", col_object.collision_layer)
			
			# Analyze normal direction
			var normal_type = "Unknown"
			if abs(col_normal.y) > 0.8:
				normal_type = "Floor/Ceiling" if col_normal.y > 0 else "Ceiling/Floor"
			elif abs(col_normal.x) > 0.8:
				normal_type = "Wall (X-axis)"
			elif abs(col_normal.z) > 0.8:
				normal_type = "Wall (Z-axis)"
			else:
				normal_type = "Angled Surface"
			print("  Surface Type: ", normal_type)
			print("  ---")
			
			# Only add to valid collisions if not excluded
			if not is_excluded:
				valid_collisions.append({
					"point": col_point,
					"normal": col_normal,
					"object": col_object,
					"shape_idx": col_shape_idx,
					"distance": col_distance,
					"index": i
				})
		print("SHAPECAST: =======================================")
		print("SHAPECAST: Valid collisions after exclusion: ", valid_collisions.size())
	
	# If all collisions were excluded, return empty
	if valid_collisions.is_empty():
		if debug_bouncing:
			print("SHAPECAST: All collisions were excluded!")
		return {}
	
	# Sort valid collisions by distance and use the closest
	valid_collisions.sort_custom(func(a, b): return a.distance < b.distance)
	var closest = valid_collisions[0]
	
	if debug_bouncing:
		print("SHAPECAST: SELECTED collision ", closest.index, " for bounce:")
		print("SHAPECAST: Point: ", closest.point)
		print("SHAPECAST: Normal: ", closest.normal)
		print("SHAPECAST: Object: ", closest.object.name)
		print("SHAPECAST: Method: ", "shapecast_filtered")
	
	return {
		"position": closest.point,
		"normal": closest.normal,
		"object": closest.object,
		"shape_index": closest.shape_idx,
		"method": "shapecast_filtered"
	}

func _fallback_collision_detection(target_body: Node3D) -> Dictionary:
	"""Fallback collision detection if ShapeCast3D is not available."""
	# Get surface normal using existing method
	var surface_normal = _get_surface_normal(target_body, global_position)
	if surface_normal.length() < 0.1:
		surface_normal = Vector3.UP
	
	return {
		"position": global_position,
		"normal": surface_normal,
		"object": target_body,
		"method": "fallback"
	}

func _get_exclusion_array_names() -> String:
	"""Helper to get readable names of excluded bodies."""
	if bounce_exclusion_array.is_empty():
		return "[]"
	
	var names = []
	for body in bounce_exclusion_array:
		if is_instance_valid(body):
			names.append(body.name)
		else:
			names.append("<invalid>")
	return "[" + ", ".join(names) + "]"
