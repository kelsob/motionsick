extends CharacterBody3D

## === EXPORTED CONFIGURATION ===
@export_group("Movement Speeds")
## Walking speed when moving normally
@export var walk_speed: float = 7.5
## Sprinting speed when holding sprint key
@export var sprint_speed: float = 15.0
## Crouching speed when crouched
@export var crouch_speed: float = 3.75
## Sliding speed during slide maneuver
@export var slide_speed: float = 18.75

@export_group("Jump System")
## Velocity applied for normal jump
@export var jump_velocity: float = 8.5
## Velocity applied for double jump
@export var double_jump_velocity: float = 8.5

@export_group("Dash System")
## Speed applied during dash movement
@export var dash_speed: float = 15.0
## How long dash lasts (seconds)
@export var dash_duration: float = 0.25
## Cooldown between dashes (seconds)
@export var dash_cooldown: float = 0.5
## How quickly dash velocity decelerates after dash ends
@export var dash_deceleration: float = 35.0

@export_group("Movement Physics")
## Acceleration rate for reaching target speed
@export var acceleration: float = 3.0
## Deceleration rate when stopping movement
@export var deceleration: float = 3.0

@export_group("Crouch and Slide System")
## Player height when crouching
@export var crouch_height: float = 1.0
## Player height when standing
@export var stand_height: float = 1.5
## Duration of slide maneuver (seconds)
@export var slide_time: float = 0.5
## Additional clearance needed above player to stand up
@export var stand_clearance: float = 0.1

@export_group("Bullet Interaction System")
## Maximum distance for bullet interaction (pickup/deflection)
@export var bullet_interaction_range: float = 5.0
## Maximum time scale threshold for bullet pickup (below this allows pickup)
@export var pickup_time_threshold: float = 0.5
## Speed multiplier applied to deflected bullets
@export var deflect_speed_boost: float = 1.5
## Cooldown between deflection attempts (seconds)
@export var deflect_cooldown: float = 0.3
## Movement slowdown when deflecting (added to movement intent for time scaling)
@export var deflect_movement_slowdown: float = 0.8
## Duration of movement slowdown after deflection (seconds)
@export var deflect_slowdown_duration: float = 0.3
## Movement slowdown when picking up bullets (added to movement intent for time scaling)
@export var pickup_movement_slowdown: float = 0.6
## Duration of movement slowdown after pickup (seconds)  
@export var pickup_slowdown_duration: float = 0.25

@export_group("Movement Thresholds")
## Minimum movement input magnitude to register as moving
@export var movement_input_threshold: float = 0.1
## Speed percentage threshold for movement state changes
@export var speed_percentage_threshold_high: float = 0.99
## Speed percentage threshold for movement state changes (low)
@export var speed_percentage_threshold_low: float = 0.01
## Minimum dash velocity magnitude to apply dash movement
@export var dash_velocity_threshold: float = 0.01

@export_group("Target Position System")
## Downward offset from camera for enemy targeting (chest level)
@export var target_position_offset: float = 0.3

@export_group("Debug Settings")
## Enable debug output for movement system
@export var debug_movement: bool = false
## Enable debug output for pickup system
@export var debug_pickup: bool = false
## Enable debug output for deflection system
@export var debug_deflection: bool = false
## Enable debug output for energy system integration
@export var debug_energy: bool = false
## Enable debug output for damage system
@export var debug_damage: bool = false

@onready var GRAVITY: float = ProjectSettings.get_setting("physics/3d/default_gravity")

## === COMPONENTS ===
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var camera: Camera3D = $Camera3D
@onready var gun: Node3D = $Camera3D/Gun
@onready var action_tracker: PlayerActionTracker = $PlayerActionTracker

## === RUNTIME STATE ===
# Movement states
var is_sprinting := false
var is_crouching := false
var is_sliding := false
var can_double_jump := false
var slide_timer := 0.0

# Previous states for tracking transitions
var was_sprinting := false
var was_crouching := false
var was_sliding := false

# Dash state
var is_dashing := false
var dash_timer := 0.0
var dash_cooldown_timer := 0.0
var dash_velocity := Vector3.ZERO

# Movement tracking for gun system
var is_moving := false
var move_input := Vector2.ZERO
var was_on_floor := true

