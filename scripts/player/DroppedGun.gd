extends RigidBody3D

# === DROPPED GUN SCRIPT ===
# Handles physics for dropped guns with time scale integration

var time_manager: Node
var debug_dropped_gun: bool = true

# Stationary detection
var stationary_timer: float = 0.0
var stationary_threshold: float = 0.25  # Seconds of being stationary
var has_been_stationary: bool = false
var last_position: Vector3

func _ready():
	if debug_dropped_gun:
		print("dropped gun: _ready() called!")
	time_manager = get_node("/root/TimeManager")
	if debug_dropped_gun:
		print("dropped gun: TimeManager found: ", time_manager != null)
	
	# Set initial velocity from metadata
	var initial_velocity = get_meta("initial_velocity", Vector3(0, 0, -2.0))
	linear_velocity = initial_velocity
	if debug_dropped_gun:
		print("dropped gun: RigidBody3D created, initial velocity: ", initial_velocity)
	
	# Add random torque for realistic spinning
	var random_torque = Vector3(
		randf_range(-5.0, 5.0),  # Random X rotation
		randf_range(-5.0, 5.0),  # Random Y rotation  
		randf_range(-5.0, 5.0)   # Random Z rotation
	)
	angular_velocity = random_torque
	if debug_dropped_gun:
		print("dropped gun: Applied random torque: ", random_torque)
	
	# Set up physics properties
	gravity_scale = 1.0
	linear_damp = 0.1
	angular_damp = 0.1
	
	# Store initial position for stationary detection
	last_position = global_position

func _process(delta):
	if debug_dropped_gun and Engine.get_process_frames() % 60 == 0:
		print("dropped gun: _process() called! delta=", delta)
	
	if time_manager:
		var time_scale = time_manager.get_time_scale()
		var time_delta = delta * time_scale
		
		# Apply time scale to physics
		gravity_scale = time_scale
		linear_damp = 0.1 * time_scale
		angular_damp = 0.1 * time_scale
		
		if debug_dropped_gun and Engine.get_process_frames() % 30 == 0:
			print("dropped gun: time_scale=", time_scale, " linear_velocity=", linear_velocity, " pos=", global_position)
		
		# Check if gun has been stationary long enough
		_check_stationary_status(time_delta)
	else:
		if debug_dropped_gun and Engine.get_process_frames() % 60 == 0:
			print("dropped gun: NO TIME_MANAGER!")

func _check_stationary_status(time_delta: float):
	"""Check if gun has been stationary long enough to create pickup."""
	# Check if velocity is below threshold (allows for tiny settling oscillations)
	if linear_velocity.length() < 0.1:
		stationary_timer += time_delta
		if debug_dropped_gun and Engine.get_process_frames() % 30 == 0:
			print("dropped gun: Stationary for ", stationary_timer, " seconds (velocity: ", linear_velocity.length(), ")")
		
		# Check if we've been stationary long enough
		if stationary_timer >= stationary_threshold and not has_been_stationary:
			has_been_stationary = true
			_create_gun_pickup()
	else:
		# Reset timer if we're moving
		stationary_timer = 0.0

func _create_gun_pickup():
	"""Create a gun pickup at the current position and remove this dropped gun."""
	if debug_dropped_gun:
		print("dropped gun: Creating gun pickup at position: ", global_position)
	
	# Get gun type and ammo from metadata
	var gun_type = get_meta("gun_type", 0)
	var ammo = get_meta("ammo", 12)
	
	# Create the gun pickup
	var gun_pickup_scene = preload("res://scenes/GunPickup.tscn")
	var new_pickup = gun_pickup_scene.instantiate()
	
	# Add to scene first
	get_tree().current_scene.add_child(new_pickup)
	
	# Wait one frame for _ready() to complete, then set position
	await get_tree().process_frame
	var pickup_position = global_position
	pickup_position.y = 1.0  # Set to 1.0 units above the ground
	new_pickup.global_position = pickup_position
	
	if debug_dropped_gun:
		print("dropped gun: Dropped gun position: ", global_position)
		print("dropped gun: Pickup position set to: ", pickup_position)
		print("dropped gun: New pickup global position: ", new_pickup.global_position)
	
	# Configure the pickup
	if debug_dropped_gun:
		print("dropped gun: Configuring new pickup with gun_type: ", gun_type, " ammo: ", ammo)
	
	if new_pickup.has_method("set_gun_type"):
		new_pickup.set_gun_type(gun_type)
		print("dropped gun: Called set_gun_type on new pickup")
	
	if new_pickup.has_method("set_ammo_info"):
		new_pickup.set_ammo_info(ammo)
		print("dropped gun: Called set_ammo_info on new pickup")
	
	if debug_dropped_gun:
		print("dropped gun: Gun pickup created at: ", new_pickup.global_position)
	
	# Remove this dropped gun
	queue_free()
