extends Node

# === CLOCK TICK MANAGER ===
# Plays rhythmic clock ticks that respect time dilation
# Integrates with AudioManager for proper time scaling

## === EXPORTED CONFIGURATION ===
@export_group("Tick Timing")
## Interval between clock ticks in real-time seconds (twice as fast now for tick-tock)
@export var tick_interval: float = 0.5
## Enable clock ticking
@export var enable_ticking: bool = true
## Auto-start ticking when level loads
@export var auto_start: bool = true

@export_group("Tick-Tock System")
## Enable alternating tick-tock sounds
@export var enable_tick_tock: bool = true
## Pitch offset for "tock" sound (higher = more tock-like)
@export var tock_pitch_offset: float = 0.15

@export_group("Stereo Effects")
## Enable left/right speaker alternation
@export var enable_stereo_alternation: bool = true
## Pan amount for stereo effect (-1.0 = full left, 1.0 = full right)
@export var stereo_pan_amount: float = 0.7

@export_group("Debug Settings")
## Enable debug output for tick events
@export var debug_ticking: bool = false

## === RUNTIME STATE ===
var is_ticking: bool = false
var tick_timer: float = 0.0
var time_manager: Node = null
var current_pan_left: bool = true  # Alternate between left and right
var is_tick_turn: bool = true  # Alternate between tick and tock

## === SIGNALS ===
signal tick_played()
signal ticking_started()
signal ticking_stopped()

func _ready():
	# Connect to TimeManager
	time_manager = get_node_or_null("/root/TimeManager")
	if not time_manager:
		if debug_ticking:
			print("ClockTickManager: WARNING - TimeManager not found!")
	
	# Auto-start if enabled
	if auto_start:
		start_ticking()
	
	if debug_ticking:
		print("ClockTickManager: Initialized as scene node - auto_start: ", auto_start)

func _process(delta: float):
	if not is_ticking or not enable_ticking:
		return
	
	# Use time-adjusted delta to respect time scale
	var time_delta = delta
	if time_manager:
		var time_scale = time_manager.get_time_scale()
		time_delta = delta * time_scale
	
	# Update tick timer
	tick_timer += time_delta
	
	# Check if it's time for a tick
	if tick_timer >= tick_interval:
		_play_tick()
		tick_timer = 0.0  # Reset timer

func _play_tick():
	"""Play a single clock tick or tock with alternation."""
	if not AudioManager:
		if debug_ticking:
			print("ClockTickManager: AudioManager not found!")
		return
	
	# Determine if this is a tick or tock
	var is_tick = is_tick_turn
	var sound_type = "tick" if is_tick else "tock"
	
	# Calculate stereo pan for alternation
	var pan_value = 0.0
	if enable_stereo_alternation:
		pan_value = stereo_pan_amount if current_pan_left else -stereo_pan_amount
		current_pan_left = not current_pan_left  # Alternate for next tick
	
	# Play the tick/tock with pitch variation
	_play_tick_tock_sound(is_tick)
	
	# Alternate tick/tock for next time
	is_tick_turn = not is_tick_turn
	
	# Emit signal
	tick_played.emit()
	
	if debug_ticking:
		print("ClockTickManager: ", sound_type.capitalize(), " played (pan: ", "%.1f" % pan_value, ")")

func _play_tick_tock_sound(is_tick: bool):
	"""Play tick or tock sound with appropriate pitch offset."""
	if not enable_tick_tock:
		# Just play normal tick sound
		AudioManager.play_sfx("clock_tick")
		return
	
	# Play the sound through AudioManager to get proper volume
	var success = AudioManager.play_sfx("clock_tick")
	
	if success and not is_tick:
		# For "tock", adjust the pitch of the player that just started
		call_deferred("_adjust_tock_pitch")