# Movement intent for time system (tracks input intensity, not velocity)
var movement_intent: float = 0.0  # Horizontal movement intent
var vertical_intent: float = 0.0  # Vertical movement intent (jump/fall)
var combined_movement_intent: float = 0.0  # Final combined intent

# Time system integration
var time_manager: Node = null
var time_energy_manager: Node = null

# Deflection system state
var deflect_cooldown_timer: float = 0.0
var deflect_slowdown_timer: float = 0.0

# Pickup system state  
var pickup_slowdown_timer: float = 0.0

# Bullet interaction tracking
var current_interactable_bullet: Node = null

# Action-based movement modifiers
var action_movement_modifier: float = 0.0

# === SIGNALS FOR GUN SYSTEM ===
signal movement_started
signal movement_stopped
signal dash_performed
signal jump_performed
signal landed

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Add to player group for bullet collision detection
	add_to_group("player")
	
	# Set player collision layer
	collision_layer = 1  # Player layer
	collision_mask = 5   # Collide with Environment (4) + Player (1) = 5
	
	# Connect to TimeManager
	time_manager = get_node("/root/TimeManager")
	if time_manager:
		if debug_energy:
			print("Player connected to TimeManager")
	else:
		if debug_energy:
			print("WARNING: Player can't find TimeManager!")
	
	# Connect to TimeEnergyManager
	time_energy_manager = get_node("/root/TimeEnergyManager")
	if time_energy_manager:
		if debug_energy:
			print("Player connected to TimeEnergyManager")
		# Connect to energy manager signals
		time_energy_manager.movement_lock_started.connect(_on_movement_locked)
		time_energy_manager.movement_unlocked.connect(_on_movement_unlocked)
		time_energy_manager.energy_depleted.connect(_on_energy_depleted)
		time_energy_manager.energy_restored.connect(_on_energy_restored)
	else:
		if debug_energy:
			print("WARNING: Player can't find TimeEnergyManager!")
	
	# Connect to gun if it exists
	if gun and gun.has_method("_on_player_movement_started"):
		movement_started.connect(gun._on_player_movement_started)
		movement_stopped.connect(gun._on_player_movement_stopped)
		dash_performed.connect(gun._on_player_dash_performed)
		jump_performed.connect(gun._on_player_jump_performed)
		landed.connect(gun._on_player_landed)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		# Camera rotation handled in camera script
		pass
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _input(event):
	# Handle dash input
	if event.is_action_pressed("action_dash") and can_dash():
		perform_dash()
	
	# Handle pickup input (bullets and gun)
	if event.is_action_pressed("action_pickup"):
		if debug_pickup:
			print("action_pickup pressed - attempting pickup")
		if not _try_pickup_gun():
			_try_pickup_bullet()
	
	# Handle bullet deflection input
	if event.is_action_pressed("action_fire"):
		# If no gun equipped, use left-click for deflection
		if not gun or not gun.is_equipped():
			_try_deflect_bullet()
	elif event.is_action_pressed("action_deflect"):
		# F key works regardless of gun state
		_try_deflect_bullet()
	
	# Handle bullet recall input (right-click)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_try_recall_bullet()

func _process(delta):
	# Update bullet interaction highlighting each frame
	_update_bullet_interaction_highlight()

func _physics_process(delta):
	# Track movement distance for analytics
	var previous_position = global_position
	
	update_timers(delta)
	handle_movement_input(delta)
	apply_gravity(delta)
	move_and_slide()
	update_movement_state()
	update_floor_state()
	update_action_tracking()
	
	# Calculate and track movement distance
	var movement_distance = previous_position.distance_to(global_position)
	if movement_distance > 0.0:
		AnalyticsManager.track_movement(movement_distance)

func update_timers(delta):
	if is_dashing:
		dash_timer -= delta
		if dash_timer <= 0.0:
			end_dash()
	
	if dash_cooldown_timer > 0.0:
		dash_cooldown_timer -= delta
	
	if is_sliding:
		slide_timer -= delta
		if slide_timer <= 0.0 or not Input.is_action_pressed("action_slide"):
			end_slide()
	
	# Update deflection cooldown
	if deflect_cooldown_timer > 0.0:
		deflect_cooldown_timer -= delta
	
	# Update action-based movement slowdown timers
	if deflect_slowdown_timer > 0.0:
		deflect_slowdown_timer -= delta
	
	if pickup_slowdown_timer > 0.0:
		pickup_slowdown_timer -= delta

