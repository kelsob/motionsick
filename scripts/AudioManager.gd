extends Node

# === DEBUG FLAGS (EASY TOGGLE) ===
const DEBUG_AUDIO = false  # General audio events
const DEBUG_PITCH_SCALING = false  # Pitch scaling updates

# === AUDIO MANAGER ===
# Autoload singleton that manages all game audio with time scaling integration
# Handles SFX, Music, and UI audio categories with independent pitch scaling

## === EXPORTED CONFIGURATION ===
@export_group("Audio Categories")
## Enable SFX category
@export var sfx_enabled: bool = true
## Enable Music category
@export var music_enabled: bool = true
## Enable UI category
@export var ui_enabled: bool = true

@export_group("Pitch Scaling - SFX")
## SFX follows time scale exactly - can get very slow but never zero
@export var sfx_min_pitch: float = 0.01
@export var sfx_max_pitch: float = 2.0

@export_group("Pitch Scaling - Music")
## Music maintains minimum pitch when time stops
@export var music_min_pitch: float = 0.1
@export var music_max_pitch: float = 1.2

@export_group("Pitch Scaling - UI")
## UI has subtle time scaling effect
@export var ui_min_pitch: float = 0.8
@export var ui_max_pitch: float = 1.2

@export_group("Volume Settings")
## Base volume for each category (before user preferences)
@export var base_sfx_volume: float = 1.0
@export var base_music_volume: float = 0.7
@export var base_ui_volume: float = 0.8
## Maximum volume cap (prevents ear destruction) - 0.5 = -6dB, 0.3 = -10dB
@export var max_volume_cap: float = 0.3

@export_group("Audio Players")
## Number of SFX players to create for overlapping sounds
@export var sfx_player_count: int = 8
## Number of 3D SFX players for positional audio
@export var sfx_3d_player_count: int = 8
## Number of UI players for UI sounds
@export var ui_player_count: int = 4
## Single music player (use crossfade for multiple tracks)
@export var music_player_count: int = 1

@export_group("3D Audio Settings")
## Maximum distance for 3D audio (beyond this, sound is silent)
@export var max_3d_distance: float = 50.0
## Reference distance for 3D audio (distance at which volume starts to decrease)
@export var reference_3d_distance: float = 5.0


## === AUDIO CATEGORIES ===
enum AudioCategory {
	SFX,
	MUSIC,
	UI
}

## === RUNTIME STATE ===
# Time system integration
var time_manager: Node = null
var current_time_scale: float = 1.0

# Audio players by category
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_3d_players: Array[AudioStreamPlayer3D] = []
var music_players: Array[AudioStreamPlayer] = []
var ui_players: Array[AudioStreamPlayer] = []

# Track which players are playing undilated sounds (should not be time-scaled)
var undilated_players: Array[AudioStreamPlayer] = []

# Track which sound each player is currently playing (for pitch sensitivity)
var sfx_player_current_sound: Dictionary = {}  # player -> sound_name
var sfx_3d_player_current_sound: Dictionary = {}  # player -> sound_name

# Player pool management
var sfx_player_index: int = 0
var sfx_3d_player_index: int = 0
var ui_player_index: int = 0
var music_player_index: int = 0

# Audio library - loaded sound effects by name
var sfx_library: Dictionary = {}
var sfx_volumes: Dictionary = {}  # Per-SFX volume levels (0.0 to 1.0)
var sfx_pitch_sensitivity: Dictionary = {}  # Per-SFX pitch scaling sensitivity (0.0 = no scaling, 1.0 = full scaling)
var music_library: Dictionary = {}
var music_pitch_sensitivity: Dictionary = {}  # Per-music pitch scaling sensitivity
var ui_library: Dictionary = {}

# Volume settings (user preferences)
var user_master_volume: float = 1.0  # Master volume affects all categories
var user_sfx_volume: float = 1.0
var user_music_volume: float = 1.0
var user_ui_volume: float = 1.0

# Currently playing music track
var current_music_player: AudioStreamPlayer = null

## === SIGNALS ===
signal audio_category_volume_changed(category: AudioCategory, volume: float)
signal music_track_started(track_name: String)
signal music_track_stopped()

func _ready():
	# Initialize time manager connection
	_setup_time_manager()
	
	# Create audio players
	_create_audio_players()
	
	# Load audio library
	_load_audio_library()
	
	# Load user volume preferences
	_load_volume_preferences()
	
	if DEBUG_AUDIO:
		print("AudioManager: Initialized with ", sfx_players.size(), " SFX players")

