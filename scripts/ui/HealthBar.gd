extends Control
class_name HealthBar

# Health bar components
@onready var background: NinePatchRect = $Background
@onready var health_fill: NinePatchRect = $Background/HealthFill
@onready var health_label: Label = $Background/HealthLabel

# Health properties
var max_health := 100.0
var current_health := 100.0
var target_health := 100.0

# Visual properties
var fill_speed := 2.0
var low_health_threshold := 25.0
var critical_health_threshold := 10.0

# Colors
var normal_color := Color.GREEN
var low_health_color := Color.YELLOW
var critical_health_color := Color.RED

func _ready():
	setup_health_bar()
	update_display()

func _process(delta):
	# Smooth health bar animation
	if abs(current_health - target_health) > 0.1:
		current_health = lerp(current_health, target_health, fill_speed * delta)
		update_display()

func setup_health_bar():
	# Position health bar in top-left corner
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	position = Vector2(20, 20)
	size = Vector2(200, 30)

func set_health(health: float):
	target_health = clamp(health, 0, max_health)

func set_max_health(max_hp: float):
	max_health = max_hp
	if current_health > max_health:
		set_health(max_health)

func damage(amount: float):
	set_health(current_health - amount)
	show_damage_effect()

func heal(amount: float):
	set_health(current_health + amount)

func update_display():
	if not health_fill or not health_label:
		return
	
	# Update fill amount
	var health_percentage = current_health / max_health
	health_fill.size.x = (size.x - 4) * health_percentage  # -4 for border
	
	# Update color based on health percentage
	var health_color = get_health_color(health_percentage)
	health_fill.modulate = health_color
	
	# Update label
	health_label.text = "%d / %d" % [current_health, max_health]

func get_health_color(percentage: float) -> Color:
	if percentage <= critical_health_threshold / 100.0:
		return critical_health_color
	elif percentage <= low_health_threshold / 100.0:
		return low_health_color
	else:
		return normal_color

func show_damage_effect():
	# Flash effect when taking damage
	var tween = create_tween()
	var original_modulate = modulate
	tween.tween_property(self, "modulate", Color.RED, 0.1)
	tween.tween_property(self, "modulate", original_modulate, 0.1)

func pulse_low_health():
	# Pulse effect for low health
	if current_health <= critical_health_threshold:
		var tween = create_tween()
		tween.set_loops()
		tween.tween_property(self, "modulate:a", 0.5, 0.5)
		tween.tween_property(self, "modulate:a", 1.0, 0.5) 