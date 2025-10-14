extends Label
class_name TimerLabel

# === TIME-DILATED TIMER LABEL ===
# Shows game time that respects TimeManager's time scale

# === STATE ===
var elapsed_time: float = 0.0
var time_manager: Node = null

func _ready():
	# Connect to TimeManager
	time_manager = get_node_or_null("/root/TimeManager")
	if not time_manager:
		print("TimerLabel: WARNING - TimeManager not found!")
	
	# Connect to GameManager for restart events
	var game_manager = get_node_or_null("/root/GameManager")
	if game_manager:
		game_manager.game_restart_requested.connect(_on_game_restart)
	
	# Initialize display
	text = "00:00"

func _on_game_restart():
	"""Reset timer when game restarts."""
	reset_timer()

func _process(delta: float):
	# Update elapsed time using time-adjusted delta
	var time_delta = delta
	if time_manager:
		var time_scale = time_manager.get_time_scale()
		time_delta = delta * time_scale
	
	elapsed_time += time_delta
	
	# Update display
	_update_display()

func _update_display():
	"""Update the label text with formatted time."""
	var minutes = int(elapsed_time / 60.0)
	var seconds = int(elapsed_time) % 60
	
	# Format as MM:SS
	text = "%02d:%02d" % [minutes, seconds]

func reset_timer():
	"""Reset the timer to zero."""
	elapsed_time = 0.0

func get_elapsed_time() -> float:
	"""Get the current elapsed time in seconds."""
	return elapsed_time

func set_elapsed_time(time: float):
	"""Set the elapsed time (useful for save/load)."""
	elapsed_time = max(0.0, time)
