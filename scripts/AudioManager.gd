extends Node

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
## SFX follows time scale exactly
@export var sfx_min_pitch: float = 0.0
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

@export_group("Audio Players")
## Number of SFX players to create for overlapping sounds
@export var sfx_player_count: int = 8
## Number of UI players for UI sounds
@export var ui_player_count: int = 4
## Single music player (use crossfade for multiple tracks)
@export var music_player_count: int = 1

@export_group("Debug Settings")
## Enable debug output for audio events
@export var debug_audio: bool = false
## Enable debug output for pitch scaling
@export var debug_pitch_scaling: bool = false

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
var music_players: Array[AudioStreamPlayer] = []
var ui_players: Array[AudioStreamPlayer] = []

# Player pool management
var sfx_player_index: int = 0
var ui_player_index: int = 0
var music_player_index: int = 0

# Audio library - loaded sound effects by name
var sfx_library: Dictionary = {}
var music_library: Dictionary = {}
var ui_library: Dictionary = {}

# Volume settings (user preferences)
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
	
	# Connect to options menu if available
	_connect_to_options_menu()
	
	if debug_audio:
		print("AudioManager: Initialized with ", sfx_players.size(), " SFX players, ", 
			  music_players.size(), " music players, ", ui_players.size(), " UI players")

func _setup_time_manager():
	"""Connect to TimeManager for time scale updates."""
	time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		if time_manager.has_signal("time_scale_changed"):
			time_manager.time_scale_changed.connect(_on_time_scale_changed)
		if debug_audio:
			print("AudioManager: Connected to TimeManager")
	else:
		if debug_audio:
			print("AudioManager: WARNING - TimeManager not found")

func _create_audio_players():
	"""Create audio player pools for each category."""
	# Create SFX players
	for i in range(sfx_player_count):
		var player = AudioStreamPlayer.new()
		player.name = "SFXPlayer_" + str(i)
		add_child(player)
		sfx_players.append(player)
	
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
	
	if debug_audio:
		print("AudioManager: Created audio players - SFX: ", sfx_players.size(), 
			  " Music: ", music_players.size(), " UI: ", ui_players.size())

func _load_audio_library():
	"""Load all audio files into memory (extend this based on your file structure)."""
	# TODO: Load your actual audio files here
	# Example structure:
	# sfx_library["gunshot_pistol"] = preload("res://assets/sounds/sfx/gunshot_pistol.ogg")
	# sfx_library["gunshot_rifle"] = preload("res://assets/sounds/sfx/gunshot_rifle.ogg")
	# music_library["level_theme"] = preload("res://assets/sounds/music/level_theme.ogg")
	# ui_library["button_click"] = preload("res://assets/sounds/ui/button_click.ogg")
	
	if debug_audio:
		print("AudioManager: Audio library loaded - SFX: ", sfx_library.size(), 
			  " Music: ", music_library.size(), " UI: ", ui_library.size())

func _load_volume_preferences():
	"""Load user volume preferences from OptionsMenu or save file."""
	# Try to get from OptionsMenu first
	var options_menu = get_node_or_null("/root/OptionsMenu")
	if options_menu:
		if "sfx_volume" in options_menu:
			user_sfx_volume = options_menu.sfx_volume
		if "music_volume" in options_menu:
			user_music_volume = options_menu.music_volume
		if "ui_volume" in options_menu:
			user_ui_volume = options_menu.ui_volume
	
	# Apply volume settings to all players
	_update_all_volumes()
	
	if debug_audio:
		print("AudioManager: Volume preferences loaded - SFX: ", user_sfx_volume, 
			  " Music: ", user_music_volume, " UI: ", user_ui_volume)

func _connect_to_options_menu():
	"""Connect to OptionsMenu volume change signals."""
	var options_menu = get_node_or_null("/root/OptionsMenu")
	if options_menu:
		# Connect to volume change signals if they exist
		if options_menu.has_signal("sfx_volume_changed"):
			options_menu.sfx_volume_changed.connect(_on_sfx_volume_changed)
		if options_menu.has_signal("music_volume_changed"):
			options_menu.music_volume_changed.connect(_on_music_volume_changed)
		if options_menu.has_signal("ui_volume_changed"):
			options_menu.ui_volume_changed.connect(_on_ui_volume_changed)
		
		if debug_audio:
			print("AudioManager: Connected to OptionsMenu volume signals")