func handle_movement_input(delta):
	var input_dir = get_input_direction()
	var target_speed = get_movement_speed()
	
	# Update movement intent based on input (not velocity)
	update_movement_intent(delta)
	
	# Handle crouching/sliding
	handle_crouch_slide_input()
	
	# Handle jumping
	handle_jump_input()
	
	# Calculate target velocity
	var direction = (global_transform.basis * input_dir).normalized()
	var target_velocity = direction * target_speed
	
	# Add dash velocity if dashing
	if is_dashing:
		target_velocity += dash_velocity
	elif dash_velocity.length() > dash_velocity_threshold:
		# Decelerate dash velocity after dash ends
		var dash_speed = dash_velocity.length()
		dash_speed = max(0.0, dash_speed - dash_deceleration * delta)
		dash_velocity = dash_velocity.normalized() * dash_speed
		target_velocity += dash_velocity
	
	# Apply acceleration/deceleration
	if direction.length() > dash_velocity_threshold or dash_velocity.length() > dash_velocity_threshold:
		velocity.x = lerp(velocity.x, target_velocity.x, min(1.0, acceleration * delta))
		velocity.z = lerp(velocity.z, target_velocity.z, min(1.0, acceleration * delta))
	else:
		velocity.x = lerp(velocity.x, 0.0, min(1.0, deceleration * delta))
		velocity.z = lerp(velocity.z, 0.0, min(1.0, deceleration * delta))

func get_movement_speed() -> float:
	if is_sliding:
		return slide_speed
	elif is_crouching:
		return crouch_speed
	elif is_sprinting and not is_crouching:
		return sprint_speed
	else:
		return walk_speed

func get_movement_speed_percentage() -> float:
	var speed_percentage : float = velocity.length() / walk_speed
	if speed_percentage >= speed_percentage_threshold_high:
		speed_percentage = 1.0
	elif speed_percentage <= speed_percentage_threshold_low:
		speed_percentage = 0
	if debug_movement:
		print("player movement speed percentage:", speed_percentage)
	return speed_percentage

func update_movement_intent(delta: float):
	"""Update movement intent based on input keys AND vertical velocity, not just horizontal."""
	# Check if any movement keys are being pressed AND movement is allowed
	var has_movement_input = (
		Input.is_action_pressed("action_move_forward") or
		Input.is_action_pressed("action_move_back") or
		Input.is_action_pressed("action_move_left") or
		Input.is_action_pressed("action_move_right")
	)
	
	# Check if movement is allowed by energy system
	var movement_allowed = true
	if time_energy_manager:
		movement_allowed = time_energy_manager.can_move()
	
	if has_movement_input and movement_allowed:
		# Increase intent using same acceleration as movement
		movement_intent = min(1.0, movement_intent + acceleration * delta)
	else:
		# Decrease intent using same deceleration as movement
		movement_intent = max(0.0, movement_intent - deceleration * delta)
		
		# If movement is not allowed, force stop velocity immediately
		if not movement_allowed:
			velocity.x = 0.0
			velocity.z = 0.0
	
	# ADD VERTICAL VELOCITY COMPONENT
	# Calculate vertical movement intensity (jump/fall motion)
	var vertical_speed = abs(velocity.y)
	vertical_intent = min(1.0, vertical_speed / jump_velocity)  # Normalize to 0-1 based on jump speed
	
	if debug_movement and vertical_intent > 0.1:
		print("MOVEMENT INTENT DEBUG: vertical_speed=", vertical_speed, " jump_velocity=", jump_velocity, " vertical_intent=", vertical_intent)
	
	# Combine horizontal intent with vertical intent (use max, not add)
	var combined_intent = max(movement_intent, vertical_intent)
	
	if debug_movement and abs(combined_intent - movement_intent) > 0.01:
		print("MOVEMENT INTENT DEBUG: horizontal=", movement_intent, " vertical=", vertical_intent, " combined=", combined_intent)
	
	# ADD ACTION-BASED MOVEMENT MODIFIERS
	action_movement_modifier = 0.0
	
	# Add deflection slowdown if active
	if deflect_slowdown_timer > 0.0:
		action_movement_modifier += deflect_movement_slowdown
	
	# Add pickup slowdown if active
	if pickup_slowdown_timer > 0.0:
		action_movement_modifier += pickup_movement_slowdown
	
	# Clamp final movement intent to valid range
	var final_movement_intent = clamp(combined_intent + action_movement_modifier, 0.0, 1.0)
	
	# Store combined intent for get_movement_intent()
	combined_movement_intent = final_movement_intent
	
	# Send combined movement intent to energy manager
	if time_energy_manager:
		time_energy_manager.set_player_movement_intent(final_movement_intent)

