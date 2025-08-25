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
@export var lifetime: float = 30.0  # Very long lifetime so bullets don't disappear while player catches up
@export var travel_type: TravelType = TravelType.CONSTANT_FAST

# Time system integration
@export var time_resistance: float = 0.0  # 0.0 = fully affected by time, 1.0 = immune

# Visual properties
@export var tracer_color: Color = Color.YELLOW  # Default tracer color (gets overridden)
@export var spin_speed: float = 720.0  # Degrees per second rotation around z-axis

# Color constants removed - using different bullet scenes instead

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
var is_player_bullet: bool = false  # Track if this bullet was fired by the player
var shooter: Node = null  # Store reference to entity that fired this bullet for self-collision prevention

# Bullet type now determined by scene instead of enum

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

# Bullet recall properties
var is_being_recalled: bool = false  # True when bullet is returning to player
var recall_speed_multiplier: float = 2.0  # How much faster bullet moves when recalled
var recall_turn_speed: float = 0.8  # How fast bullet turns toward player (0-1, higher = faster turn)
var recall_target_position: Vector3 = Vector3.ZERO  # Current target position (player)

# Bounce properties
@export var can_bounce: bool = false  # Whether this bullet can bounce off surfaces
@export var max_bounces: int = 3  # Maximum number of bounces before bullet dies
@export_range(0.0, 1.0) var bounce_energy_loss: float = 0.2  # Energy lost per bounce (0.0 = no loss, 1.0 = all energy lost)
var current_bounces: int = 0  # Current number of bounces performed

# Travel behavior state
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
	# If not fired yet, track the gun's muzzle position and rotation (ONLY FOR PLAYER BULLETS!)
	if not has_been_fired and muzzle_marker and is_player_bullet:
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
			
			# Handle recalled bullet movement
			if is_being_recalled:
				_update_recalled_movement(time_scale, time_delta)
			else:
				# Normal bullet movement
				var movement = travel_direction * current_speed * time_scale * time_delta
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
		recall_target_position = player.global_position + Vector3(0, 1.0, 0)
		print("Bullet recalled! Heading to player at: ", recall_target_position)
		return true
	else:
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

func _update_recalled_movement(time_scale: float, time_delta: float):
	"""Handle movement when bullet is being recalled to player."""
	# Update player position continuously
	var player = get_tree().get_first_node_in_group("player")
	if player:
		recall_target_position = player.global_position + Vector3(0, 1.0, 0)
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
	if distance_to_player < 1.5:
		_handle_bullet_return_to_player()

func _handle_bullet_return_to_player():
	"""Handle what happens when recalled bullet reaches the player."""
	print("Bullet returned to player!")
	
	# Give player back ammo
	var player = get_tree().get_first_node_in_group("player")
	if player and player.gun and player.gun.has_method("add_ammo"):
		player.gun.add_ammo(1)
		print("Returned 1 ammo to player")
	else:
		print("WARNING: Could not return ammo - gun not found")
	
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
	
	# Visual effects handled by TracerManager
	
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

# Tracer visuals handled by TracerManager

# Material configuration removed - using different bullet scenes instead

func _cleanup_bullet():
	"""Clean up bullet resources including tracer registration."""
	# Unregister from tracer system
	if TracerManager and tracer_id != -1:
		TracerManager.unregister_bullet(tracer_id)
		tracer_id = -1