func _process(_delta):
	"""Update pitch scaling based on current time scale."""
	if time_manager:
		var new_time_scale = time_manager.get_time_scale()
		if new_time_scale != current_time_scale:
			current_time_scale = new_time_scale
			_update_pitch_scaling()

func _on_time_scale_changed(new_scale: float):
	"""Handle time scale changes from TimeManager."""
	current_time_scale = new_scale
	_update_pitch_scaling()
	
	if debug_pitch_scaling:
		print("AudioManager: Time scale changed to ", new_scale)

func _update_pitch_scaling():
	"""Update pitch scaling for all audio categories based on current time scale."""
	# SFX: Follows time scale exactly
	var sfx_pitch = clamp(current_time_scale, sfx_min_pitch, sfx_max_pitch)
	
	# Music: Maintains minimum pitch when time stops
	var music_pitch = clamp(lerp(music_min_pitch, music_max_pitch, current_time_scale), 
							music_min_pitch, music_max_pitch)
	
	# UI: Subtle scaling effect
	var ui_pitch = clamp(lerp(ui_min_pitch, ui_max_pitch, current_time_scale), 
						 ui_min_pitch, ui_max_pitch)
	
	# Apply pitch scaling to all players
	for player in sfx_players:
		if player.playing:
			player.pitch_scale = sfx_pitch
	
	for player in music_players:
		if player.playing:
			player.pitch_scale = music_pitch
	
	for player in ui_players:
		if player.playing:
			player.pitch_scale = ui_pitch
	
	if debug_pitch_scaling:
		print("AudioManager: Pitch scaling - SFX: ", sfx_pitch, " Music: ", music_pitch, " UI: ", ui_pitch)

func _update_all_volumes():
	"""Update volume for all audio players based on user preferences."""
	# Update SFX players
	for player in sfx_players:
		player.volume_db = linear_to_db(base_sfx_volume * user_sfx_volume)
	
	# Update Music players
	for player in music_players:
		player.volume_db = linear_to_db(base_music_volume * user_music_volume)
	
	# Update UI players
	for player in ui_players:
		player.volume_db = linear_to_db(base_ui_volume * user_ui_volume)

## === PUBLIC API - SFX ===

func play_sfx(sound_name: String, volume_modifier: float = 1.0) -> bool:
	"""Play a sound effect with automatic pitch scaling."""
	if not sfx_enabled or not sfx_library.has(sound_name):
		if debug_audio:
			print("AudioManager: SFX not found or disabled: ", sound_name)
		return false
	
	var player = _get_next_sfx_player()
	if not player:
		if debug_audio:
			print("AudioManager: No available SFX players")
		return false
	
	# Configure player
	player.stream = sfx_library[sound_name]
	player.volume_db = linear_to_db(base_sfx_volume * user_sfx_volume * volume_modifier)
	player.pitch_scale = clamp(current_time_scale, sfx_min_pitch, sfx_max_pitch)
	player.play()
	
	if debug_audio:
		print("AudioManager: Playing SFX: ", sound_name, " at pitch: ", player.pitch_scale)
	
	return true

func stop_all_sfx():
	"""Stop all currently playing SFX."""
	for player in sfx_players:
		if player.playing:
			player.stop()

## === PUBLIC API - MUSIC ===

func play_music(track_name: String, fade_in_duration: float = 0.0) -> bool:
	"""Play a music track with automatic pitch scaling."""
	if not music_enabled or not music_library.has(track_name):
		if debug_audio:
			print("AudioManager: Music track not found or disabled: ", track_name)
		return false
	
	# Stop current music
	if current_music_player and current_music_player.playing:
		current_music_player.stop()
	
	# Get music player
	current_music_player = music_players[0]  # Use first music player
	
	# Configure player
	current_music_player.stream = music_library[track_name]
	current_music_player.volume_db = linear_to_db(base_music_volume * user_music_volume)
	current_music_player.pitch_scale = clamp(lerp(music_min_pitch, music_max_pitch, current_time_scale), 
											  music_min_pitch, music_max_pitch)
	current_music_player.play()
	
	# TODO: Implement fade-in if duration > 0
	
	music_track_started.emit(track_name)
	
	if debug_audio:
		print("AudioManager: Playing music: ", track_name, " at pitch: ", current_music_player.pitch_scale)
	
	return true

