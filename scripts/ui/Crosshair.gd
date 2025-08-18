extends Control

@onready var up_pip = $TextureRect1
@onready var right_pip = $TextureRect2
@onready var down_pip = $TextureRect3
@onready var left_pip = $TextureRect4

# Animation settings
@export var spread_distance: float = 10.0  # How far pips spread out
@export var spread_duration: float = 0.1   # How long to spread out
@export var return_duration: float = 0.3   # How long to return to center

# Store original positions
var original_positions: Dictionary = {}
var gun_reference: Node3D = null

func _ready():
	# Store original positions of all pips
	original_positions["up"] = up_pip.position
	original_positions["right"] = right_pip.position
	original_positions["down"] = down_pip.position
	original_positions["left"] = left_pip.position
	
	# Connect to gun firing signal
	_connect_to_gun()

func _connect_to_gun():
	"""Find and connect to the gun's firing signal."""
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("Crosshair: Could not find player!")
		return
	
	var camera = player.get_node("Camera3D")
	if not camera:
		print("Crosshair: Could not find camera!")
		return
	
	var gun = camera.get_node("Gun")
	if not gun:
		print("Crosshair: Could not find gun!")
		return
	
	gun_reference = gun
	
	# Connect to the fired_shot signal
	if gun.has_signal("fired_shot"):
		gun.fired_shot.connect(_on_gun_fired)
		print("Crosshair: Connected to gun firing signal")
	else:
		print("Crosshair: Gun has no fired_shot signal!")

func _on_gun_fired(damage: int):
	"""Called when the gun fires - animate crosshair spread."""
	animate_crosshair_spread()

func animate_crosshair_spread():
	"""Animate the crosshair pips spreading out and returning."""
	# Calculate spread positions
	var up_spread = original_positions["up"] + Vector2(0, -spread_distance)
	var right_spread = original_positions["right"] + Vector2(spread_distance, 0)
	var down_spread = original_positions["down"] + Vector2(0, spread_distance)
	var left_spread = original_positions["left"] + Vector2(-spread_distance, 0)
	
	# Create tween for animation
	var tween = create_tween()
	tween.set_parallel(true)  # Allow multiple properties to animate simultaneously
	
	# Spread out phase
	tween.tween_property(up_pip, "position", up_spread, spread_duration)
	tween.tween_property(right_pip, "position", right_spread, spread_duration)
	tween.tween_property(down_pip, "position", down_spread, spread_duration)
	tween.tween_property(left_pip, "position", left_spread, spread_duration)
	
	# Return phase (starts after spread completes)
	tween.tween_property(up_pip, "position", original_positions["up"], return_duration).set_delay(spread_duration)
	tween.tween_property(right_pip, "position", original_positions["right"], return_duration).set_delay(spread_duration)
	tween.tween_property(down_pip, "position", original_positions["down"], return_duration).set_delay(spread_duration)
	tween.tween_property(left_pip, "position", original_positions["left"], return_duration).set_delay(spread_duration)