func _on_body_entered(body):
	
	# Check if we hit an enemy first (has take_damage method)
	if body.has_method("take_damage"):
		# Check if this is friendly fire (enemy bullet hitting enemy)
		var is_enemy_target = body.is_in_group("enemies")
		var is_player_target = body.is_in_group("player")
		

		
		# Check for enemy-on-enemy damage
		if not is_player_bullet and is_enemy_target:
			print("💀 ENEMY FRIENDLY FIRE: ", shooter.name if shooter else "unknown", " → ", body.name, " (", damage, " damage)")
		
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
				print("⏰ BULLET: Player damage prevented, bullet continues")
				return  # Don't free bullet, let it continue
			
			# Apply knockback if enemy supports it
			if body.has_method("apply_knockback"):
				var knockback_direction = travel_direction.normalized()
				body.apply_knockback(knockback_direction, knockback)

		
		has_hit_target = true
		is_being_recalled = false  # Stop any active recall
		
		# Handle piercing logic (regardless of damage)
		if piercing_value > 0.0:
			print("IMPACT Piercing through target, continuing bullet")
			_handle_piercing(body, global_position)
		else:
			# No piercing - create explosion and destroy bullet
			if is_explosive:
				_create_bullet_explosion(global_position)
			_cleanup_bullet()
			queue_free()
		return  # Done with target collision
	
	# Check if we hit environment (walls/floor) - only if not an enemy
	elif _is_environment(body):
		# Check all vertex raycasts to find the exact impact point
		var impact_data = _find_vertex_impact(body)
		
		if impact_data.has("position") and impact_data.has("normal"):
			print("VERTEX IMPACT found at: ", impact_data.position)
			print("VERTEX NORMAL: ", impact_data.normal)
			print("VERTEX RAYCAST: ", impact_data.raycast_name)
			
			# Try bouncing if bouncing is enabled
			if can_bounce and current_bounces < max_bounces:
				_handle_vertex_bounce(impact_data.position, impact_data.normal)
				return  # Don't destroy bullet - let it continue bouncing
			else:
				print("IMPACT Stopping bullet - no bounce")
		else:
			print("VERTEX IMPACT could not determine precise impact")
			
			# Fallback - try simple bounce if we're supposed to bounce
			if can_bounce and current_bounces < max_bounces:
				print("VERTEX FALLBACK: Attempting simple bounce without vertex data")
				_handle_simple_fallback_bounce()
				return  # Don't destroy bullet
		
		# Environment hit but no bouncing - stop bullet
		print("IMPACT Environment hit - stopping bullet")
		if is_explosive:
			_create_bullet_explosion(global_position)
		has_hit_target = true
		_cleanup_bullet()
		queue_free()
		
	# If we get here, unknown collision - stop the bullet
	else:
		print("IMPACT Unknown collision with: ", body.name, " - stopping bullet")
		has_hit_target = true
		_cleanup_bullet()
		queue_free()
	
	print("=== END COLLISION INFO ===")

func _find_vertex_impact(target_body: Node3D) -> Dictionary:
	"""Check all vertex raycasts to find which one hit the target body closest."""
	print("VERTEX === CHECKING ALL VERTEX RAYCASTS ===")
	print("VERTEX Bullet current_bounces: ", current_bounces)
	print("VERTEX Bullet global_position: ", global_position)
	print("VERTEX Bullet global_rotation: ", global_rotation)
	
	var all_raycasts = [forward_raycast, backward_raycast, left_raycast, right_raycast, up_raycast, down_raycast]
	var raycast_names = ["forward", "backward", "left", "right", "up", "down"]
	
	# Check if raycasts exist
	for i in range(all_raycasts.size()):
		if all_raycasts[i] == null:
			print("VERTEX ERROR: ", raycast_names[i], " raycast is NULL!")
		else:
			print("VERTEX ", raycast_names[i], " raycast exists and enabled: ", all_raycasts[i].enabled)
	
	var closest_impact = {}
	var closest_distance = INF
	
	for i in range(all_raycasts.size()):
		var raycast = all_raycasts[i]
		var name = raycast_names[i]
		
		print("VERTEX Checking ", name, " raycast...")
		
		if raycast.is_colliding():
			var collider = raycast.get_collider()
			var collision_point = raycast.get_collision_point()
			var collision_normal = raycast.get_collision_normal()
			var distance = global_position.distance_to(collision_point)
			
			print("VERTEX ", name, " HIT: ", collider.name if collider else "null")
			print("VERTEX ", name, " distance: ", distance)
			print("VERTEX ", name, " point: ", collision_point)
			print("VERTEX ", name, " normal: ", collision_normal)
			
			# Check if this raycast hit our target body
			if collider == target_body and distance < closest_distance:
				print("VERTEX ", name, " is CLOSEST hit on target!")
				closest_distance = distance
				closest_impact = {
					"position": collision_point,
					"normal": collision_normal,
					"distance": distance,
					"raycast_name": name
				}
		else:
			print("VERTEX ", name, " not colliding")
	
	if closest_impact.is_empty():
		print("VERTEX No raycasts hit the target body!")
	else:
		print("VERTEX Best impact: ", closest_impact.raycast_name, " at distance ", closest_impact.distance)
	
	return closest_impact