func _setup_time_manager():
	"""Connect to TimeManager for time scale updates."""
	time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		if time_manager.has_signal("time_scale_changed"):
			time_manager.time_scale_changed.connect(_on_time_scale_changed)
		if DEBUG_AUDIO:
			print("AudioManager: Connected to TimeManager")
	else:
		if DEBUG_AUDIO:
			print("AudioManager: WARNING - TimeManager not found")

func _create_audio_players():
	"""Create audio player pools for each category."""
	# Create SFX players (2D)
	for i in range(sfx_player_count):
		var player = AudioStreamPlayer.new()
		player.name = "SFXPlayer_" + str(i)
		add_child(player)
		sfx_players.append(player)
	
	# Create 3D SFX players (positional)
	for i in range(sfx_3d_player_count):
		var player = AudioStreamPlayer3D.new()
		player.name = "SFX3DPlayer_" + str(i)
		player.max_distance = max_3d_distance
		player.unit_size = reference_3d_distance
		player.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
		add_child(player)
		sfx_3d_players.append(player)
	
	# Create Music players
	for i in range(music_player_count):
		var player = AudioStreamPlayer.new()
		player.name = "MusicPlayer_" + str(i)
		add_child(player)
		music_players.append(player)
	
	# Create UI players
	for i in range(ui_player_count):
		var player = AudioStreamPlayer.new()
		player.name = "UIPlayer_" + str(i)
		add_child(player)
		ui_players.append(player)
	
	if DEBUG_AUDIO:
		print("AudioManager: Created audio players - SFX: ", sfx_players.size(), 
			  " SFX3D: ", sfx_3d_players.size(), " Music: ", music_players.size(), " UI: ", ui_players.size())

func _load_audio_library():
	"""Load all audio files into memory with individual volume levels."""

	# Music Assets
	_register_music("track_1", preload("res://assets/sounds/music/MUSIC-dulledclub2.wav"), 0.95, 0.5)

	# Player SFX
	_register_sfx("player_death", preload("res://assets/sounds/sfx/player/people_man_scream.wav"), 0.75, 1.0)

	# Time SFX
	_register_sfx("clock_tick", preload("res://assets/sounds/sfx/time/tick_reverb.wav"), 0.1, 1.0)

	# UI SFX (no pitch scaling for UI sounds)
	_register_sfx("ui_tick", preload("res://assets/sounds/sfx/ui/tick.wav"), 0.25, 0.0)
	_register_sfx("ui_accept", preload("res://assets/sounds/sfx/ui/tick_complex.wav"), 0.25, 0.0)
	_register_sfx("ambience_oneshot_1", preload("res://assets/sounds/sfx/ui/ambienceoneshot.wav"), 1.0, 1.0)

	# Weapon SFX (full pitch scaling for combat feedback)
	_register_sfx("gunshot_pistol", preload("res://assets/sounds/sfx/weapons/gunshot_mechanical.wav"), 0.8, 1.0)
	_register_sfx("bounce_pistol", preload("res://assets/sounds/sfx/weapons/impact_percussive.wav"), 1.0, 1.0)
	_register_sfx("bullet_pickup", preload("res://assets/sounds/sfx/weapons/impactenergy.wav"), 1.0, 1.0)
	_register_sfx("bullet_redirect", preload("res://assets/sounds/sfx/weapons/impact_boom.wav"), 1.0, 1.0)
	_register_sfx("pistol_empty_chamber", preload("res://assets/sounds/sfx/weapons/impactenergy2.wav"), 1.0, 1.0)
	_register_sfx("pistol_pickup", preload("res://assets/sounds/sfx/weapons/mechanical_sound_4.wav"), 0.5, 1.0)
	_register_sfx("bullet_explosion", preload("res://assets/sounds/sfx/weapons/gunshot_energy.wav"), 0.025, 1.0)
	_register_sfx("bullet_hum", preload("res://assets/sounds/sfx/weapons/humlow.wav"), 1.0, 0.6)
	
	if DEBUG_AUDIO:
		print("AudioManager: Audio library loaded - SFX: ", sfx_library.size(), " sounds")

