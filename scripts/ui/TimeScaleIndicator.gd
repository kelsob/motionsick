extends Label

# === TIME SCALE DEBUG INDICATOR ===
# Shows current time scale as a number with color coding

## === EXPORTED CONFIGURATION ===
@export_group("Display Settings")
## Update rate in seconds
@export var update_rate: float = 0.05
## Number format (decimal places)
@export var decimal_places: int = 2

@export_group("Color Settings")
## Color at full stop (time scale = 0.0)
@export var color_full_stop: Color = Color.RED
## Color at full speed (time scale = 1.0)
@export var color_full_speed: Color = Color.GREEN

## === RUNTIME STATE ===
var time_manager: Node = null
var update_timer: float = 0.0

func _ready():
	# Get TimeManager reference
	time_manager = get_node_or_null("/root/TimeManager")
	if not time_manager:
		print("TimeScaleIndicator: WARNING - TimeManager not found!")
		text = "ERROR"
		return
	
	# Initial update
	_update_display()

func _process(delta: float):
	if not time_manager:
		return
	
	# Throttle updates
	update_timer += delta
	if update_timer >= update_rate:
		update_timer = 0.0
		_update_display()

func _update_display():
	"""Update the label text and color based on current time scale."""
	if not time_manager:
		return
	
	var time_scale = time_manager.get_time_scale()
	
	# Update text
	var format_string = "%." + str(decimal_places) + "f"
	text = format_string % time_scale
	
	# Update color (lerp between red and green)
	modulate = color_full_stop.lerp(color_full_speed, time_scale)