func get_movement_intent() -> float:
	"""Get current movement intent (0.0 to 1.0) including vertical velocity and action modifiers."""
	return combined_movement_intent

func handle_crouch_slide_input():
	# Sprinting - only allow when on ground
	is_sprinting = Input.is_action_pressed("action_sprint") and not is_crouching and not is_sliding and is_on_floor()
	
	# Sliding
	if Input.is_action_just_pressed("action_slide") and is_sprinting and is_on_floor() and not is_sliding:
		start_slide()
	
	# Crouching - only allow when on ground
	if Input.is_action_pressed("action_crouch") and not is_sliding and is_on_floor():
		if not is_crouching:
			crouch()
	else:
		if is_crouching and not is_sliding:
			# Only allow standing up when on ground and there's room
			if is_on_floor() and can_stand_up():
				stand()

func handle_jump_input():
	if Input.is_action_just_pressed("action_jump"):
		if is_on_floor():
			# If crouched, temporarily stand up for the jump
			var was_crouched = is_crouching
			if was_crouched and can_stand_up():
				stand()
			
			velocity.y = jump_velocity
			can_double_jump = true
			action_tracker.record_jump()
			# Track jump for analytics
			AnalyticsManager.track_jump()
			jump_performed.emit()
		elif can_double_jump:
			velocity.y = double_jump_velocity
			can_double_jump = false
			action_tracker.record_double_jump()
			# Track double jump for analytics
			AnalyticsManager.track_jump()
			jump_performed.emit()

func apply_gravity(delta):
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		if velocity.y < 0:
			velocity.y = 0

func update_movement_state():
	# Track movement input for gun system
	move_input = Vector2(
		Input.get_action_strength("action_move_right") - Input.get_action_strength("action_move_left"),
		Input.get_action_strength("action_move_back") - Input.get_action_strength("action_move_forward")
	)
	
	var moving_now = move_input.length() > movement_input_threshold
	
	if moving_now and not is_moving:
		is_moving = true
		movement_started.emit()
		
	elif not moving_now and is_moving:
		is_moving = false
		movement_stopped.emit()
		


func update_floor_state():
	if not is_on_floor() and was_on_floor:
		# Just left the ground
		pass
	elif is_on_floor() and not was_on_floor:
		# Just landed
		landed.emit()
		
		# If crouched and crouch key isn't held, try to stand up
		if is_crouching and not Input.is_action_pressed("action_crouch") and not is_sliding:
			if can_stand_up():
				stand()
	
	was_on_floor = is_on_floor()

func update_action_tracking():
	# Track sprinting state changes
	if is_sprinting and not was_sprinting:
		action_tracker.record_sprint_start()
	elif not is_sprinting and was_sprinting:
		action_tracker.record_sprint_stop()
	
	# Track crouching state changes (but not during sliding)
	if is_crouching and not was_crouching and not is_sliding and is_on_floor():
		action_tracker.record_crouch_start()
	elif not is_crouching and was_crouching and not is_sliding and is_on_floor():
		action_tracker.record_crouch_stop()
	
	# Track sliding state changes
	if is_sliding and not was_sliding:
		action_tracker.record_slide_start()
	elif not is_sliding and was_sliding:
		action_tracker.record_slide_stop()
	
	# Update previous states
	was_sprinting = is_sprinting
	was_crouching = is_crouching
	was_sliding = is_sliding

# === DASH SYSTEM ===
func can_dash() -> bool:
	return not is_dashing and dash_cooldown_timer <= 0.0