func _register_sfx(name: String, audio_stream: AudioStream, volume_level: float = 1.0, pitch_sensitivity: float = 1.0):
	"""Register a sound effect with individual volume level and pitch sensitivity."""
	sfx_library[name] = audio_stream
	sfx_volumes[name] = clamp(volume_level, 0.0, 1.0)
	sfx_pitch_sensitivity[name] = clamp(pitch_sensitivity, 0.0, 1.0)
	
	if DEBUG_AUDIO:
		print("AudioManager: Registered SFX: ", name, " (volume: ", "%.1f" % volume_level, ", pitch_sens: ", "%.1f" % pitch_sensitivity, ")")

func _register_music(name: String, audio_stream: AudioStream, volume_level: float = 1.0, pitch_sensitivity: float = 1.0):
	"""Register a music track with volume level and pitch sensitivity."""
	music_library[name] = audio_stream
	music_pitch_sensitivity[name] = clamp(pitch_sensitivity, 0.0, 1.0)
	
	if DEBUG_AUDIO:
		print("AudioManager: Registered music: ", name, " (volume: ", "%.1f" % volume_level, ", pitch_sens: ", "%.1f" % pitch_sensitivity, ")")

func _load_volume_preferences():
	"""Load user volume preferences from save file."""
	print("AudioManager: _load_volume_preferences() called")
	
	# Load from settings save file
	var settings_file = "user://settings.save"
	print("AudioManager: Checking for settings file: ", settings_file)
	print("AudioManager: File exists: ", FileAccess.file_exists(settings_file))
	
	if FileAccess.file_exists(settings_file):
		var save_file = FileAccess.open(settings_file, FileAccess.READ)
		if save_file:
			var settings = save_file.get_var()
			save_file.close()
			
			print("AudioManager: Loaded settings from file: ", settings)
			
			if settings and typeof(settings) == TYPE_DICTIONARY:
				# Load master and individual category volumes
				user_master_volume = settings.get("master_volume", 0.8)
				user_sfx_volume = settings.get("sfx_volume", 1.0)
				user_music_volume = settings.get("music_volume", 1.0)
				user_ui_volume = settings.get("ui_volume", 1.0)
				print("AudioManager: Loaded volumes - master: ", user_master_volume, " sfx: ", user_sfx_volume, " music: ", user_music_volume, " ui: ", user_ui_volume)
	else:
		print("AudioManager: No settings file found, using defaults")
	
	# Apply volume settings to all players
	_update_all_volumes()
	
	print("AudioManager: Volume preferences loaded - SFX: ", user_sfx_volume, " Music: ", user_music_volume, " UI: ", user_ui_volume)


func _process(_delta):
	"""Update pitch scaling based on current time scale."""
	if time_manager:
		var new_time_scale = time_manager.get_time_scale()
		if new_time_scale != current_time_scale:
			var old_scale = current_time_scale
			current_time_scale = new_time_scale
			_update_time_scaled_audio(old_scale, new_time_scale)

func _on_time_scale_changed(new_scale: float):
	"""Handle time scale changes from TimeManager."""
	# Only update if scale actually changed to prevent spam
	if abs(current_time_scale - new_scale) > 0.01:
		var old_scale = current_time_scale
		current_time_scale = new_scale
		_update_time_scaled_audio(old_scale, new_scale)

func _update_time_scaled_audio(old_scale: float, new_scale: float):
	"""Update audio to match time scale with proper time distortion."""
	# Update pitch and playback speed for all playing audio
	_update_pitch_and_speed_scaling()