func _handle_vertex_bounce(impact_position: Vector3, surface_normal: Vector3):
	"""Handle bouncing using precise vertex impact data."""
	print("VERTEX === BOUNCE WITH EXACT VERTEX DATA ===")
	print("VERTEX Impact position: ", impact_position)
	print("VERTEX Surface normal: ", surface_normal)
	print("VERTEX Travel direction before: ", travel_direction)
	
	# Calculate reflection: new_direction = incident - 2 * (incident · normal) * normal
	var incident_direction = travel_direction.normalized()
	var dot_product = incident_direction.dot(surface_normal)
	var reflected_direction = incident_direction - 2.0 * dot_product * surface_normal
	
	print("VERTEX Reflected direction: ", reflected_direction)
	print("VERTEX Incident angle: ", rad_to_deg(acos(abs(dot_product))))
	
	# Update bullet properties
	travel_direction = reflected_direction.normalized()
	current_bounces += 1
	current_speed *= (1.0 - bounce_energy_loss)
	
	# Move bullet away from surface
	global_position = impact_position + surface_normal * 0.15
	
	# Orient bullet
	if travel_direction.length() > 0.01:
		var up_vector = Vector3.UP
		if abs(travel_direction.dot(Vector3.UP)) > 0.99:
			up_vector = Vector3.FORWARD
		look_at(global_position + travel_direction, up_vector)
	
	print("VERTEX Bounce complete - new direction: ", travel_direction)
	print("VERTEX POST-BOUNCE: Checking raycast states...")
	print("VERTEX POST-BOUNCE forward enabled: ", forward_raycast.enabled if forward_raycast else "null")
	print("VERTEX POST-BOUNCE backward enabled: ", backward_raycast.enabled if backward_raycast else "null")
	print("VERTEX POST-BOUNCE left enabled: ", left_raycast.enabled if left_raycast else "null")
	print("VERTEX POST-BOUNCE right enabled: ", right_raycast.enabled if right_raycast else "null")
	print("VERTEX POST-BOUNCE up enabled: ", up_raycast.enabled if up_raycast else "null")
	print("VERTEX POST-BOUNCE down enabled: ", down_raycast.enabled if down_raycast else "null")

func _handle_simple_fallback_bounce():
	"""Smart fallback bounce when vertex raycasts fail - works for floors AND walls."""
	print("FALLBACK === SMART BOUNCE WITHOUT VERTEX DATA ===")
	print("FALLBACK Bullet position: ", global_position)
	print("FALLBACK Travel direction before: ", travel_direction)
	
	# SMART NORMAL DETECTION: Cast a ray in travel direction to find surface normal
	var space_state = get_world_3d().direct_space_state
	var ray_start = global_position - travel_direction.normalized() * 0.3
	var ray_end = global_position + travel_direction.normalized() * 0.3
	
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collision_mask = 4  # Environment layer
	query.exclude = [self]
	
	print("FALLBACK Smart raycast - start: ", ray_start)
	print("FALLBACK Smart raycast - end: ", ray_end)
	
	var result = space_state.intersect_ray(query)
	var surface_normal: Vector3
	
	if result and result.has("normal"):
		surface_normal = result.normal
		print("FALLBACK SUCCESS: Got surface normal from smart raycast: ", surface_normal)
		print("FALLBACK Surface type: ", "Floor" if abs(surface_normal.y) > 0.7 else "Wall")
	else:
		# Ultimate fallback - assume floor
		surface_normal = Vector3.UP
		print("FALLBACK ULTIMATE: Using upward normal as last resort: ", surface_normal)
	
	# Calculate reflection using the detected/assumed normal
	var incident_direction = travel_direction.normalized()
	var dot_product = incident_direction.dot(surface_normal)
	var reflected_direction = incident_direction - 2.0 * dot_product * surface_normal
	
	print("FALLBACK Incident direction: ", incident_direction)
	print("FALLBACK Surface normal: ", surface_normal)
	print("FALLBACK Dot product: ", dot_product)
	print("FALLBACK Reflected direction: ", reflected_direction)
	print("FALLBACK Incident angle: ", rad_to_deg(acos(abs(dot_product))))
	
	# Update bullet properties
	travel_direction = reflected_direction.normalized()
	current_bounces += 1
	current_speed *= (1.0 - bounce_energy_loss)
	
	# Move bullet away from surface in normal direction
	global_position += surface_normal * 0.2
	print("FALLBACK Moved bullet away from surface by: ", surface_normal * 0.2)
	
	# Orient bullet
	if travel_direction.length() > 0.01:
		var up_vector = Vector3.UP
		if abs(travel_direction.dot(Vector3.UP)) > 0.99:
			up_vector = Vector3.FORWARD
		look_at(global_position + travel_direction, up_vector)
	
	print("FALLBACK Smart bounce complete - new direction: ", travel_direction)
	print("FALLBACK New position: ", global_position)

