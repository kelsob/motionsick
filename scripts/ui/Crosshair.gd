extends Control
class_name Crosshair

# Crosshair elements
@onready var center_dot: Control = $CenterDot
@onready var top_line: Control = $TopLine
@onready var bottom_line: Control = $BottomLine
@onready var left_line: Control = $LeftLine
@onready var right_line: Control = $RightLine

# Crosshair properties
var base_gap := 10.0
var current_gap := 10.0
var base_thickness := 2.0
var line_length := 15.0

# Dynamic behavior
var spread_amount := 0.0
var max_spread := 30.0
var spread_recovery_speed := 5.0

# Colors
var normal_color := Color.WHITE
var hit_color := Color.RED
var enemy_color := Color.ORANGE

func _ready():
	# Center the crosshair
	set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	setup_crosshair_elements()

func _process(delta):
	update_spread(delta)
	update_crosshair_position()

func setup_crosshair_elements():
	# This will be called to set up the visual elements
	# The actual visual setup will be done in the scene
	pass

func update_spread(delta):
	# Recover spread over time
	if spread_amount > 0:
		spread_amount = max(0, spread_amount - spread_recovery_speed * delta)
		current_gap = base_gap + spread_amount

func update_crosshair_position():
	if not center_dot or not top_line:
		return
	
	# Update line positions based on current gap
	var half_gap = current_gap / 2.0
	
	# Position crosshair lines
	if top_line:
		top_line.position = Vector2(0, -half_gap - line_length/2)
	if bottom_line:
		bottom_line.position = Vector2(0, half_gap + line_length/2)
	if left_line:
		left_line.position = Vector2(-half_gap - line_length/2, 0)
	if right_line:
		right_line.position = Vector2(half_gap + line_length/2, 0)

func add_spread(amount: float):
	spread_amount = min(max_spread, spread_amount + amount)

func show_hit_indicator():
	# Flash red when hitting an enemy
	var tween = create_tween()
	modulate = hit_color
	tween.tween_property(self, "modulate", normal_color, 0.2)

func set_crosshair_color(color: Color):
	modulate = color 