func _update_pitch_and_speed_scaling():
	"""Update pitch scaling for all audio categories based on current time scale."""
	# Calculate base pitch scales
	var sfx_pitch_base = clamp(current_time_scale, sfx_min_pitch, sfx_max_pitch)
	var music_pitch = clamp(lerp(music_min_pitch, music_max_pitch, current_time_scale), 
							music_min_pitch, music_max_pitch)
	var ui_pitch = clamp(lerp(ui_min_pitch, ui_max_pitch, current_time_scale), 
						 ui_min_pitch, ui_max_pitch)
	
	# Update SFX players with individual pitch sensitivity
	for player in sfx_players:
		if player.playing and not player in undilated_players:
			var sound_name = sfx_player_current_sound.get(player, "")
			if sound_name != "":
				var sensitivity = sfx_pitch_sensitivity.get(sound_name, 1.0)
				var final_pitch = max(0.01, lerp(1.0, sfx_pitch_base, sensitivity))
				player.pitch_scale = final_pitch
			else:
				# Unknown sound, use default
				player.pitch_scale = max(0.01, sfx_pitch_base)
			player.stream_paused = false
	
	# Update 3D SFX players with individual pitch sensitivity
	for player in sfx_3d_players:
		if player.playing:
			var sound_name = sfx_3d_player_current_sound.get(player, "")
			if sound_name != "":
				var sensitivity = sfx_pitch_sensitivity.get(sound_name, 1.0)
				var final_pitch = max(0.01, lerp(1.0, sfx_pitch_base, sensitivity))
				player.pitch_scale = final_pitch
			else:
				# Unknown sound, use default
				player.pitch_scale = max(0.01, sfx_pitch_base)
			player.stream_paused = false
	
	# Music pitch update - need to know which track is playing to apply sensitivity
	# For now, just update the current music player if we know what's playing
	if current_music_player and current_music_player.playing:
		# Try to find which track is playing (check stream against library)
		var playing_track_name = ""
		for track_name in music_library.keys():
			if current_music_player.stream == music_library[track_name]:
				playing_track_name = track_name
				break
		
		if playing_track_name != "":
			var pitch_sensitivity = music_pitch_sensitivity.get(playing_track_name, 1.0)
			var final_pitch = lerp(1.0, music_pitch, pitch_sensitivity)
			current_music_player.pitch_scale = max(0.1, final_pitch)
		else:
			# Fallback: use default pitch
			current_music_player.pitch_scale = max(0.1, music_pitch)
	
	for player in ui_players:
		if player.playing:
			player.pitch_scale = max(0.1, ui_pitch)

func _ensure_correct_pitch(player: AudioStreamPlayer, target_pitch: float):
	"""Ensure the audio player maintains the correct pitch (defensive fix for timing issues)."""
	if is_instance_valid(player) and player.playing:
		if abs(player.pitch_scale - target_pitch) > 0.01:
			player.pitch_scale = target_pitch
			if DEBUG_AUDIO:
				print("AudioManager: Corrected pitch drift to: ", target_pitch)

func _ensure_correct_pitch_3d(player: AudioStreamPlayer3D, target_pitch: float):
	"""Ensure the 3D audio player maintains the correct pitch."""
	if is_instance_valid(player) and player.playing:
		if abs(player.pitch_scale - target_pitch) > 0.01:
			player.pitch_scale = target_pitch
			if DEBUG_AUDIO:
				print("AudioManager: Corrected 3D pitch drift to: ", target_pitch)

func _cleanup_undilated_tracking(player: AudioStreamPlayer):
	"""Remove player from undilated tracking when sound finishes."""
	# Wait for the sound to actually finish, then clean up
	if is_instance_valid(player):
		await player.finished
	
	# Remove from undilated tracking
	if player in undilated_players:
		undilated_players.erase(player)
	
	# Remove from sound tracking
	if player in sfx_player_current_sound:
		sfx_player_current_sound.erase(player)

func _update_all_volumes():
	"""Update volume for all audio players based on user preferences."""
	# Update SFX players (master * sfx * cap)
	for player in sfx_players:
		var final_volume = base_sfx_volume * user_master_volume * user_sfx_volume * max_volume_cap
		player.volume_db = linear_to_db(final_volume)
	
	# Update Music players (master * music * cap)
	for player in music_players:
		var final_volume = base_music_volume * user_master_volume * user_music_volume * max_volume_cap
		player.volume_db = linear_to_db(final_volume)
	
	# Update UI players (master * ui * cap)
	for player in ui_players:
		var final_volume = base_ui_volume * user_master_volume * user_ui_volume * max_volume_cap
		player.volume_db = linear_to_db(final_volume)

## === PUBLIC API - SFX ===

