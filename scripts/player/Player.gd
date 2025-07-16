extends CharacterBody3D

# Player movement parameters
const WALK_SPEED := 6.0
const SPRINT_SPEED := 12.0
const CROUCH_SPEED := 3.0
const SLIDE_SPEED := 16.0
const JUMP_VELOCITY := 7.0
const DOUBLE_JUMP_VELOCITY := 7.0
@onready var GRAVITY: float = ProjectSettings.get_setting("physics/3d/default_gravity")
const CROUCH_HEIGHT := 1.0
const STAND_HEIGHT := 1.5
const SLIDE_TIME := 0.5

var is_sprinting := false
var is_crouching := false
var is_sliding := false
var can_double_jump := false
var slide_timer := 0.0
var dash_velocity: Vector3 = Vector3.ZERO

@onready var collision_shape: CollisionShape3D = $CollisionShape3D
@onready var mesh: MeshInstance3D = $MeshInstance3D
@onready var camera: Camera3D = $Camera3D

# --- Gun system signals ---
signal started_moving
signal stopped_moving
signal jumped
signal landed
signal started_wallrun
signal stopped_wallrun
signal took_damage

var move_input: Vector2 = Vector2.ZERO
var is_moving: bool = false
var was_on_floor: bool = true

func _ready():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	$Gun.dash_requested.connect(_on_dash_requested)
	$Gun.dash_ended.connect(_on_dash_ended)

func _unhandled_input(event):
	if event is InputEventMouseMotion:
		# Camera handled in camera script
		pass
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _physics_process(delta):
	var input_dir = get_input_direction()
	var move_speed = WALK_SPEED

	# Sprinting
	is_sprinting = Input.is_action_pressed("action_sprint") and not is_crouching and not is_sliding
	if is_sprinting:
		move_speed = SPRINT_SPEED

	# Crouching
	if Input.is_action_pressed("action_crouch") and not is_sliding:
		if not is_crouching:
			crouch()
		move_speed = CROUCH_SPEED
	else:
		if is_crouching and not is_sliding:
			stand()

	# Sliding
	if Input.is_action_just_pressed("action_slide") and is_sprinting and is_on_floor() and not is_sliding:
		start_slide()
	if is_sliding:
		slide_timer -= delta
		move_speed = SLIDE_SPEED
		if slide_timer <= 0.0 or not Input.is_action_pressed("action_slide"):
			end_slide()

	# Jumping
	if Input.is_action_just_pressed("action_jump"):
		if is_on_floor():
			velocity.y = JUMP_VELOCITY
			can_double_jump = true
		elif can_double_jump:
			velocity.y = DOUBLE_JUMP_VELOCITY
			can_double_jump = false

	# Bunny hop: preserve some velocity if jumping right after landing
	if is_on_floor() and abs(velocity.y) < 0.1:
		if Input.is_action_pressed("action_jump"):
			velocity.y = JUMP_VELOCITY
			can_double_jump = true

	# Apply movement
	var direction = (global_transform.basis * input_dir).normalized()
	velocity.x = direction.x * move_speed + dash_velocity.x
	velocity.z = direction.z * move_speed + dash_velocity.z

	# Gravity
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		if velocity.y < 0:
			velocity.y = 0

	move_and_slide()

	# --- Gun system state detection ---
	move_input = Vector2(
		Input.get_action_strength("action_move_right") - Input.get_action_strength("action_move_left"),
		Input.get_action_strength("action_move_back") - Input.get_action_strength("action_move_forward")
	)
	var moving_now: bool = move_input.length() > 0.1
	if moving_now and not is_moving:
		is_moving = true
		started_moving.emit()
		# Mega dash if gun is charged
		if $Gun.is_charged:
			var dash_dir: Vector3 = Vector3.ZERO
			if move_input.length() > 0.1:
				var forward: Vector3 = -transform.basis.z
				var right: Vector3 = transform.basis.x
				dash_dir = (forward * -move_input.y + right * move_input.x).normalized()
			else:
				dash_dir = -transform.basis.z
			$Gun.trigger_dash(dash_dir, true) # Mega dash
	elif not moving_now and is_moving:
		is_moving = false
		stopped_moving.emit()

	if not is_on_floor() and was_on_floor:
		jumped.emit()
	elif is_on_floor() and not was_on_floor:
		landed.emit()
	was_on_floor = is_on_floor()

	# Wallrun detection placeholder (implement your own logic)
	# if wallrun_started:
	#     started_wallrun.emit()
	# if wallrun_stopped:
	#     stopped_wallrun.emit()

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

func crouch():
	is_crouching = true
	var shape = collision_shape.shape as CapsuleShape3D
	shape.height = CROUCH_HEIGHT
	mesh.mesh.height = CROUCH_HEIGHT
	position.y = 0.5

func stand():
	is_crouching = false
	var shape = collision_shape.shape as CapsuleShape3D
	shape.height = STAND_HEIGHT
	mesh.mesh.height = STAND_HEIGHT
	position.y = 1.0

func start_slide():
	is_sliding = true
	slide_timer = SLIDE_TIME
	crouch()

func end_slide():
	is_sliding = false
	stand()

# --- Gun system dash trigger ---
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("action_dash"):
		dash()

func _on_dash_requested(direction: Vector3, is_mega_dash: bool):
	# Set dash velocity for dash duration
	var speed = $Gun.dash_speed
	if is_mega_dash:
		speed *= $Gun.mega_dash_multiplier
		$Gun.stop_charging()
	dash_velocity = direction * speed
	# Momentum continues after dash

func dash() -> void:
	# Dash in movement direction, or forward if no input
	var dash_dir: Vector3 = Vector3.ZERO
	if move_input.length() > 0.1:
		var forward: Vector3 = -transform.basis.z
		var right: Vector3 = transform.basis.x
		dash_dir = (forward * -move_input.y + right * move_input.x).normalized()
	else:
		dash_dir = -transform.basis.z
	var gun: Node = $Gun
	if gun and gun.has_method("trigger_dash"):
		# Always check for mega dash if charged
		if gun.is_charged:
			if not is_moving:
				is_moving = true
				started_moving.emit()
			gun.trigger_dash(dash_dir, true) # Mega dash
			gun.stop_charging()
			
			print("mega dash!")
		else:
			# If not charged, do a normal dash
			if not is_moving:
				is_moving = true
				started_moving.emit()
			gun.trigger_dash(dash_dir, false) # Normal dash
			print("dash!")

func _on_dash_ended():
	# Clear dash velocity when dash ends
	dash_velocity = Vector3.ZERO
	# If no movement input, consider player stopped and start charging
	if move_input.length() <= 0.1 and is_moving:
		is_moving = false
		stopped_moving.emit()

# Call this method from your damage logic to notify the gun
func notify_took_damage() -> void:
	took_damage.emit() 

func get_camera_direction():
	return camera.global_transform.basis.z.normalized()
	