func _is_environment(body: Node3D) -> bool:
	"""Check if the body is environment (walls, floors, etc.) based on collision layer."""
	# Environment should be on collision layer 3 (bit value 4)
	return (body.collision_layer & 4) != 0

func _get_surface_impact_position(hit_body: Node3D) -> Vector3:
	"""Calculate the actual surface impact position using raycast with debugging."""
	print("BOUNCE === IMPACT POSITION CALCULATION ===")
	print("BOUNCE Hit body: ", hit_body.name)
	print("BOUNCE Bullet position: ", global_position)
	print("BOUNCE Travel direction: ", travel_direction)
	
	# Cast a ray from slightly behind the bullet to slightly ahead to find surface intersection
	var space_state = get_world_3d().direct_space_state
	var ray_start = global_position - travel_direction * 0.5  # Start slightly behind bullet
	var ray_end = global_position + travel_direction * 0.5    # End slightly ahead
	
	print("BOUNCE Impact raycast start: ", ray_start)
	print("BOUNCE Impact raycast end: ", ray_end)
	print("BOUNCE Impact raycast direction: ", (ray_end - ray_start).normalized())
	
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collision_mask = hit_body.collision_layer  # Only hit the specific body
	query.exclude = [self]  # Don't hit the bullet itself
	
	print("BOUNCE Impact raycast mask: ", query.collision_mask)
	print("BOUNCE Hit body layer: ", hit_body.collision_layer)
	
	var result = space_state.intersect_ray(query)
	
	if result and result.collider == hit_body:
		# Found the exact surface hit point
		print("BOUNCE Impact position found via raycast: ", result.position)
		print("BOUNCE Impact normal from raycast: ", result.normal)
		return result.position
	else:
		# Fallback: move bullet position slightly back along travel direction
		var fallback_position = global_position - travel_direction.normalized() * 0.1
		print("BOUNCE Using fallback impact position: ", fallback_position)
		if result:
			print("BOUNCE Raycast hit wrong body: ", result.collider.name if result.collider else "null")
		else:
			print("BOUNCE Raycast missed completely")
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

func _get_collision_normal_direct(surface_body: Node3D, impact_position: Vector3) -> Vector3:
	"""Get collision normal using a direct raycast at the impact position - WORKS FOR ANY SURFACE."""
	print("BOUNCE === DIRECT COLLISION NORMAL ===")
	var space_state = get_world_3d().direct_space_state
	
	# PERFECT LOGIC: Cast ray in the OPPOSITE direction of bullet travel
	# This ensures we hit the surface we just collided with, regardless of orientation
	var ray_distance = 0.5
	var ray_start = impact_position - travel_direction.normalized() * ray_distance  # Start behind impact (where bullet came from)
	var ray_end = impact_position + travel_direction.normalized() * ray_distance    # End ahead of impact (where bullet was going)
	
	print("BOUNCE Direct normal raycast - start: ", ray_start)
	print("BOUNCE Direct normal raycast - end: ", ray_end)
	print("BOUNCE Raycast direction (bullet travel): ", travel_direction.normalized())
	
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collision_mask = surface_body.collision_layer
	query.exclude = [self]
	
	var result = space_state.intersect_ray(query)
	
	if result and result.collider == surface_body:
		print("BOUNCE SUCCESS: Got collision normal directly: ", result.normal)
		print("BOUNCE Normal type: ", "Floor" if abs(result.normal.y) > 0.7 else "Wall")
		return result.normal
	else:
		print("BOUNCE FAILED: Direct raycast missed, will use fallback")
		if result:
			print("BOUNCE Hit wrong body: ", result.collider.name if result.collider else "null")
		return Vector3.ZERO  # Signal to use fallback