func play_sfx(sound_name: String, volume_modifier: float = 1.0) -> bool:
	"""Play a sound effect with automatic time scaling."""
	if not sfx_enabled or not sfx_library.has(sound_name):
		if DEBUG_AUDIO:
			print("AudioManager: SFX not found or disabled: ", sound_name)
		return false
	
	var player = _get_next_sfx_player()
	if not player:
		if DEBUG_AUDIO:
			print("AudioManager: No available SFX players")
		return false
	
	# Configure player
	player.stream = sfx_library[sound_name]
	
	# Calculate volume with individual SFX volume level and cap (master * sfx * individual * cap)
	var sfx_volume_level = sfx_volumes.get(sound_name, 1.0)  # Default to 1.0 if not set
	var final_volume = base_sfx_volume * user_master_volume * user_sfx_volume * volume_modifier * sfx_volume_level * max_volume_cap
	player.volume_db = linear_to_db(final_volume)
	
	# Calculate correct pitch for current time scale with sensitivity
	var pitch_sensitivity = sfx_pitch_sensitivity.get(sound_name, 1.0)  # Default to full sensitivity
	var pitch_scale = clamp(current_time_scale, sfx_min_pitch, sfx_max_pitch)
	# Lerp between 1.0 (no change) and pitch_scale (full change) based on sensitivity
	var final_pitch = max(0.01, lerp(1.0, pitch_scale, pitch_sensitivity))
	
	# Track which sound this player is playing
	sfx_player_current_sound[player] = sound_name
	
	# Set pitch BEFORE playing to avoid the initial squeak
	player.pitch_scale = final_pitch
	
	# Start playing at the correct time-scaled pitch
	player.play()
	player.stream_paused = false
	
	# Ensure pitch stays correct (defensive programming)
	call_deferred("_ensure_correct_pitch", player, final_pitch)
	
	if DEBUG_AUDIO:
		print("AudioManager: Playing SFX: ", sound_name, " (paused: ", player.stream_paused, ")")
	
	return true

func play_sfx_undilated(sound_name: String, volume_modifier: float = 1.0) -> bool:
	"""Play a sound effect that ignores time scaling (always normal speed/pitch)."""
	if not sfx_enabled or not sfx_library.has(sound_name):
		if DEBUG_AUDIO:
			print("AudioManager: Undilated SFX not found or disabled: ", sound_name)
		return false
	
	var player = _get_next_sfx_player()
	if not player:
		if DEBUG_AUDIO:
			print("AudioManager: No available SFX players for undilated sound")
		return false
	
	# Configure player
	player.stream = sfx_library[sound_name]
	
	# Calculate volume with individual SFX volume level (master * sfx * individual)
	var sfx_volume_level = sfx_volumes.get(sound_name, 1.0)
	var final_volume = base_sfx_volume * user_master_volume * user_sfx_volume * volume_modifier * sfx_volume_level
	player.volume_db = linear_to_db(final_volume)
	
	# ALWAYS use normal pitch and speed - ignore time scale
	player.pitch_scale = 1.0
	
	# Start playing at normal speed
	player.play()
	player.stream_paused = false
	
	# Track this player as undilated so time scaling won't affect it
	if not player in undilated_players:
		undilated_players.append(player)
	
	# Clean up tracking when sound finishes
	call_deferred("_cleanup_undilated_tracking", player)
	
	if DEBUG_AUDIO:
		print("AudioManager: Playing undilated SFX: ", sound_name, " (pitch: 1.0, ignoring time scale)")
	
	return true

func play_sfx_3d(sound_name: String, position: Vector3, volume_modifier: float = 1.0) -> AudioStreamPlayer3D:
	"""Play a 3D positioned sound effect with automatic time scaling. Returns player reference."""
	if not sfx_enabled or not sfx_library.has(sound_name):
		if DEBUG_AUDIO:
			print("AudioManager: 3D SFX not found or disabled: ", sound_name)
		return null
	
	var player = _get_next_sfx_3d_player()
	if not player:
		if DEBUG_AUDIO:
			print("AudioManager: No available 3D SFX players")
		return null
	
	# Configure player
	player.stream = sfx_library[sound_name]
	
	# Calculate volume with individual SFX volume level and cap (master * sfx * individual * cap)
	var sfx_volume_level = sfx_volumes.get(sound_name, 1.0)  # Default to 1.0 if not set
	var final_volume = base_sfx_volume * user_master_volume * user_sfx_volume * volume_modifier * sfx_volume_level * max_volume_cap
	player.volume_db = linear_to_db(final_volume)
	player.global_position = position
	
	# Set pitch scale for time distortion with sensitivity
	var pitch_sensitivity = sfx_pitch_sensitivity.get(sound_name, 1.0)
	var pitch_scale = clamp(current_time_scale, sfx_min_pitch, sfx_max_pitch)
	var final_pitch = max(0.01, lerp(1.0, pitch_scale, pitch_sensitivity))
	player.pitch_scale = final_pitch
	
	# Track which sound this player is playing
	sfx_3d_player_current_sound[player] = sound_name
	
	# Start playing at the correct time-scaled pitch
	player.play()
	player.stream_paused = false
	
	# Ensure pitch stays correct
	call_deferred("_ensure_correct_pitch_3d", player, final_pitch)
	
	if DEBUG_AUDIO:
		print("AudioManager: Playing 3D SFX: ", sound_name, " at ", position)
	
	return player

