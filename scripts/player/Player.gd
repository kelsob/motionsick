extends CharacterBody3D

# === MOVEMENT CONSTANTS ===
const WALK_SPEED := 10.0
const SPRINT_SPEED := 20.0
const CROUCH_SPEED := 5.0
const SLIDE_SPEED := 25.0
const JUMP_VELOCITY := 8.5
const DOUBLE_JUMP_VELOCITY := 8.5

# Dash systemLOL
const DASH_SPEED := 20.0
const DASH_DURATION := 0.25
const DASH_COOLDOWN := 0.5

# Smooth movement
const ACCELERATION := 3.0   # Slower acceleration (takes ~0.5 seconds to reach full speed)
const DECELERATION := 3.0   # Slower deceleration (takes ~0.3 seconds to stop)
const DASH_DECELERATION := 35.0

# Crouch system
const CROUCH_HEIGHT := 1.0
const STAND_HEIGHT := 1.5
const SLIDE_TIME := 0.5

@onready var GRAVITY: float = ProjectSettings.get_setting("physics/3d/default_gravity")

# === COMPONENTS ===
@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var camera: Camera3D = $Camera3D
@onready var gun: Node3D = $Camera3D/Gun
@onready var action_tracker: PlayerActionTracker = $PlayerActionTracker

# === MOVEMENT STATE ===
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
var movement_intent: float = 0.0  # 0.0 to 1.0, based on input not velocity

# Time system integration
var time_manager: Node = null
var time_energy_manager: Node = null

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
		print("Player connected to TimeManager")
	else:
		print("WARNING: Player can't find TimeManager!")
	
	# Connect to TimeEnergyManager
	time_energy_manager = get_node("/root/TimeEnergyManager")
	if time_energy_manager:
		print("Player connected to TimeEnergyManager")
		# Connect to energy manager signals
		time_energy_manager.movement_lock_started.connect(_on_movement_locked)
		time_energy_manager.movement_unlocked.connect(_on_movement_unlocked)
		time_energy_manager.energy_depleted.connect(_on_energy_depleted)
		time_energy_manager.energy_restored.connect(_on_energy_restored)
	else:
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

func _physics_process(delta):
	update_timers(delta)
	handle_movement_input(delta)
	apply_gravity(delta)
	move_and_slide()
	update_movement_state()
	update_floor_state()
	update_action_tracking()

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
	elif dash_velocity.length() > 0.01:
		# Decelerate dash velocity after dash ends
		var dash_speed = dash_velocity.length()
		dash_speed = max(0.0, dash_speed - DASH_DECELERATION * delta)
		dash_velocity = dash_velocity.normalized() * dash_speed
		target_velocity += dash_velocity
	
	# Apply acceleration/deceleration
	if direction.length() > 0.01 or dash_velocity.length() > 0.01:
		velocity.x = lerp(velocity.x, target_velocity.x, min(1.0, ACCELERATION * delta))
		velocity.z = lerp(velocity.z, target_velocity.z, min(1.0, ACCELERATION * delta))
	else:
		velocity.x = lerp(velocity.x, 0.0, min(1.0, DECELERATION * delta))
		velocity.z = lerp(velocity.z, 0.0, min(1.0, DECELERATION * delta))

func get_movement_speed() -> float:
	if is_sliding:
		return SLIDE_SPEED
	elif is_crouching:
		return CROUCH_SPEED
	elif is_sprinting and not is_crouching:
		return SPRINT_SPEED
	else:
		return WALK_SPEED

func get_movement_speed_percentage() -> float:
	var speed_percentage : float = velocity.length() / WALK_SPEED
	if speed_percentage >= 0.99:
		speed_percentage = 1.0
	elif speed_percentage <= 0.01:
		speed_percentage = 0
	print("player movement speed percentage:", speed_percentage)
	return speed_percentage

func update_movement_intent(delta: float):
	"""Update movement intent based on input keys, not actual velocity."""
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
		movement_intent = min(1.0, movement_intent + ACCELERATION * delta)
	else:
		# Decrease intent using same deceleration as movement
		movement_intent = max(0.0, movement_intent - DECELERATION * delta)
		
		# If movement is not allowed, force stop velocity immediately
		if not movement_allowed:
			velocity.x = 0.0
			velocity.z = 0.0
	
	# Send movement intent to energy manager
	if time_energy_manager:
		time_energy_manager.set_player_movement_intent(movement_intent)

func get_movement_intent() -> float:
	"""Get current movement intent (0.0 to 1.0) based on input, not velocity."""
	return movement_intent

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
			
			velocity.y = JUMP_VELOCITY
			can_double_jump = true
			action_tracker.record_jump()
			jump_performed.emit()
		elif can_double_jump:
			velocity.y = DOUBLE_JUMP_VELOCITY
			can_double_jump = false
			action_tracker.record_double_jump()
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
	
	var moving_now = move_input.length() > 0.1
	
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
	dash_timer = DASH_DURATION
	dash_cooldown_timer = DASH_COOLDOWN
	dash_velocity = dash_direction * DASH_SPEED
	
	dash_performed.emit()

func get_dash_direction() -> Vector3:
	# Use movement input if available, otherwise forward
	if move_input.length() > 0.1:
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
	shape.height = CROUCH_HEIGHT
	
	# Change visual mesh height  
	if mesh.mesh is CapsuleMesh:
		(mesh.mesh as CapsuleMesh).height = CROUCH_HEIGHT

func stand():
	is_crouching = false
	# Restore collision shape height
	var shape = collision_shape.shape as CapsuleShape3D
	shape.height = STAND_HEIGHT
	
	# Restore visual mesh height
	if mesh.mesh is CapsuleMesh:
		(mesh.mesh as CapsuleMesh).height = STAND_HEIGHT

func can_stand_up() -> bool:
	# Check if there's room above to stand up
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		global_position + Vector3(0, CROUCH_HEIGHT/2, 0),
		global_position + Vector3(0, STAND_HEIGHT/2 + 0.1, 0),
		collision_mask
	)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	return result.is_empty()

func start_slide():
	is_sliding = true
	slide_timer = SLIDE_TIME
	crouch()

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
	print("Player received movement lock signal")
	# Force stop any current movement
	velocity.x = 0
	velocity.z = 0
	# Reset movement intent
	movement_intent = 0.0

func _on_movement_unlocked():
	"""Called when energy system unlocks player movement."""
	print("Player received movement unlock signal")

func _on_energy_depleted():
	"""Called when energy is completely depleted."""
	print("Player received energy depleted signal")
	# Could add visual/audio feedback here

func _on_energy_restored():
	"""Called when energy is restored after depletion."""
	print("Player received energy restored signal")
	# Could add visual/audio feedback here 