func perform_dash():
	if not can_dash():
		return
	
	var dash_direction = get_dash_direction()
	
	is_dashing = true
	dash_timer = dash_duration
	dash_cooldown_timer = dash_cooldown
	dash_velocity = dash_direction * dash_speed
	
	# Track dash usage for analytics
	AnalyticsManager.track_dash()
	
	dash_performed.emit()

func get_dash_direction() -> Vector3:
	# Use movement input if available, otherwise forward
	if move_input.length() > movement_input_threshold:
		var forward = -transform.basis.z
		var right = transform.basis.x
		return (forward * -move_input.y + right * move_input.x).normalized()
	else:
		return -transform.basis.z

func end_dash():
	is_dashing = false
	# Dash velocity will naturally decelerate in handle_movement_input

# === CROUCH/SLIDE SYSTEM ===
func crouch():
	is_crouching = true
	# Change collision shape height
	var shape = collision_shape.shape as CapsuleShape3D
	shape.height = crouch_height
	
	# Change visual mesh height  
	if mesh.mesh is CapsuleMesh:
		(mesh.mesh as CapsuleMesh).height = crouch_height

func stand():
	is_crouching = false
	# Restore collision shape height
	var shape = collision_shape.shape as CapsuleShape3D
	shape.height = stand_height
	
	# Restore visual mesh height
	if mesh.mesh is CapsuleMesh:
		(mesh.mesh as CapsuleMesh).height = stand_height

func can_stand_up() -> bool:
	# Check if there's room above to stand up
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, crouch_height/2, 0),
		global_position + Vector3(0, stand_height/2 + stand_clearance, 0),
		collision_mask
	)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	return result.is_empty()

func start_slide():
	is_sliding = true
	slide_timer = slide_time
	crouch()
	# Track slide usage for analytics
	AnalyticsManager.track_slide()

func end_slide():
	is_sliding = false
	stand()

# === UTILITY FUNCTIONS ===
func get_input_direction() -> Vector3:
	var dir = Vector3.ZERO
	if Input.is_action_pressed("action_move_forward"):
		dir.z -= 1
	if Input.is_action_pressed("action_move_back"):
		dir.z += 1
	if Input.is_action_pressed("action_move_left"):
		dir.x -= 1
	if Input.is_action_pressed("action_move_right"):
		dir.x += 1
	return dir.normalized()

func get_camera_direction() -> Vector3:
	return camera.global_transform.basis.z.normalized()

# === PUBLIC API FOR GUN SYSTEM ===
func is_player_moving() -> bool:
	return is_moving

func is_player_dashing() -> bool:
	return is_dashing

# === TIME ENERGY SYSTEM SIGNAL HANDLERS ===

func _on_movement_locked():
	"""Called when energy system locks player movement."""
	if debug_energy:
		print("Player received movement lock signal")
	# Force stop any current movement
	velocity.x = 0
	velocity.z = 0
	# Reset movement intent
	movement_intent = 0.0

func _on_movement_unlocked():
	"""Called when energy system unlocks player movement."""
	if debug_energy:
		print("Player received movement unlock signal")

func _on_energy_depleted():
	"""Called when energy is completely depleted."""
	if debug_energy:
		print("Player received energy depleted signal")
	# Could add visual/audio feedback here

func _on_energy_restored():
	"""Called when energy is restored after depletion."""
	if debug_energy:
		print("Player received energy restored signal")
	# Could add visual/audio feedback here

# === INPUT ENABLE/DISABLE SYSTEM ===
func set_input_enabled(enabled: bool):
	"""Enable or disable player input and movement."""
	if enabled:
		# Enable player
		set_process_input(true)
		set_process(true)
		set_physics_process(true)
		
		# Enable gun
		if gun:
			gun.set_process(true)
			gun.set_physics_process(true)
			gun.set_process_input(true)
			if gun.has_method("set_enabled"):
				gun.set_enabled(true)
		
		# Enable camera
		if camera:
			camera.set_process_input(true)
	else:
		# Disable player
		velocity = Vector3.ZERO
		set_process_input(false)
		set_process(false)
		set_physics_process(false)
		
		# Disable gun
		if gun:
			gun.set_process(false)
			gun.set_physics_process(false)
			gun.set_process_input(false)
			if gun.has_method("set_enabled"):
				gun.set_enabled(false)
		
		# Disable camera
		if camera:
			camera.set_process_input(false)