func stop_all_sfx():
	"""Stop all currently playing SFX."""
	for player in sfx_players:
		if player.playing:
			player.stop()
	
	for player in sfx_3d_players:
		if player.playing:
			player.stop()

## === PUBLIC API - MUSIC ===

func play_music(track_name: String, fade_in_duration: float = 0.0) -> bool:
	"""Play a music track with automatic pitch scaling."""
	if not music_enabled or not music_library.has(track_name):
		if DEBUG_AUDIO:
			print("AudioManager: Music track not found or disabled: ", track_name)
		return false
	
	# Stop current music
	if current_music_player and current_music_player.playing:
		current_music_player.stop()
	
	# Get music player
	current_music_player = music_players[0]  # Use first music player
	
	# Configure player
	current_music_player.stream = music_library[track_name]
	var final_volume = base_music_volume * user_master_volume * user_music_volume * max_volume_cap
	current_music_player.volume_db = linear_to_db(final_volume)
	
	# Apply pitch scaling with sensitivity
	var pitch_sensitivity = music_pitch_sensitivity.get(track_name, 1.0)
	var pitch_scale = clamp(lerp(music_min_pitch, music_max_pitch, current_time_scale), 
											  music_min_pitch, music_max_pitch)
	# Lerp between 1.0 (no change) and pitch_scale based on sensitivity
	var final_pitch = lerp(1.0, pitch_scale, pitch_sensitivity)
	current_music_player.pitch_scale = final_pitch
	
	current_music_player.play()
	
	# TODO: Implement fade-in if duration > 0
	
	music_track_started.emit(track_name)
	
	if DEBUG_AUDIO:
		print("AudioManager: Playing music: ", track_name, " at pitch: ", current_music_player.pitch_scale)
	
	return true

func stop_music(fade_out_duration: float = 0.0):
	"""Stop the currently playing music."""
	if current_music_player and current_music_player.playing:
		# TODO: Implement fade-out if duration > 0
		current_music_player.stop()
		music_track_stopped.emit()
		
		if DEBUG_AUDIO:
			print("AudioManager: Stopped music")

func is_music_playing() -> bool:
	"""Check if music is currently playing."""
	return current_music_player and current_music_player.playing

## === PUBLIC API - UI ===

func play_ui(sound_name: String, volume_modifier: float = 1.0) -> bool:
	"""Play a UI sound with subtle pitch scaling."""
	if not ui_enabled or not ui_library.has(sound_name):
		if DEBUG_AUDIO:
			print("AudioManager: UI sound not found or disabled: ", sound_name)
		return false
	
	var player = _get_next_ui_player()
	if not player:
		if DEBUG_AUDIO:
			print("AudioManager: No available UI players")
		return false
	
	# Configure player
	player.stream = ui_library[sound_name]
	player.volume_db = linear_to_db(base_ui_volume * user_ui_volume * volume_modifier)
	player.pitch_scale = clamp(lerp(ui_min_pitch, ui_max_pitch, current_time_scale), 
							   ui_min_pitch, ui_max_pitch)
	player.play()
	
	if DEBUG_AUDIO:
		print("AudioManager: Playing UI: ", sound_name, " at pitch: ", player.pitch_scale)
	
	return true

## === PLAYER POOL MANAGEMENT ===

func _get_next_sfx_player() -> AudioStreamPlayer:
	"""Get the next available SFX player from the pool."""
	var start_index = sfx_player_index
	
	# Find next available player
	while sfx_players[sfx_player_index].playing:
		sfx_player_index = (sfx_player_index + 1) % sfx_players.size()
		
		# If we've checked all players, use the next one anyway (overlapping)
		if sfx_player_index == start_index:
			break
	
	var player = sfx_players[sfx_player_index]
	sfx_player_index = (sfx_player_index + 1) % sfx_players.size()
	return player