func _handle_surface_bounce(surface_body: Node3D, impact_position: Vector3, direct_normal: Vector3 = Vector3.ZERO):
	"""Handle bullet bouncing off a surface with EXTENSIVE debugging."""
	print("BOUNCE ================================")
	print("BOUNCE === BOUNCE ATTEMPT #", current_bounces + 1, " of ", max_bounces, " ===")
	print("BOUNCE ================================")
	print("BOUNCE Impact position: ", impact_position)
	print("BOUNCE Bullet position: ", global_position)
	print("BOUNCE Travel direction BEFORE: ", travel_direction)
	print("BOUNCE Travel direction normalized: ", travel_direction.normalized())
	print("BOUNCE Travel direction length: ", travel_direction.length())
	print("BOUNCE Current speed: ", current_speed)
	print("BOUNCE Surface body: ", surface_body.name)
	print("BOUNCE Surface body class: ", surface_body.get_class())
	print("BOUNCE Surface collision layer: ", surface_body.collision_layer)
	
	# Get surface normal - use direct normal first, fallback if needed
	var surface_normal: Vector3
	if direct_normal != Vector3.ZERO:
		print("BOUNCE Using direct collision normal: ", direct_normal)
		surface_normal = direct_normal
	else:
		print("BOUNCE Using fallback normal detection")
		surface_normal = _get_surface_normal(surface_body, impact_position)
	
	if surface_normal.length() < 0.1:
		print("BOUNCE ERROR: Could not determine surface normal, stopping bullet")
		print("BOUNCE Surface normal length: ", surface_normal.length())
		print("BOUNCE Surface normal value: ", surface_normal)
		has_hit_target = true
		_create_environment_impact_effect(impact_position)
		_cleanup_bullet()
		queue_free()
		return
	
	print("BOUNCE Surface normal: ", surface_normal)
	print("BOUNCE Surface normal normalized: ", surface_normal.normalized())
	print("BOUNCE Surface normal length: ", surface_normal.length())
	
	# Calculate reflection: new_direction = incident - 2 * (incident · normal) * normal
	var incident_direction = travel_direction.normalized()
	print("BOUNCE Incident direction: ", incident_direction)
	
	var dot_product = incident_direction.dot(surface_normal)
	print("BOUNCE Dot product (incident · normal): ", dot_product)
	print("BOUNCE Angle of incidence (degrees): ", rad_to_deg(acos(abs(dot_product))))
	
	var reflection_component = 2.0 * dot_product * surface_normal
	print("BOUNCE Reflection component (2 * dot * normal): ", reflection_component)
	
	var reflected_direction = incident_direction - reflection_component
	print("BOUNCE Reflected direction (raw): ", reflected_direction)
	print("BOUNCE Reflected direction normalized: ", reflected_direction.normalized())
	print("BOUNCE Reflected direction length: ", reflected_direction.length())
	
	# Validate reflection
	var reflected_dot = reflected_direction.normalized().dot(surface_normal)
	print("BOUNCE Reflected dot with normal: ", reflected_dot)
	print("BOUNCE Angle of reflection (degrees): ", rad_to_deg(acos(abs(reflected_dot))))
	
	# Check if reflection makes sense (should be opposite of incident angle)
	if abs(abs(dot_product) - abs(reflected_dot)) > 0.1:
		print("BOUNCE WARNING: Reflection angle doesn't match incident angle!")
		print("BOUNCE Expected reflected dot: ", -dot_product, " Got: ", reflected_dot)
	
	# Update bullet properties
	travel_direction = reflected_direction.normalized()
	current_bounces += 1
	
	print("BOUNCE Travel direction AFTER: ", travel_direction)
	print("BOUNCE Bounce count updated to: ", current_bounces)
	
	# Apply energy loss
	var old_speed = current_speed
	current_speed *= (1.0 - bounce_energy_loss)
	print("BOUNCE Speed change: ", old_speed, " -> ", current_speed, " (loss: ", bounce_energy_loss, ")")
	
	# Move bullet slightly away from surface to prevent re-collision
	# Use bullet center position instead of impact position for consistent results
	var old_position = global_position
	global_position = global_position + surface_normal * 0.15  # Move bullet center away from surface
	print("BOUNCE Position change: ", old_position, " -> ", global_position)
	print("BOUNCE Position offset from bullet center: ", surface_normal * 0.15)
	print("BOUNCE Using bullet center instead of impact position for positioning")
	
	# Orient bullet to new direction
	if travel_direction.length() > 0.01:
		var up_vector = Vector3.UP
		if abs(travel_direction.dot(Vector3.UP)) > 0.99:
			up_vector = Vector3.FORWARD
		print("BOUNCE Orienting bullet - up_vector: ", up_vector)
		look_at(global_position + travel_direction, up_vector)
		print("BOUNCE Bullet rotation after look_at: ", global_rotation)
	else:
		print("BOUNCE ERROR: Travel direction too small for orientation!")
	
	# Create bounce impact effect (different color to show bounce)
	_create_bounce_impact_effect(impact_position)
	
	print("BOUNCE ================================")
	print("BOUNCE === BOUNCE COMPLETE ===")
	print("BOUNCE ================================")

