extends Node3D

@export var fire_delay: float = 0.2
@export var burst_count: int = 3
@export var burst_interval: float = 0.1
@export var charge_time: float = 1.0
@export var power_dash_damage: int = 100
@export var dash_damage: int = 50

@export var fire_rate_start: float = 0.5 # seconds between shots at start
@export var fire_rate_min: float = 0.08  # minimum seconds between shots
@export var fire_rate_accel: float = 0.05 # how much to decrease interval per shot

@export var dash_speed: float = 30.0
@export var dash_duration: float = 0.2
@export var mega_dash_multiplier: float = 3.0

@onready var BulletScene = preload("res://scenes/bullet.tscn")

var charging: bool = false
var charge_timer: float = 0.0
var is_charged: bool = false
var firing: bool = false
var fire_timer: Timer = null
var current_fire_rate: float = fire_rate_start
var burst_shots_left: int = 0
var burst_timer: Timer = null

var dash_timer: Timer = null
var is_dashing: bool = false
var mega_dash_ready: bool = false

signal dash_requested(direction: Vector3, is_mega_dash: bool)
signal dash_ended

func _ready():
	var player = get_parent()
	player.started_moving.connect(_on_started_moving)
	player.stopped_moving.connect(_on_stopped_moving)
	player.jumped.connect(_on_jumped)
	player.started_wallrun.connect(_on_started_wallrun)
	player.took_damage.connect(_on_took_damage)
	# If player starts game standing still, begin charging
	if not player.is_moving:
		_on_stopped_moving()

func _on_started_moving():
	stop_charging()
	start_firing()

func _on_stopped_moving():
	stop_firing()
	start_charging()

func start_firing():
	if firing:
		return
	firing = true
	current_fire_rate = fire_rate_start
	_fire_loop()

func stop_firing():
	firing = false
	if fire_timer and fire_timer.is_inside_tree():
		fire_timer.queue_free()
	current_fire_rate = fire_rate_start

func _fire_loop():
	if not firing:
		return
	_fire()
	# Ramp up fire rate
	current_fire_rate = max(fire_rate_min, current_fire_rate - fire_rate_accel)
	fire_timer = Timer.new()
	fire_timer.wait_time = current_fire_rate
	fire_timer.one_shot = true
	fire_timer.timeout.connect(_fire_loop)
	add_child(fire_timer)
	fire_timer.start()

func start_charging():
	charging = true
	is_charged = false
	charge_timer = 0.0
	mega_dash_ready = false

func stop_charging():
	charging = false
	charge_timer = 0.0
	is_charged = false

# Remove all polling for mega dash in _process()
func _process(delta: float) -> void:
	if charging:
		charge_timer += delta
		if charge_timer >= charge_time and not is_charged:
			is_charged = true
			# Charging complete, ready for power dash
	# No dash logic here; handled by Player.gd dash() event

func _on_jumped():
	# Fire burst
	burst_shots_left = burst_count
	_fire_burst()

func _on_started_wallrun():
	_fire_piercing_shot()

func _on_took_damage():
	stop_charging()

func _fire():
	var bullet = BulletScene.instantiate()
	get_tree().current_scene.add_child(bullet)
	# Spawn at gun's position, offset forward
	var forward = -get_parent().get_camera_direction()
	var spawn_pos = global_transform.origin + forward * 1.0 # 1.0 units in front of gun
	bullet.global_position = spawn_pos
	bullet.fire(forward)

func _fire_burst():
	if burst_shots_left > 0:
		# Placeholder: print("Gun fires burst shot")
		burst_shots_left -= 1
		if burst_timer and burst_timer.is_inside_tree():
			burst_timer.queue_free()
		burst_timer = Timer.new()
		burst_timer.wait_time = burst_interval
		burst_timer.one_shot = true
		burst_timer.timeout.connect(_fire_burst)
		add_child(burst_timer)
		burst_timer.start()

func _fire_piercing_shot():
	# Placeholder: print("Gun fires piercing shot (wallrun)")
	pass

func trigger_power_dash():
	# Placeholder: print("Power Dash triggered! High damage.")
	pass

func trigger_dash(direction: Vector3, is_mega_dash: bool=false):
	if is_dashing:
		return
	is_dashing = true
	dash_requested.emit(direction, is_mega_dash)
	dash_timer = Timer.new()
	dash_timer.wait_time = dash_duration
	dash_timer.one_shot = true
	dash_timer.timeout.connect(_end_dash)
	add_child(dash_timer)
	dash_timer.start()

func _end_dash():
	is_dashing = false
	dash_ended.emit()
	# Do not zero velocity; momentum continues 