func _get_next_ui_player() -> AudioStreamPlayer:
	"""Get the next available UI player from the pool."""
	var start_index = ui_player_index
	
	# Find next available player
	while ui_players[ui_player_index].playing:
		ui_player_index = (ui_player_index + 1) % ui_players.size()
		
		# If we've checked all players, use the next one anyway
		if ui_player_index == start_index:
			break
	
	var player = ui_players[ui_player_index]
	ui_player_index = (ui_player_index + 1) % ui_players.size()
	return player

func _get_next_sfx_3d_player() -> AudioStreamPlayer3D:
	"""Get the next available 3D SFX player from the pool."""
	var start_index = sfx_3d_player_index
	
	# Find next available player
	while sfx_3d_players[sfx_3d_player_index].playing:
		sfx_3d_player_index = (sfx_3d_player_index + 1) % sfx_3d_players.size()
		
		# If we've checked all players, use the next one anyway
		if sfx_3d_player_index == start_index:
			break
	
	var player = sfx_3d_players[sfx_3d_player_index]
	sfx_3d_player_index = (sfx_3d_player_index + 1) % sfx_3d_players.size()
	return player

## === VOLUME CONTROL ===

func set_master_volume(volume: float):
	"""Set master volume (0.0 to 1.0) - affects all audio categories."""
	print("AudioManager: set_master_volume CALLED with: ", volume)
	user_master_volume = clamp(volume, 0.0, 1.0)
	# Update all categories when master changes
	_update_all_volumes()
	print("AudioManager: Master volume set to: ", user_master_volume)

func set_sfx_volume(volume: float):
	"""Set SFX volume (0.0 to 1.0)."""
	print("AudioManager: set_sfx_volume CALLED with: ", volume)
	user_sfx_volume = clamp(volume, 0.0, 1.0)
	print("AudioManager: user_sfx_volume set to: ", user_sfx_volume)
	_update_sfx_volumes()
	print("AudioManager: _update_sfx_volumes() completed")
	audio_category_volume_changed.emit(AudioCategory.SFX, user_sfx_volume)

func set_music_volume(volume: float):
	"""Set music volume (0.0 to 1.0)."""
	user_music_volume = clamp(volume, 0.0, 1.0)
	_update_music_volumes()
	audio_category_volume_changed.emit(AudioCategory.MUSIC, user_music_volume)

func set_ui_volume(volume: float):
	"""Set UI volume (0.0 to 1.0)."""
	user_ui_volume = clamp(volume, 0.0, 1.0)
	_update_ui_volumes()
	audio_category_volume_changed.emit(AudioCategory.UI, user_ui_volume)

func _update_sfx_volumes():
	"""Update volume for all SFX players."""
	var final_volume = base_sfx_volume * user_master_volume * user_sfx_volume * max_volume_cap
	var final_db = linear_to_db(final_volume)
	
	print("AudioManager: _update_sfx_volumes() - base=", base_sfx_volume, " master=", user_master_volume, " sfx=", user_sfx_volume, " cap=", max_volume_cap)
	print("AudioManager: final_volume=", final_volume, " final_db=", final_db, " dB")
	
	for player in sfx_players:
		player.volume_db = final_db
	
	# Also update 3D players
	for player in sfx_3d_players:
		player.volume_db = final_db
	
	print("AudioManager: Updated ", sfx_players.size(), " 2D and ", sfx_3d_players.size(), " 3D SFX players")

func _update_music_volumes():
	"""Update volume for all music players."""
	for player in music_players:
		var final_volume = base_music_volume * user_master_volume * user_music_volume * max_volume_cap
		player.volume_db = linear_to_db(final_volume)

func _update_ui_volumes():
	"""Update volume for all UI players."""
	for player in ui_players:
		var final_volume = base_ui_volume * user_master_volume * user_ui_volume * max_volume_cap
		player.volume_db = linear_to_db(final_volume)

## === OPTIONS MENU INTEGRATION ===



func register_ui(name: String, audio_stream: AudioStream):
	"""Register a UI sound in the library."""
	ui_library[name] = audio_stream
	if DEBUG_AUDIO:
		print("AudioManager: Registered UI sound: ", name)

## === SFX VOLUME CONTROL ===