# === DAMAGE SYSTEM ===
signal player_died

func take_damage(damage: int) -> bool:
	"""Player takes damage - any damage kills the player. Returns true if damage was taken."""
	# Check if damage should be prevented due to time dilation
	var time_manager = get_node_or_null("/root/TimeManager")
	if time_manager and time_manager.is_damage_prevented():
		if debug_damage:
			print("Player: Damage prevented due to time dilation (", time_manager.get_time_scale(), ")")
		return false  # Damage was prevented
	
	if debug_damage:
		print("Player took damage: ", damage, " - Player dies!")
	
	# Play death SFX
	if AudioManager:
		AudioManager.play_sfx("player_death", 1.0)
	
	# Emit death signal
	print("Player: Emitting player_died signal")
	print("Player: Signal connections: ", player_died.get_connections().size())
	for connection in player_died.get_connections():
		print("Player: Connected to: ", connection.callable)
	player_died.emit()
	print("Player: player_died signal emitted")
	
	# Use the unified disable method
	set_input_enabled(false)
	
	# Optional: Add death visual/audio effects here
	# For now, just print death message
	if debug_damage:
		print("PLAYER DIED - Game Over!")
	
	return true  # Damage was taken

# === GUN PICKUP SYSTEM ===

func _try_pickup_gun() -> bool:
	"""Try to pick up a gun if player is overlapping with it."""
	# Check if we already have a gun equipped
	if gun and gun.has_method("is_equipped") and gun.is_equipped():
		return false
	
	# Find gun pickups and try to pick up (they check overlap internally)
	var gun_pickups = get_tree().get_nodes_in_group("gun_pickups")
	
	for pickup in gun_pickups:
		if pickup is Area3D and is_instance_valid(pickup):
			# Try to pick up - the pickup itself checks if player is in range
			if pickup.has_method("try_pickup") and pickup.try_pickup(self):
				return true
	
	return false

# === BULLET PICKUP SYSTEM ===

func _try_pickup_bullet():
	"""Try to pick up the currently interactable bullet."""
	# Check time conditions
	if not time_manager:
		return false
	
	var current_time_scale = time_manager.get_time_scale()
	if current_time_scale > pickup_time_threshold:
		if debug_pickup:
			print("Bullet pickup failed: time scale too high (", current_time_scale, " > ", pickup_time_threshold, ")")
		return false
	
	# Check ammo capacity
	if gun and gun.get_current_ammo() >= gun.get_max_ammo():
		if debug_pickup:
			print("Bullet pickup failed: ammo full")
		return false
	
	# Use the currently highlighted bullet (if any)
	if not current_interactable_bullet or not is_instance_valid(current_interactable_bullet):
		if debug_pickup:
			print("Bullet pickup failed: no interactable bullet")
		return false
	
	# Tell gun to add ammo
	if gun and gun.has_method("pickup_bullet"):
		var pickup_success = gun.pickup_bullet()
		if pickup_success:
			current_interactable_bullet.queue_free()
			current_interactable_bullet = null
			
			# Trigger movement slowdown for time scaling effect
			pickup_slowdown_timer = pickup_slowdown_duration
			
			if debug_pickup:
				print("Bullet picked up! Movement slowdown active for ", pickup_slowdown_duration, "s")
			
			return true
	
	return false

# === BULLET RECALL SYSTEM ===

func _try_recall_bullet():
	"""Try to recall the most recently fired bullet."""
	if TracerManager:
		var success = TracerManager.recall_most_recent_bullet()
		if debug_pickup:
			if success:
				print("Player: Bullet recall successful!")
			else:
				print("Player: No bullets available for recall")
	else:
		if debug_pickup:
			print("Player: TracerManager not found - cannot recall bullets")

# === BULLET DEFLECTION SYSTEM ===