func stop_music(fade_out_duration: float = 0.0):
	"""Stop the currently playing music."""
	if current_music_player and current_music_player.playing:
		# TODO: Implement fade-out if duration > 0
		current_music_player.stop()
		music_track_stopped.emit()
		
		if debug_audio:
			print("AudioManager: Stopped music")

func is_music_playing() -> bool:
	"""Check if music is currently playing."""
	return current_music_player and current_music_player.playing

## === PUBLIC API - UI ===

func play_ui(sound_name: String, volume_modifier: float = 1.0) -> bool:
	"""Play a UI sound with subtle pitch scaling."""
	if not ui_enabled or not ui_library.has(sound_name):
		if debug_audio:
			print("AudioManager: UI sound not found or disabled: ", sound_name)
		return false
	
	var player = _get_next_ui_player()
	if not player:
		if debug_audio:
			print("AudioManager: No available UI players")
		return false
	
	# Configure player
	player.stream = ui_library[sound_name]
	player.volume_db = linear_to_db(base_ui_volume * user_ui_volume * volume_modifier)
	player.pitch_scale = clamp(lerp(ui_min_pitch, ui_max_pitch, current_time_scale), 
							   ui_min_pitch, ui_max_pitch)
	player.play()
	
	if debug_audio:
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

## === VOLUME CONTROL ===

func set_sfx_volume(volume: float):
	"""Set SFX volume (0.0 to 1.0)."""
	user_sfx_volume = clamp(volume, 0.0, 1.0)
	_update_sfx_volumes()
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
	for player in sfx_players:
		player.volume_db = linear_to_db(base_sfx_volume * user_sfx_volume)

func _update_music_volumes():
	"""Update volume for all music players."""
	for player in music_players:
		player.volume_db = linear_to_db(base_music_volume * user_music_volume)

func _update_ui_volumes():
	"""Update volume for all UI players."""
	for player in ui_players:
		player.volume_db = linear_to_db(base_ui_volume * user_ui_volume)

## === OPTIONS MENU INTEGRATION ===

func _on_sfx_volume_changed(volume: float):
	"""Handle SFX volume change from OptionsMenu."""
	set_sfx_volume(volume)

func _on_music_volume_changed(volume: float):
	"""Handle music volume change from OptionsMenu."""
	set_music_volume(volume)

func _on_ui_volume_changed(volume: float):
	"""Handle UI volume change from OptionsMenu."""
	set_ui_volume(volume)

## === AUDIO LIBRARY MANAGEMENT ===

func register_sfx(name: String, audio_stream: AudioStream):
	"""Register a sound effect in the library."""
	sfx_library[name] = audio_stream
	if debug_audio:
		print("AudioManager: Registered SFX: ", name)

func register_music(name: String, audio_stream: AudioStream):
	"""Register a music track in the library."""
	music_library[name] = audio_stream
	if debug_audio:
		print("AudioManager: Registered music: ", name)

func register_ui(name: String, audio_stream: AudioStream):
	"""Register a UI sound in the library."""
	ui_library[name] = audio_stream
	if debug_audio:
		print("AudioManager: Registered UI sound: ", name)

## === CONVENIENCE METHODS FOR YOUR SFX LIST ===

# Weapon sounds
func play_gunshot(weapon_type: String = "pistol"):
	play_sfx("gunshot_" + weapon_type)

func play_reload(weapon_type: String = "pistol"):
	play_sfx("reload_" + weapon_type)

func play_empty_chamber(weapon_type: String = "pistol"):
	play_sfx("empty_chamber_" + weapon_type)

func play_gun_pickup(weapon_type: String = "pistol"):
	play_sfx("gun_pickup_" + weapon_type)

# Bullet sounds
func play_bullet_bounce():
	play_sfx("bullet_bounce")

func play_bullet_pierce():
	play_sfx("bullet_pierce")

func play_bullet_detonate():
	play_sfx("bullet_detonate")

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