func _adjust_tock_pitch():
	"""Adjust the pitch of the most recently played clock tick for 'tock' effect."""
	var player = _get_last_played_sfx_player()
	if player:
		# Get current time scale for proper pitch calculation
		var base_time_scale = time_manager.get_time_scale() if time_manager else 1.0
		var base_pitch = clamp(base_time_scale, 0.01, 2.0)
		
		# Apply tock pitch offset (higher pitch for "tock")
		var tock_pitch = base_pitch + tock_pitch_offset
		tock_pitch = clamp(tock_pitch, 0.01, 2.5)  # Allow slightly higher than normal max
		
		# Override the pitch while keeping AudioManager's volume calculation
		player.pitch_scale = tock_pitch
		
		if debug_ticking:
			print("ClockTickManager: Adjusted to tock pitch: ", tock_pitch, " (base: ", base_pitch, " + offset: ", tock_pitch_offset, ")")

func _get_last_played_sfx_player() -> AudioStreamPlayer:
	"""Get the SFX player that was just used (for pitch adjustment)."""
	if not AudioManager or AudioManager.sfx_players.size() == 0:
		return null
	
	# Get the previous player in the pool (the one that was just used)
	var last_index = (AudioManager.sfx_player_index - 1) % AudioManager.sfx_players.size()
	if last_index < 0:
		last_index = AudioManager.sfx_players.size() - 1
	
	var player = AudioManager.sfx_players[last_index]
	return player if player.playing else null

## === PUBLIC API ===

func start_ticking():
	"""Start the clock ticking."""
	if is_ticking:
		return
	
	is_ticking = true
	tick_timer = 0.0
	is_tick_turn = true  # Always start with "tick"
	current_pan_left = true  # Reset stereo alternation
	ticking_started.emit()
	
	if debug_ticking:
		print("ClockTickManager: Started ticking (interval: ", tick_interval, "s, tick-tock: ", enable_tick_tock, ")")

func stop_ticking():
	"""Stop the clock ticking."""
	if not is_ticking:
		return
	
	is_ticking = false
	tick_timer = 0.0
	ticking_stopped.emit()
	
	if debug_ticking:
		print("ClockTickManager: Stopped ticking")

func set_tick_interval(interval: float):
	"""Set the tick interval."""
	tick_interval = max(0.1, interval)  # Minimum 0.1 seconds
	if debug_ticking:
		print("ClockTickManager: Tick interval set to: ", tick_interval, "s")

func reset_tick_timer():
	"""Reset the tick timer (useful for synchronization)."""
	tick_timer = 0.0
	if debug_ticking:
		print("ClockTickManager: Tick timer reset")

func is_currently_ticking() -> bool:
	"""Check if clock is currently ticking."""
	return is_ticking and enable_ticking

## === LEVEL INTEGRATION ===

func configure_for_level(config: Dictionary):
	"""Configure clock ticking for a specific level."""
	if config.has("tick_interval"):
		set_tick_interval(config.tick_interval)
	
	if config.has("enable_ticking"):
		enable_ticking = config.enable_ticking
	
	if config.has("stereo_alternation"):
		enable_stereo_alternation = config.stereo_alternation
	
	if debug_ticking:
		print("ClockTickManager: Configured for level: ", config.keys())

func reset_for_level():
	"""Reset clock tick state for a new level."""
	stop_ticking()
	tick_timer = 0.0
	current_pan_left = true
	is_tick_turn = true  # Always start with "tick"
	
	if auto_start:
		start_ticking()
	
	if debug_ticking:
		print("ClockTickManager: Reset for new level")

## === DEBUG ===

func print_tick_status():
	"""Debug function to print current tick status."""
	print("\n=== CLOCK TICK MANAGER STATUS ===")
	print("Ticking enabled: ", enable_ticking)
	print("Currently ticking: ", is_ticking)
	print("Tick interval: ", tick_interval, "s (", 60.0/tick_interval, " BPM)")
	print("Timer progress: ", "%.2f" % tick_timer, "/", tick_interval, "s")
	print("Tick-tock enabled: ", enable_tick_tock)
	print("Next sound: ", "Tick" if is_tick_turn else "Tock")
	print("Tock pitch offset: +", tock_pitch_offset)
	print("Stereo alternation: ", enable_stereo_alternation)
	print("Current pan side: ", "Left" if current_pan_left else "Right")
	print("Time manager found: ", time_manager != null)
	print("==================================\n")