func _try_deflect_bullet():
	"""Try to deflect the currently interactable bullet."""
	# Check cooldown
	if deflect_cooldown_timer > 0.0:
		if debug_deflection:
			print("Deflection on cooldown")
		return false
	
	# Use the currently highlighted bullet (if any)
	if not current_interactable_bullet or not is_instance_valid(current_interactable_bullet):
		if debug_deflection:
			print("No interactable bullet to deflect")
		return false
	
	# Get deflection direction (where player is looking)
	var deflect_direction = -camera.global_transform.basis.z.normalized()
	
	# Deflect the bullet (bullet will create its own effect)
	if current_interactable_bullet.has_method("deflect_bullet"):
		current_interactable_bullet.deflect_bullet(deflect_direction, deflect_speed_boost)
	else:
		if debug_deflection:
			print("ERROR: Bullet does not have deflect_bullet method")
		return false
	
	# Track deflection for analytics
	AnalyticsManager.track_deflection()
	
	# Start cooldown
	deflect_cooldown_timer = deflect_cooldown
	
	# Trigger movement slowdown for time scaling effect
	deflect_slowdown_timer = deflect_slowdown_duration
	
	if debug_deflection:
		print("Bullet deflected! Movement slowdown active for ", deflect_slowdown_duration, "s")
	return true


func _create_deflection_effect(position: Vector3):
	"""Create visual effect at deflection point."""
	var deflect_scene = load("res://scenes/effects/BulletDeflect.tscn")
	if not deflect_scene:
		if debug_deflection:
			print("WARNING: Could not load BulletDeflect.tscn")
		return
	
	var effect = deflect_scene.instantiate()
	get_tree().current_scene.add_child(effect)
	effect.global_position = position
	
	if debug_deflection:
		print("Deflection effect created at: ", position)

# === UNIFIED BULLET INTERACTION SYSTEM ===

func _update_bullet_interaction_highlight():
	"""Update which bullet (if any) should be highlighted as interactable."""
	# Find the closest interactable bullet
	var interactable_bullet = _find_interactable_bullet()
	
	# If the interactable bullet changed, update highlighting
	if interactable_bullet != current_interactable_bullet:
		# Unhighlight previous bullet
		if current_interactable_bullet and is_instance_valid(current_interactable_bullet):
			if current_interactable_bullet.has_method("set_highlight"):
				current_interactable_bullet.set_highlight(false)
		
		# Highlight new bullet
		if interactable_bullet and interactable_bullet.has_method("set_highlight"):
			interactable_bullet.set_highlight(true)
		
		# Update tracked bullet
		current_interactable_bullet = interactable_bullet

func _find_interactable_bullet() -> Node:
	"""Find the closest bullet that is on-screen and in range."""
	if not camera:
		return null
	
	var all_bullets = get_tree().get_nodes_in_group("bullets")
	var camera_pos = camera.global_position
	var viewport = get_viewport()
	
	var closest_bullet = null
	var closest_distance = INF
	
	for bullet in all_bullets:
		if not bullet or not is_instance_valid(bullet):
			continue
		
		# Skip unfired bullets
		if not bullet.has_been_fired:
			continue
		
		# Check distance
		var distance = camera_pos.distance_to(bullet.global_position)
		if distance > bullet_interaction_range:
			continue
		
		# Check if on-screen (simple frustum check)
		if not _is_position_on_screen(bullet.global_position):
			continue
		
		# This bullet is valid and closer
		if distance < closest_distance:
			closest_distance = distance
			closest_bullet = bullet
	
	return closest_bullet

func _is_position_on_screen(world_position: Vector3) -> bool:
	"""Check if a 3D world position is visible on the player's screen."""
	if not camera:
		return false
	
	# Project world position to screen coordinates
	var screen_pos = camera.unproject_position(world_position)
	var viewport_rect = get_viewport().get_visible_rect()
	
	# Check if within viewport bounds
	return viewport_rect.has_point(screen_pos)

# === TARGET POSITION FOR ENEMIES ===
func get_camera_position() -> Vector3:
	"""Get the raw camera position without any offset."""
	if camera:
		return camera.global_position
	else:
		# Fallback to player center if camera not found
		return global_position

func get_target_position(shooter_position: Vector3 = Vector3.ZERO) -> Vector3:
	"""Get the position enemies should aim at - targets player's head/chest area."""
	# Return camera position with a slight downward adjustment to aim at chest level
	# This feels more natural than aiming at the very top of the head
	return get_camera_position() + Vector3.DOWN * target_position_offset
