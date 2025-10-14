extends Label
class_name RealTimerLabel

# === REAL-TIME TIMER LABEL ===
# Shows actual real-world time elapsed, ignoring TimeManager's time scale

# === STATE ===
var elapsed_real_time: float = 0.0

func _ready():
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
	# Update elapsed time using pure delta (ignores time scale)
	elapsed_real_time += delta
	
	# Update display
	_update_display()

func _update_display():
	"""Update the label text with formatted time."""
	var minutes = int(elapsed_real_time / 60.0)
	var seconds = int(elapsed_real_time) % 60
	
	# Format as MM:SS
	text = "%02d:%02d" % [minutes, seconds]

func reset_timer():
	"""Reset the timer to zero."""
	elapsed_real_time = 0.0

func get_elapsed_time() -> float:
	"""Get the current elapsed real time in seconds."""
	return elapsed_real_time

func set_elapsed_time(time: float):
	"""Set the elapsed time (useful for save/load)."""
	elapsed_real_time = max(0.0, time)