func set_sfx_individual_volume(sound_name: String, volume_level: float):
	"""Set the individual volume level for a specific SFX (0.0 to 1.0)."""
	sfx_volumes[sound_name] = clamp(volume_level, 0.0, 1.0)
	if DEBUG_AUDIO:
		print("AudioManager: Set ", sound_name, " volume to: ", "%.2f" % volume_level)

func get_sfx_individual_volume(sound_name: String) -> float:
	"""Get the individual volume level for a specific SFX."""
	return sfx_volumes.get(sound_name, 1.0)

func get_all_sfx_volumes() -> Dictionary:
	"""Get all individual SFX volume levels for debugging/configuration."""
	return sfx_volumes.duplicate()

## === CONVENIENCE METHODS FOR YOUR SFX LIST ===

# Weapon sounds
func play_gunshot(weapon_type: String = "pistol"):
	play_sfx("gunshot_" + weapon_type)

func play_reload(weapon_type: String = "pistol"):
	play_sfx("reload_" + weapon_type)

func play_empty_chamber(weapon_type: String = "pistol"):
	play_sfx("empty_chamber_" + weapon_type)

func play_gun_pickup(weapon_type: String = "pistol"):
	play_sfx_undilated(weapon_type + "_pickup")

# Bullet sounds
func play_bullet_bounce(position: Vector3 = Vector3.ZERO):
	"""Play bullet bounce sound - 3D positioned if position provided."""
	if position == Vector3.ZERO:
		play_sfx("bounce_pistol")  # 2D fallback
	else:
		play_sfx_3d("bounce_pistol", position)  # 3D positioned

func play_bullet_pierce():
	play_sfx("bullet_pierce")

func play_bullet_detonate():
	play_sfx("bullet_explosion")

func play_bullet_redirect():
	play_sfx("bullet_redirect")

func play_bullet_pickup():
	play_sfx("bullet_pickup")

# Player movement
func play_jump():
	play_sfx("player_jump")

func play_land():
	play_sfx("player_land")

func play_dash():
	play_sfx("player_dash")

# Time system
func play_time_slow():
	play_sfx("time_slow_engaged")

func play_time_stop():
	play_sfx("time_fully_stopped")

func play_time_resume():
	play_sfx("time_resuming")

# UI sounds
func play_ui_accept():
	play_ui("ui_accept")

func play_ui_back():
	play_ui("ui_back")

func play_ui_hover():
	play_ui("ui_hover")

## === DEBUG AND UTILITY ===

func get_audio_stats() -> Dictionary:
	"""Get current audio system statistics."""
	return {
		"sfx_playing": _count_playing_sounds(sfx_players),
		"music_playing": _count_playing_sounds(music_players),
		"ui_playing": _count_playing_sounds(ui_players),
		"current_time_scale": current_time_scale,
		"sfx_library_size": sfx_library.size(),
		"music_library_size": music_library.size(),
		"ui_library_size": ui_library.size()
	}

func _count_playing_sounds(players: Array) -> int:
	"""Count how many players in an array are currently playing."""
	var count = 0
	for player in players:
		if player.playing:
			count += 1
	return count

func test_audio():
	"""Test method to verify audio is working."""
	print("audio: === AUDIO TEST ===")
	print("audio: Master bus volume: ", AudioServer.get_bus_volume_db(0), " dB")
	print("audio: Master bus muted: ", AudioServer.is_bus_mute(0))
	print("audio: Available SFX: ", sfx_library.keys())
	
	if sfx_library.has("gunshot_pistol"):
		print("audio: Testing gunshot_pistol...")
		var success = play_sfx("gunshot_pistol")
		print("audio: Test result: ", success)
	else:
		print("audio: gunshot_pistol not found in library!")
	
	print("audio: === END TEST ===")

func print_debug_info():
	"""Print current audio system state for debugging."""
	var stats = get_audio_stats()
	print("\n=== AUDIO MANAGER DEBUG ===")
	print("Time Scale: ", current_time_scale)
	print("SFX Playing: ", stats.sfx_playing, "/", sfx_players.size())
	print("Music Playing: ", stats.music_playing, "/", music_players.size())
	print("UI Playing: ", stats.ui_playing, "/", ui_players.size())
	print("Volumes - SFX: ", user_sfx_volume, " Music: ", user_music_volume, " UI: ", user_ui_volume)
	print("Library sizes - SFX: ", stats.sfx_library_size, " Music: ", stats.music_library_size, " UI: ", stats.ui_library_size)
	print("===========================\n")