func _get_surface_normal(surface_body: Node3D, impact_position: Vector3) -> Vector3:
	"""Get the surface normal at the impact point using raycast with EXTENSIVE debugging."""
	print("BOUNCE === SURFACE NORMAL DETECTION ===")
	print("BOUNCE Impact position: ", impact_position)
	print("BOUNCE Impact Y value: ", impact_position.y)
	print("BOUNCE Bullet position: ", global_position)
	print("BOUNCE Bullet Y value: ", global_position.y)
	print("BOUNCE Y difference (impact - bullet): ", impact_position.y - global_position.y)
	
	var space_state = get_world_3d().direct_space_state
	
	# BETTER APPROACH: Raycast FROM the impact position to get accurate surface normal
	# This gets the actual normal at the collision point, not some estimated position
	var ray_start = impact_position + travel_direction.normalized() * 0.1  # Start slightly ahead of impact
	var ray_end = impact_position - travel_direction.normalized() * 0.1    # End slightly behind impact
	
	print("BOUNCE Raycasting FROM impact position for accurate normal")
	print("BOUNCE Impact position: ", impact_position)
	print("BOUNCE Raycast for normal - start: ", ray_start)
	print("BOUNCE Raycast for normal - end: ", ray_end)
	print("BOUNCE Raycast direction: ", (ray_end - ray_start).normalized())
	print("BOUNCE Raycast distance: ", ray_start.distance_to(ray_end))
	
	var query = PhysicsRayQueryParameters3D.create(ray_start, ray_end)
	query.collision_mask = surface_body.collision_layer
	query.exclude = [self]
	
	print("BOUNCE Raycast collision mask: ", query.collision_mask)
	print("BOUNCE Surface body collision layer: ", surface_body.collision_layer)
	print("BOUNCE Mask & Layer match: ", (query.collision_mask & surface_body.collision_layer) != 0)
	
	var result = space_state.intersect_ray(query)
	
	if result and result.collider == surface_body:
		print("BOUNCE SUCCESS: Surface normal found via raycast")
		print("BOUNCE Normal: ", result.normal)
		print("BOUNCE Hit position: ", result.position)
		print("BOUNCE Hit collider: ", result.collider.name)
		print("BOUNCE Normal length: ", result.normal.length())
		print("BOUNCE Normal Y component: ", result.normal.y)
		return result.normal
	else:
		print("BOUNCE FALLBACK: Using smart fallback normal")
		if result:
			print("BOUNCE Raycast hit different body: ", result.collider.name if result.collider else "null")
			print("BOUNCE Result normal: ", result.normal if result.has("normal") else "no normal")
		else:
			print("BOUNCE Raycast missed completely")
		
		# SIMPLE FALLBACK: Calculate normal from impact position to surface center
		var surface_center = surface_body.global_position
		var surface_name = surface_body.name.to_lower()
		
		print("BOUNCE Simple fallback - impact to surface center")
		print("BOUNCE Surface center: ", surface_center)
		print("BOUNCE Surface name: ", surface_name)
		
		# Calculate vector from surface center to impact point = outward normal direction
		var outward_normal = (impact_position - surface_center).normalized()
		print("BOUNCE Calculated outward normal: ", outward_normal)
		return outward_normal

func _create_bounce_impact_effect(position: Vector3):
	"""Create impact effect when bullet bounces off a surface."""
	print("BOUNCE Creating bounce impact effect at: ", position)
	
	# Use TracerManager to create bounce impact effect (cyan color to distinguish from regular impacts)
	if TracerManager:
		TracerManager.create_impact(position, Color.CYAN, 0.2)

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
