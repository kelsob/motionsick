extends Node3D

# === GUN DATA SYSTEM ===
# References to gun data resources for each gun type
@export var gun_data_resources: Array[Resource] = []
var current_gun_data: Resource = null

# === GUN STATES ===
enum State {
	IDLE,
	FIRING,
	CHARGING,
	CHARGED,
	DASH_MODE
}

# === FIRE MODES FOR TESTING ===
enum FireMode {
	RAPID_FIRE,      # Key 1
	CHARGE_BLAST,    # Key 2
	DASH_ATTACK,     # Key 3
	JUMP_BURST,      # Key 4
	SLOW_FIRE,       # Key 5
	FAST_FIRE,       # Key 6
	HEAVY_BLAST,     # Key 7
	TRIPLE_SHOT,     # Key 8
	AUTO_CHARGE      # Key 9
}

# === CONFIGURATION ===
@export_group("Gun Type")
## Current gun type (affects SFX and properties)
@export_enum("Pistol", "Rifle", "Shotgun", "Sniper", "RocketLauncher") var current_gun_type: int = 0

@export_group("Testing")
@export var testing_mode: bool = true  # Enable key-based fire mode testing
@export var movement_based: bool = false  # Enable movement-based firing (original system)

@export_group("Gun Positioning")
@export var screen_position := Vector3(0.15, -0.1, -0.4)  # Ideal gun position
@export var auto_position := false  # Enable to automatically position gun

@export_group("Aiming System")
@export var focal_distance: float = 50.0  # Fixed distance for bullet convergence point

@export_group("Firing System")
@export var rapid_fire_rate_start: float = 0.5   # Pistol: slower single shots
@export var rapid_fire_rate_min: float = 0.5     # Pistol: no acceleration
@export var rapid_fire_acceleration: float = 0.0 # Pistol: consistent timing

@export_group("Charging System")
@export var charge_time: float = 0.0  # Assault rifle: no charging needed
@export var min_charge_for_blast: float = 0.0

@export_group("Damage Values")
@export var rapid_fire_damage: int = 45          # Pistol: higher damage per shot
@export var charged_blast_damage_min: int = 30   # Assault rifle: consistent medium damage
@export var charged_blast_damage_max: int = 30   # Assault rifle: no charge variation
@export var dash_attack_damage: int = 120        # Shotgun: high damage total
@export var jump_burst_damage: int = 35          # Triple shot: decent damage per shot
@export var jump_burst_count: int = 3            # Triple shot: 3 shots
@export var jump_burst_interval: float = 0.12    # Triple shot: slightly slower burst
@export var slow_fire_damage: int = 150          # Rocket launcher: high direct damage

@export_group("Spread System (degrees)")
@export var rapid_fire_spread: float = 1.0       # Pistol: accurate
@export var charge_blast_spread: float = 2.5     # Assault rifle: some spread when firing fast
@export var dash_attack_spread: float = 0.5      # Shotgun: tight center pattern (pellets handle spread)
@export var jump_burst_spread: float = 3.0       # Triple shot: medium spread
@export var slow_fire_spread: float = 0.0        # Rocket launcher: perfectly accurate
@export var fast_fire_spread: float = 5.0        # Unused
@export var heavy_blast_spread: float = 0.0      # Unused
@export var triple_shot_spread: float = 8.0      # Unused
@export var auto_charge_spread: float = 0.5      # Unused

@export_group("Recoil System (degrees)")
@export var rapid_fire_recoil: float = 0.8       # Pistol: moderate recoil
@export var charge_blast_recoil: float = 0.4     # Assault rifle: manageable recoil for continuous fire
@export var dash_attack_recoil: float = 2.5      # Shotgun: heavy recoil
@export var jump_burst_recoil: float = 0.6       # Triple shot: medium recoil per shot
@export var slow_fire_recoil: float = 3.0        # Rocket launcher: very heavy recoil
@export var fast_fire_recoil: float = 0.1        # Unused
@export var heavy_blast_recoil: float = 1.67     # Unused
@export var triple_shot_recoil: float = 0.27     # Unused
@export var auto_charge_recoil: float = 0.67     # Unused

@export_group("Recoil Duration (seconds)")
@export var rapid_fire_recoil_duration: float = 0.4  # Pistol: moderate recovery
@export var charge_blast_recoil_duration: float = 0.3 # Assault rifle: quick recovery for continuous fire
@export var dash_attack_recoil_duration: float = 1.2  # Shotgun: long recovery
@export var jump_burst_recoil_duration: float = 0.5   # Triple shot: medium recovery
@export var slow_fire_recoil_duration: float = 2.0    # Rocket launcher: very long recovery
@export var fast_fire_recoil_duration: float = 0.2    # Unused
@export var heavy_blast_recoil_duration: float = 1.5  # Unused
@export var triple_shot_recoil_duration: float = 0.5  # Unused
@export var auto_charge_recoil_duration: float = 1.0  # Unused

@export_group("Explosive Properties")
@export var rapid_fire_explosive: bool = false    # Pistol: no explosions
@export var charge_blast_explosive: bool = false  # Assault rifle: no explosions
@export var dash_attack_explosive: bool = false   # Shotgun: no explosions
@export var jump_burst_explosive: bool = false    # Triple shot: no explosions
@export var slow_fire_explosive: bool = true      # Rocket launcher: explosive!
@export var fast_fire_explosive: bool = false     # Unused
@export var heavy_blast_explosive: bool = true    # Unused
@export var triple_shot_explosive: bool = false   # Unused
@export var auto_charge_explosive: bool = true    # Unused

@export_group("Explosion Radius (units)")
@export var rapid_fire_explosion_radius: float = 0.0   # Pistol: no explosions
@export var charge_blast_explosion_radius: float = 0.0 # Assault rifle: no explosions
@export var dash_attack_explosion_radius: float = 0.0  # Shotgun: no explosions
@export var jump_burst_explosion_radius: float = 0.0   # Triple shot: no explosions
@export var slow_fire_explosion_radius: float = 10.0   # Rocket launcher: large explosion
@export var fast_fire_explosion_radius: float = 0.0    # Unused
@export var heavy_blast_explosion_radius: float = 12.0 # Unused
@export var triple_shot_explosion_radius: float = 0.0  # Unused
@export var auto_charge_explosion_radius: float = 10.0 # Unused

@export_group("Explosion Damage")
@export var rapid_fire_explosion_damage: int = 0       # Pistol: no explosions
@export var charge_blast_explosion_damage: int = 0     # Assault rifle: no explosions
@export var dash_attack_explosion_damage: int = 0      # Shotgun: no explosions
@export var jump_burst_explosion_damage: int = 0       # Triple shot: no explosions
@export var slow_fire_explosion_damage: int = 200      # Rocket launcher: high explosion damage
@export var fast_fire_explosion_damage: int = 0        # Unused
@export var heavy_blast_explosion_damage: int = 250    # Unused
@export var triple_shot_explosion_damage: int = 0      # Unused
@export var auto_charge_explosion_damage: int = 180    # Unused

@export_group("Shotgun Properties")
@export var rapid_fire_shotgun: bool = false       # Pistol: not shotgun
@export var charge_blast_shotgun: bool = false     # Assault rifle: not shotgun
@export var dash_attack_shotgun: bool = true       # Shotgun: IS shotgun!
@export var jump_burst_shotgun: bool = false       # Triple shot: not shotgun (burst fire instead)
@export var slow_fire_shotgun: bool = false        # Rocket launcher: not shotgun
@export var fast_fire_shotgun: bool = false        # Unused
@export var heavy_blast_shotgun: bool = false      # Unused
@export var triple_shot_shotgun: bool = true       # Unused
@export var auto_charge_shotgun: bool = false      # Unused

@export_group("Shotgun Pellet Count")
@export var rapid_fire_pellets: int = 1            # Pistol: single shot
@export var charge_blast_pellets: int = 1          # Assault rifle: single shot
@export var dash_attack_pellets: int = 8           # Shotgun: 8 pellets
@export var jump_burst_pellets: int = 1            # Triple shot: single shots in burst
@export var slow_fire_pellets: int = 1             # Rocket launcher: single rocket
@export var fast_fire_pellets: int = 1             # Unused
@export var heavy_blast_pellets: int = 1           # Unused
@export var triple_shot_pellets: int = 8           # Unused
@export var auto_charge_pellets: int = 1           # Unused

@export_group("Shotgun Spread (degrees)")
@export var rapid_fire_shotgun_spread: float = 0.0     # Pistol: not shotgun
@export var charge_blast_shotgun_spread: float = 0.0   # Assault rifle: not shotgun
@export var dash_attack_shotgun_spread: float = 20.0   # Shotgun: wide pellet spread
@export var jump_burst_shotgun_spread: float = 0.0     # Triple shot: not shotgun
@export var slow_fire_shotgun_spread: float = 0.0      # Rocket launcher: not shotgun

@export_group("Piercing Properties")
@export var rapid_fire_piercing: float = 5.0           # Pistol: no piercing
@export var charge_blast_piercing: float = 0.0         # Assault rifle: no piercing
@export var dash_attack_piercing: float = 0.0          # Shotgun: no piercing
@export var jump_burst_piercing: float = 0.0           # Triple shot: no piercing
@export var slow_fire_piercing: float = 3.0            # Rocket launcher: high piercing for testing
@export var fast_fire_piercing: float = 0.0            # Unused
@export var heavy_blast_piercing: float = 0.0          # Unused
@export var triple_shot_piercing: float = 0.0          # Unused
@export var auto_charge_piercing: float = 0.0          # Unused

@export_group("Ammo System")
@export var max_ammo: int = 30                          # Maximum ammo capacity
@export var starting_ammo: int = 15                     # Starting ammo amount

@export_group("Firing Effects")
@export var velocity_loss_on_firing: float = 0.6        # Percentage of velocity lost when firing (0.0-1.0)

@export_group("Visual Effects")
@export var wall_ripple_scene: PackedScene = preload("res://scenes/effects/WallRipple.tscn")

@export_group("Knockback System")
@export var rapid_fire_knockback: float = 2.0          # Pistol: light knockback
@export var charge_blast_knockback: float = 1.5        # Assault rifle: very light knockback
@export var dash_attack_knockback: float = 8.0         # Shotgun: heavy knockback
@export var jump_burst_knockback: float = 3.0          # Triple shot: medium knockback
@export var slow_fire_knockback: float = 15.0          # Rocket launcher: massive knockback
@export var fast_fire_knockback: float = 1.0           # Unused
@export var heavy_blast_knockback: float = 12.0        # Unused
@export var triple_shot_knockback: float = 6.0         # Unused
@export var auto_charge_knockback: float = 10.0        # Unused
@export var fast_fire_shotgun_spread: float = 0.0      # Unused
@export var heavy_blast_shotgun_spread: float = 0.0    # Unused
@export var triple_shot_shotgun_spread: float = 15.0   # Unused
@export var auto_charge_shotgun_spread: float = 0.0    # Unused

@export_group("Recoil Settings")
@export var recoil_randomness: float = 0.25  # Random variation in recoil direction

@export_group("Animation Timing")
## Duration for muzzle flash animation
@export var muzzle_flash_duration: float = 0.2
## Scale factor for muzzle flash growth phase
@export var muzzle_flash_min_scale: float = 0.5
## Maximum scale for muzzle flash
@export var muzzle_flash_max_scale: float = 1.2
## Percentage of animation time for growth phase
@export var muzzle_flash_grow_phase_ratio: float = 0.25

@export_group("Hitscan System")
## Maximum range for hitscan weapons
@export var hitscan_max_range: float = 1000.0
## Collision mask for hitscan weapons (Environment + Enemy)
@export var hitscan_collision_mask: int = 132
## Delay for delayed hitscan weapons
@export var delayed_hitscan_delay: float = 0.15

@export_group("Tracer System")
## Tracer cylinder radius for hitscan weapons
@export var tracer_radius: float = 0.02
## Tracer shrink rate for animations (units per second)
@export var tracer_shrink_rate: float = 400.0
## Base tracer duration divisor
@export var tracer_duration_divisor: float = 16.0

@export_group("Muzzle Flash Properties")
## Muzzle flash sphere radius
@export var muzzle_flash_radius: float = 0.3
## Muzzle flash sphere height
@export var muzzle_flash_height: float = 0.6
## Muzzle flash emission energy
@export var muzzle_flash_emission_energy: float = 5.0

@export_group("Impact Effects")
## Duration for impact effects
@export var impact_effect_duration: float = 0.2
## Duration for shotgun pellet impact effects
@export var shotgun_impact_duration: float = 0.1

@export_group("Explosion Animation")
## Explosion scale-up duration
@export var explosion_scale_up_duration: float = 0.1
## Explosion scale-down duration
@export var explosion_scale_down_duration: float = 0.4
## Total explosion animation duration
@export var explosion_total_duration: float = 0.5
## Explosion fade delay timing
@export var explosion_fade_delay_1: float = 0.1
## Explosion fade delay timing
@export var explosion_fade_delay_2: float = 0.3
## Maximum explosion scale
@export var explosion_max_scale: float = 2.0
## Initial explosion emission energy
@export var explosion_initial_emission: float = 5.0

@export_group("Equip Animation")
## Duration for gun equip animation
@export var equip_animation_duration: float = 0.3
## Bounce factor for equip animation (overshoot)
@export var equip_animation_bounce_factor: float = 1.2
## Growth phase ratio for equip animation
@export var equip_grow_phase_ratio: float = 0.7
## Settle phase ratio for equip animation
@export var equip_settle_phase_ratio: float = 0.3

@export_group("Travel Configuration")
## Assault rifle fire rate for continuous fire
@export var assault_rifle_fire_rate: float = 0.15
## Fast fire mode fire rate
@export var fast_fire_rate: float = 0.05
## Heavy blast damage value
@export var heavy_blast_damage: int = 300

@export_group("Debug Settings")
## Enable debug output for gun initialization and setup
@export var debug_initialization: bool = false
## Enable debug output for firing events
@export var debug_firing: bool = false
## Enable debug output for state changes
@export var debug_state_changes: bool = false
## Enable debug output for ammo system
@export var debug_ammo: bool = false
## Enable debug output for recoil system
@export var debug_recoil: bool = false
## Enable debug output for explosion system
@export var debug_explosions: bool = false
## Enable debug output for equip/unequip system
@export var debug_equipment: bool = false
## Enable debug output for energy system integration
@export var debug_energy: bool = false

@export_group("Bullet Travel Behaviors")
@export var rapid_fire_travel: int = 2  # Pistol: CONSTANT_FAST projectiles
@export var charge_blast_travel: int = 2  # Assault rifle: CONSTANT_FAST projectiles  
@export var dash_attack_travel: int = 2  # Shotgun: CONSTANT_FAST pellets
@export var jump_burst_travel: int = 2  # Triple shot: CONSTANT_FAST projectiles
@export var slow_fire_travel: int = 1   # Rocket launcher: CONSTANT_SLOW rockets
@export var fast_fire_travel: int = 6   # Unused
@export var heavy_blast_travel: int = 0 # Unused  
@export var triple_shot_travel: int = 5 # Unused
@export var auto_charge_travel: int = 4 # Unused

# === STATE ===
var current_state: State = State.IDLE
var current_fire_mode: FireMode = FireMode.RAPID_FIRE
var charge_level: float = 0.0  # 0.0 to 1.0
var rapid_fire_current_rate: float
var rapid_fire_timer: Timer
var charge_timer: Timer
var burst_shots_remaining: int = 0
var is_firing_active: bool = false  # For testing mode

# === EQUIP STATE ===
var is_gun_equipped: bool = false
var equip_animation_active: bool = false

# === AMMO SYSTEM ===
var current_ammo: int = 0

# === RECOIL STATE ===
var is_recoiling: bool = false
var recoil_timer: float = 0.0

# === TIME SYSTEM INTEGRATION ===
@export var affect_muzzle_flash: bool = true  # Whether muzzle flash should be time-scaled
@export var affect_visual_effects: bool = true  # Whether visual effects should be time-scaled
var time_manager: Node = null
var time_energy_manager: Node = null

# === COMPONENTS ===
# Player bullet scene (you'll create this)
@export var player_bullet_scene: PackedScene = preload("res://scenes/bullets/PlayerBullet.tscn")
@onready var camera = get_parent()  # Gun is now child of camera
@onready var player = camera.get_parent()  # Player is camera's parent
@onready var muzzle_marker = $Marker3D
@onready var muzzle_flash: MeshInstance3D = create_muzzle_flash_node()

# === BULLET PRE-SPAWN SYSTEM ===
var prepared_bullet: Area3D = null  # Bullet that is spawned ahead of time and ready to fire

# === SIGNALS ===
signal state_changed(new_state: State)
signal fire_mode_changed(new_mode: FireMode)
signal charge_level_changed(level: float)
signal fired_shot(damage: int)
signal ammo_changed(current: int, max: int)

# === MANUAL ANIMATION SYSTEM ===
var active_muzzle_flashes: Array[Dictionary] = []
var active_tracers: Array[Dictionary] = []

func _process(delta: float):
	"""Update all manual animations with time-adjusted delta."""
	# Update recoil
	_update_recoil(delta)
	
	# Update equip animation
	if equip_animation_active:
		_update_equip_animation(delta)
	
	# Get time-adjusted delta like TracerManager does
	var time_manager = get_node_or_null("/root/TimeManager")
	var time_adjusted_delta = time_manager.get_effective_delta(delta, 0.0) if time_manager else delta
	
	# Update muzzle flashes
	var flashes_to_remove: Array[int] = []
	for i in range(active_muzzle_flashes.size()):
		var flash_data = active_muzzle_flashes[i]
		if _update_muzzle_flash_animation(flash_data, time_adjusted_delta):
			flashes_to_remove.append(i)
	
	for i in range(flashes_to_remove.size() - 1, -1, -1):
		active_muzzle_flashes.remove_at(flashes_to_remove[i])
	
	# Update tracers
	var tracers_to_remove: Array[int] = []
	for i in range(active_tracers.size()):
		var tracer_data = active_tracers[i]
		if _update_tracer_animation(tracer_data, time_adjusted_delta):
			tracers_to_remove.append(i)
	
	for i in range(tracers_to_remove.size() - 1, -1, -1):
		active_tracers.remove_at(tracers_to_remove[i])



func _update_muzzle_flash_animation(flash_data: Dictionary, time_adjusted_delta: float) -> bool:
	"""Update a single muzzle flash animation. Returns true if animation is complete."""
	var muzzle_flash = flash_data.get("muzzle_flash")
	var age = flash_data.get("age", 0.0)
	var total_duration = flash_data.get("total_duration", 0.2)
	var phase = flash_data.get("phase", "grow")  # grow, shrink
	
	if not is_instance_valid(muzzle_flash):
		return true  # Remove invalid flashes
	
	# Age the flash using UNSCALED delta - muzzle flash should always proceed at normal speed
	age += get_process_delta_time()  # Use unscaled delta time
	flash_data["age"] = age
	
	# Calculate progress
	var progress = age / total_duration
	
	match phase:
		"grow":
			# Grow phase (0.0 to grow_phase_ratio of total time)
			var grow_progress = min(1.0, progress / muzzle_flash_grow_phase_ratio)
			var scale_range = muzzle_flash_max_scale - muzzle_flash_min_scale
			muzzle_flash.scale = Vector3.ONE * (muzzle_flash_min_scale + grow_progress * scale_range)
			
			if grow_progress >= 1.0:
				phase = "shrink"
				flash_data["phase"] = phase
		
		"shrink":
			# Shrink and hide phase (grow_phase_ratio to 1.0 of total time)
			var shrink_progress = (progress - muzzle_flash_grow_phase_ratio) / (1.0 - muzzle_flash_grow_phase_ratio)
			if shrink_progress >= 1.0:
				shrink_progress = 1.0
			
			muzzle_flash.scale = Vector3.ONE * (muzzle_flash_max_scale - shrink_progress * muzzle_flash_max_scale)
			
			if shrink_progress >= 1.0:
				# Animation complete
				muzzle_flash.visible = false
				return true
	
	return false

func _update_tracer_animation(tracer_data: Dictionary, time_adjusted_delta: float) -> bool:
	"""Update a single tracer animation. Returns true if animation is complete."""
	var tracer = tracer_data.get("tracer")
	var age = tracer_data.get("age", 0.0)
	var total_duration = tracer_data.get("total_duration", 0.0)
	var original_height = tracer_data.get("original_height", 0.0)
	var impact_end = tracer_data.get("impact_end", Vector3.ZERO)
	var line_direction = tracer_data.get("line_direction", Vector3.ZERO)
	
	if not is_instance_valid(tracer):
		return true  # Remove invalid tracers
	
	# Age the tracer
	age += time_adjusted_delta
	tracer_data["age"] = age
	
	# Calculate progress
	var progress = age / total_duration
	
	if progress >= 1.0:
		# Animation complete
		tracer.queue_free()
		return true
	
	# Update tracer height and position
	var new_height = original_height * (1.0 - progress)
	if new_height < 0.01:
		new_height = 0.01  # Prevent zero height
	
	tracer.mesh.height = new_height
	tracer.global_position = impact_end - line_direction * (new_height / 2.0)
	
	return false

func _ready():
	# Initialize gun data resources
	_initialize_gun_data_resources()
	
	# Initialize timers
	rapid_fire_timer = Timer.new()
	rapid_fire_timer.one_shot = true
	rapid_fire_timer.timeout.connect(_on_rapid_fire_timer_timeout)
	add_child(rapid_fire_timer)
	
	charge_timer = Timer.new()
	charge_timer.one_shot = false
	charge_timer.wait_time = 0.1  # Update charge every 100ms
	charge_timer.timeout.connect(_update_charge)
	add_child(charge_timer)
	
	# Connect to time manager for visual effects
	time_manager = get_node("/root/TimeManager")
	if time_manager:
		if debug_initialization:
			print("Gun connected to TimeManager for visual effects")
	
	# Connect to time energy manager
	time_energy_manager = get_node("/root/TimeEnergyManager")
	if time_energy_manager:
		if debug_initialization:
			print("Gun connected to TimeEnergyManager")
	else:
		if debug_initialization:
			print("WARNING: Gun can't find TimeEnergyManager!")
	
	# Set initial state
	_change_state(State.IDLE)
	
	# Initialize ammo system - start with 0 ammo until gun is picked up
	current_ammo = 0
	ammo_changed.emit(current_ammo, max_ammo)
	
	# Apply auto-positioning if enabled
	if auto_position:
		position = screen_position
	
	# Start unequipped (hidden) - player must find gun pickup
	unequip_gun()
	
	if debug_initialization:
		print("Gun ready! Testing mode: ", testing_mode)
		if testing_mode:
			print("\n=== GUN TESTING CONTROLS ===")
			print("Fire mode controls:")
			print("1 - Pistol (", "%.1f" % rapid_fire_spread, "° spread) - Single shot, moderate damage")
			print("2 - Assault Rifle (", "%.1f" % charge_blast_spread, "° spread) - Continuous fire, hold to spray")
			print("3 - Shotgun (", "%.1f" % dash_attack_spread, "° spread) - ", dash_attack_pellets, " pellets, high damage")
			print("4 - Triple Shot (", "%.1f" % jump_burst_spread, "° spread) - 3 shot burst")
			print("5 - Rocket Launcher (", "%.1f" % slow_fire_spread, "° spread) - High damage explosive")
			print("6 - Fast Fire (", "%.1f" % fast_fire_spread, "° spread) - Unused") 
			print("7 - Heavy Blast (", "%.1f" % heavy_blast_spread, "° spread) - Unused")
			print("8 - Shotgun Old (", "%.1f" % triple_shot_spread, "° spread) - Unused")
			print("9 - Auto Charge (", "%.1f" % auto_charge_spread, "° spread) - Unused")
			print("\nControls:")
			print("Left Click - Fire in selected mode")
			print("Q - Dash")
			print("================================\n")

func _input(event):
	# Don't process input if gun is disabled or not equipped
	if not is_processing_input() or not is_gun_equipped:
		return
		
	if testing_mode:
		_handle_testing_input(event)
	elif movement_based:
		# Keep original debug mode for movement-based system
		if event is InputEventMouseButton:
			if event.button_index == MOUSE_BUTTON_LEFT:
				if event.pressed:
					_start_debug_firing()
				else:
					_stop_debug_firing()

func _handle_testing_input(event):
	# Handle fire mode selection (keys 1-9)
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_1:
				_set_fire_mode(FireMode.RAPID_FIRE)
			KEY_2:
				_set_fire_mode(FireMode.CHARGE_BLAST)
			KEY_3:
				_set_fire_mode(FireMode.DASH_ATTACK)
			KEY_4:
				_set_fire_mode(FireMode.JUMP_BURST)
			KEY_5:
				_set_fire_mode(FireMode.SLOW_FIRE)
			KEY_6:
				_set_fire_mode(FireMode.FAST_FIRE)
			KEY_7:
				_set_fire_mode(FireMode.HEAVY_BLAST)
			KEY_8:
				_set_fire_mode(FireMode.TRIPLE_SHOT)
			KEY_9:
				_set_fire_mode(FireMode.AUTO_CHARGE)
	
	# Handle firing (action_fire input)
	if event.is_action_pressed("action_fire"):
		_start_test_firing()
	elif event.is_action_released("action_fire"):
		_stop_test_firing()

func _set_fire_mode(mode: FireMode):
	if current_fire_mode == mode:
		return
	
	current_fire_mode = mode
	fire_mode_changed.emit(mode)
	
	var mode_names = ["Pistol", "Assault Rifle", "Shotgun", "Triple Shot", 
					  "Rocket Launcher", "Fast Fire", "Heavy Blast", "Shotgun Old", "Auto Charge"]
	var travel_names = ["Hitscan", "Constant Slow", "Constant Fast", "Slow→Fast", 
						"Fast→Slow", "Smooth Accel", "Pulsing", "Delayed Hitscan"]
	var spread = get_current_spread()
	var travel_type = get_current_travel_type()
	var explosive_text = ""
	if is_current_mode_explosive():
		explosive_text = " | EXPLOSIVE (R:" + str(get_current_explosion_radius()) + " D:" + str(get_current_explosion_damage()) + ")"
	
	var shotgun_text = ""
	if is_current_mode_shotgun():
		shotgun_text = " | SHOTGUN (" + str(get_current_pellet_count()) + " pellets, " + str(get_current_shotgun_spread()) + "° spread)"
	
	print("Fire mode: ", mode_names[mode], " | Spread: ", "%.1f" % spread, "° | Travel: ", travel_names[travel_type], explosive_text, shotgun_text)
	
	# Stop current activity and reset to idle
	_change_state(State.IDLE)

func _start_test_firing():
	is_firing_active = true
	
	match current_fire_mode:
		FireMode.RAPID_FIRE:
			_change_state(State.FIRING)
		FireMode.CHARGE_BLAST:
			# Assault rifle: continuous fire, no charging
			_start_assault_rifle()
		FireMode.DASH_ATTACK:
			_fire_shotgun_blast()
		FireMode.JUMP_BURST:
			_fire_jump_burst()
		FireMode.SLOW_FIRE:
			_start_slow_fire()
		FireMode.FAST_FIRE:
			_start_fast_fire()
		FireMode.HEAVY_BLAST:
			_fire_heavy_blast()
		FireMode.TRIPLE_SHOT:
			_fire_triple_shot()
		FireMode.AUTO_CHARGE:
			_start_auto_charge()

func _stop_test_firing():
	is_firing_active = false
	
	match current_fire_mode:
		FireMode.CHARGE_BLAST:
			# Assault rifle: just stop firing, no charging behavior
			pass
		FireMode.AUTO_CHARGE:
			if current_state == State.CHARGED:  # Only fire if fully charged
				_fire_charged_blast()
			else:
				print("Released before fully charged - no shot fired")
	
	_change_state(State.IDLE)

# === NEW FIRE MODES FOR TESTING ===
func _start_assault_rifle():
	# Assault rifle: fast continuous fire
	rapid_fire_current_rate = assault_rifle_fire_rate
	_change_state(State.FIRING)

func _fire_shotgun_blast():
	# Shotgun: single blast with multiple pellets
	_fire_bullet(dash_attack_damage)
	fired_shot.emit(dash_attack_damage)
	if debug_firing:
		print("Shotgun blast! Damage: ", dash_attack_damage)

func _start_slow_fire():
	# Rocket launcher: single shot with high damage
	_fire_bullet(slow_fire_damage)
	fired_shot.emit(slow_fire_damage)
	if debug_firing:
		print("Rocket fired! Damage: ", slow_fire_damage)

func _start_fast_fire():
	rapid_fire_current_rate = fast_fire_rate
	_change_state(State.FIRING)

func _fire_heavy_blast():
	_fire_bullet(heavy_blast_damage)
	fired_shot.emit(heavy_blast_damage)
	if debug_firing:
		print("Heavy blast! Damage: ", heavy_blast_damage)

func _fire_triple_shot():
	# Now handled by shotgun system - this is just for backward compatibility
	_fire_bullet(rapid_fire_damage)
	fired_shot.emit(rapid_fire_damage)
	if debug_firing:
		print("Shotgun blast!")

func _start_auto_charge():
	_change_state(State.CHARGING)

# === DEBUG FIRING (for movement-based mode) ===
func _start_debug_firing():
	if debug_firing:
		print("Debug firing started")
	_change_state(State.FIRING)

func _stop_debug_firing():
	if debug_firing:
		print("Debug firing stopped")
	_change_state(State.IDLE)

# === PLAYER SIGNAL HANDLERS (only used if movement_based is true) ===
func _on_player_movement_started():
	if not movement_based:
		return
	
	match current_state:
		State.IDLE:
			_change_state(State.FIRING)
		State.CHARGING:
			_fire_charged_blast()
			_change_state_with_delay(State.FIRING, 0.2)
		State.CHARGED:
			_fire_charged_blast()
			_change_state_with_delay(State.FIRING, 0.2)

func _on_player_movement_stopped():
	if not movement_based:
		return
	
	match current_state:
		State.FIRING:
			_change_state(State.CHARGING)
		State.DASH_MODE:
			_change_state(State.CHARGING)

func _on_player_dash_performed():
	if not movement_based:
		return
	
	_change_state(State.DASH_MODE)
	_fire_dash_attack()

func _on_player_jump_performed():
	if not movement_based:
		return
	
	if current_state == State.FIRING:
		_fire_jump_burst()

func _on_player_landed():
	if not movement_based:
		return
	
	# Could add landing effects here if needed
	pass

# === STATE MANAGEMENT ===
func _change_state(new_state: State):
	if current_state == new_state:
		return
	
	# Exit current state
	match current_state:
		State.FIRING:
			_stop_rapid_fire()
		State.CHARGING, State.CHARGED:
			_stop_charging()
		State.DASH_MODE:
			pass  # Dash is instantaneous
	
	# Enter new state
	current_state = new_state
	match new_state:
		State.IDLE:
			pass
		State.FIRING:
			_start_rapid_fire()
		State.CHARGING:
			_start_charging()
		State.CHARGED:
			pass  # Already charged, just waiting
		State.DASH_MODE:
			pass  # Dash is instantaneous
	
	state_changed.emit(new_state)
	if debug_state_changes:
		print("Gun state: ", State.keys()[new_state])

func _change_state_with_delay(new_state: State, delay: float):
	var delay_timer = Timer.new()
	delay_timer.wait_time = delay
	delay_timer.one_shot = true
	delay_timer.timeout.connect(func(): 
		_change_state(new_state)
		delay_timer.queue_free()
	)
	add_child(delay_timer)
	delay_timer.start()

# === RAPID FIRE SYSTEM ===
func _start_rapid_fire():
	if not testing_mode and not movement_based:
		return
	
	if movement_based and not movement_based and player.is_player_dashing():
		return  # Don't fire while dashing (only in movement mode)
	
	if rapid_fire_current_rate == 0.0:
		rapid_fire_current_rate = rapid_fire_rate_start
	
	_fire_rapid_shot()

func _stop_rapid_fire():
	if rapid_fire_timer.is_inside_tree():
		rapid_fire_timer.stop()

func _fire_rapid_shot():
	if current_state != State.FIRING:
		return
	
	if not testing_mode and not is_firing_active:
		return
	
	if movement_based and player.is_player_dashing():
		return  # Don't fire while dashing (only in movement mode)
	
	_fire_bullet(rapid_fire_damage)
	fired_shot.emit(rapid_fire_damage)
	
	# Schedule next shot with increasing fire rate (only for normal rapid fire)
	if current_fire_mode == FireMode.RAPID_FIRE:
		rapid_fire_current_rate = max(rapid_fire_rate_min, 
			rapid_fire_current_rate - rapid_fire_acceleration)
	
	rapid_fire_timer.wait_time = rapid_fire_current_rate
	rapid_fire_timer.start()

func _on_rapid_fire_timer_timeout():
	_fire_rapid_shot()

# === CHARGING SYSTEM ===
func _start_charging():
	charge_level = 0.0
	charge_timer.start()
	if debug_state_changes:
		print("Started charging...")

func _stop_charging():
	charge_timer.stop()
	charge_level = 0.0
	charge_level_changed.emit(0.0)

func _update_charge():
	if current_state == State.CHARGING:
		charge_level += charge_timer.wait_time / charge_time
		charge_level = min(1.0, charge_level)
		charge_level_changed.emit(charge_level)
		
		if charge_level >= 1.0:
			_change_state(State.CHARGED)
			if debug_state_changes:
				print("*** GUN FULLY CHARGED! Release to fire! ***")

func _fire_charged_blast():
	# We only call this when fully charged, so no need to check minimum
	var damage = int(lerp(charged_blast_damage_min, charged_blast_damage_max, charge_level))
	_fire_bullet(damage)
	fired_shot.emit(damage)
	
	if debug_firing:
		print("Charged blast fired! Damage: ", damage, " (charge: ", "%.1f" % (charge_level * 100), "%)")
	charge_level = 0.0
	charge_level_changed.emit(0.0)

# === SPECIAL ATTACKS ===
func _fire_dash_attack():
	_fire_bullet(dash_attack_damage)
	fired_shot.emit(dash_attack_damage)
	if debug_firing:
		print("Dash attack! Damage: ", dash_attack_damage)

func _fire_jump_burst():
	burst_shots_remaining = jump_burst_count
	_fire_burst_shot()

func _fire_burst_shot():
	if burst_shots_remaining <= 0:
		return
	
	_fire_bullet(jump_burst_damage)
	fired_shot.emit(jump_burst_damage)
	burst_shots_remaining -= 1
	
	if burst_shots_remaining > 0:
		# Schedule next burst shot
		var burst_timer = Timer.new()
		burst_timer.process_mode = Timer.TIMER_PROCESS_PHYSICS
		burst_timer.wait_time = jump_burst_interval
		burst_timer.timeout.connect(func(): 
			_fire_burst_shot()
			burst_timer.queue_free()
		)
		add_child(burst_timer)
		burst_timer.start()

# === BULLET SPAWNING ===
func _prepare_next_bullet():
	# Only prepare a bullet if we have ammo remaining
	if current_ammo <= 0:
		if debug_ammo:
			print("Not preparing bullet - no ammo remaining")
		return
		
	# Instantiate a bullet ahead of time so it's ready when we need to fire
	prepared_bullet = player_bullet_scene.instantiate()
	# Add directly to main scene since bullets are now scene children
	get_tree().current_scene.add_child.call_deferred(prepared_bullet)
	
	# Setup the bullet after it's added to the scene
	_setup_prepared_bullet.call_deferred()
	if debug_ammo:
		print("Prepared next bullet - ammo remaining: ", current_ammo)

func _setup_prepared_bullet():
	if not prepared_bullet:
		return
		
	# Give the bullet reference to gun and muzzle so it can track position
	if prepared_bullet.has_method("set_gun_reference"):
		prepared_bullet.set_gun_reference(self, muzzle_marker)
	
	# Mark as player bullet (enables recall ability)
	if prepared_bullet.has_method("set_as_player_bullet"):
		prepared_bullet.set_as_player_bullet()
	
	# Position the bullet at the muzzle (it will continue tracking via script)
	prepared_bullet.global_position = get_muzzle_position()
	


func _fire_bullet(damage: int):
	# Check if we have ammo
	if current_ammo <= 0:
		# Play empty chamber SFX
		AudioManager.play_sfx("pistol_empty_chamber")
		
		if debug_ammo:
			print("Cannot fire - no ammo remaining!")
		return
	
	# Check if firing is allowed by energy system
	if time_energy_manager and not time_energy_manager.can_fire():
		if debug_energy:
			print("Firing blocked - insufficient energy or in forced recharge")
		return
	
	# Drain energy for firing
	if time_energy_manager:
		var energy_drained = time_energy_manager.drain_energy_for_firing()
		if not energy_drained:
			if debug_energy:
				print("Firing blocked - energy drain failed")
			return
	
	# Consume ammo
	current_ammo -= 1
	ammo_changed.emit(current_ammo, max_ammo)
	
	# Track bullet fired for analytics
	AnalyticsManager.track_bullet_fired()
	
	if debug_ammo:
		print("Ammo: ", current_ammo, "/", max_ammo)
	
	# Apply velocity loss to player when firing (only when actually firing)
	# TEMPORARILY DISABLED FOR TESTING
	# _apply_firing_velocity_loss()
	
	var travel_type = get_current_travel_type()
	
	# Show muzzle flash for all weapon types
	_show_muzzle_flash()
	
	# Play gunshot SFX
	_play_gunshot_sfx()
	
	# Apply recoil kick AFTER firing (next frame) to avoid targeting issues
	call_deferred("_apply_recoil")
	
	# Check if this is a shotgun weapon
	if is_current_mode_shotgun():
		_fire_shotgun(damage, travel_type)
	# Check if this is a hitscan weapon (travel type 0 or 7)
	elif travel_type == 0 or travel_type == 7:
		_fire_hitscan(damage, travel_type)
	else:
		_fire_projectile(damage)

func _fire_hitscan(damage: int, travel_type: int):
	"""Fire an instant hitscan weapon."""
	var spawn_position = get_muzzle_position()
	var fire_direction = get_firing_direction()
	
	if debug_firing:
		print("FIRING HITSCAN - Type: ", travel_type, " Damage: ", damage)
	
	# For delayed hitscan, add a brief delay
	if travel_type == 7:  # DELAYED_HITSCAN
		await get_tree().create_timer(delayed_hitscan_delay).timeout
	
	# Perform raycast
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		spawn_position,
		spawn_position + fire_direction * hitscan_max_range
	)
	
	# Set collision mask - hit Environment (4) + Enemy (128) = 132
	query.collision_mask = hitscan_collision_mask
	query.exclude = [get_tree().get_first_node_in_group("player")]  # Don't hit player
	
	var result = space_state.intersect_ray(query)
	var impact_position: Vector3
	
	if result:
		if debug_firing:
			print("Hitscan hit: ", result.collider.name, " at ", result.position)
		impact_position = result.position
		
		# Deal direct damage if we hit an enemy
		if result.collider.has_method("take_damage"):
			result.collider.take_damage(damage)
			# Play bullet hit enemy SFX
			AudioManager.play_sfx("bullet_enemy_hit")
		else:
			# Hit environment - create wall ripple effect
			_create_wall_ripple(result.position, result.normal)
		
		# Create visual effects
		_create_hitscan_effects(spawn_position, result.position)
	else:
		if debug_firing:
			print("Hitscan missed")
		impact_position = spawn_position + fire_direction * hitscan_max_range
		# Create tracer to max range
		_create_hitscan_effects(spawn_position, impact_position)
	
	# Handle explosion if this weapon is explosive
	if is_current_mode_explosive():
		_create_explosion(impact_position)

func _fire_projectile(damage: int):
	"""Fire a projectile bullet."""
	var spawn_position = get_muzzle_position()
	var fire_direction = get_firing_direction()
	
	var bullet: Area3D
	if prepared_bullet:
		bullet = prepared_bullet
		prepared_bullet = null
	else:
		# Fallback if no prepared bullet
		bullet = player_bullet_scene.instantiate()
		get_tree().current_scene.add_child(bullet)
		if bullet.has_method("set_gun_reference"):
			bullet.set_gun_reference(self, muzzle_marker)
		# Mark as player bullet (enables recall ability)
		if bullet.has_method("set_as_player_bullet"):
			bullet.set_as_player_bullet()
	
	# Bullet is already in scene root, just activate it
	bullet.global_position = spawn_position
	# Area3D doesn't have freeze/sleeping properties
	
	# Configure bullet collision
	bullet.collision_layer = 2  # Bullets layer  
	bullet.collision_mask = 132  # Environment (bit 3=4) + Enemy (bit 8=128) = 132 (NO player layer)
	
	# Area3D automatically handles collision detection
	
	# Pass damage value if bullet script supports it
	if bullet.has_method("set_damage"):
		bullet.set_damage(damage)
	
	# Pass knockback value if bullet script supports it
	if bullet.has_method("set_knockback"):
		bullet.set_knockback(get_current_knockback())
	
	# Pass explosion properties if this weapon is explosive
	if is_current_mode_explosive() and bullet.has_method("set_explosion_properties"):
		bullet.set_explosion_properties(get_current_explosion_radius(), get_current_explosion_damage())
	
	# Pass piercing properties if bullet script supports it
	if bullet.has_method("set_piercing_properties"):
		bullet.set_piercing_properties(get_current_piercing())
	
	# Mark as player bullet (enables recall ability)
	if bullet.has_method("set_as_player_bullet"):
		bullet.set_as_player_bullet()
	
	# Configure travel behavior before firing (for projectiles only)
	if bullet.has_method("set_travel_config"):
		var travel_type = get_current_travel_type()
		var travel_config = get_travel_config_for_mode()
		bullet.set_travel_config(travel_type, travel_config)
	
	# Fire the bullet
	if bullet.has_method("fire"):
		bullet.fire(fire_direction)
	elif bullet.has_method("set_direction"):
		bullet.set_direction(fire_direction)
	
	# Prepare the next bullet
	_prepare_next_bullet()

func create_muzzle_flash_node() -> MeshInstance3D:
	"""Create and setup the muzzle flash node attached to the gun."""
	var flash = MeshInstance3D.new()
	flash.name = "MuzzleFlash"
	
	# Create sphere mesh
	var sphere = SphereMesh.new()
	sphere.radius = muzzle_flash_radius
	sphere.height = muzzle_flash_height
	flash.mesh = sphere
	
	# Create bright yellow material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.YELLOW
	material.emission_enabled = true
	material.emission = Color.YELLOW
	material.emission_energy = muzzle_flash_emission_energy
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash.material_override = material
	
	# Initially hidden
	flash.visible = false
	
	# Attach to muzzle marker
	muzzle_marker.add_child(flash)
	
	return flash

func _show_muzzle_flash():
	"""Show the muzzle flash briefly."""
	if not muzzle_flash:
		return
	
	muzzle_flash.visible = true
	
	# Start with small scale
	muzzle_flash.scale = Vector3.ONE * muzzle_flash_min_scale
	
	# Add to active muzzle flashes list for manual animation
	var flash_data = {
		"muzzle_flash": muzzle_flash,
		"age": 0.0,
		"total_duration": muzzle_flash_duration,
		"phase": "grow"
	}
	active_muzzle_flashes.append(flash_data)

func _create_hitscan_effects(start_pos: Vector3, end_pos: Vector3):
	"""Create visual effects for hitscan weapons."""
	# Force transform update to get current muzzle position
	muzzle_marker.force_update_transform()
	var current_muzzle_pos = muzzle_marker.global_position
	
	# Recalculate end position based on current muzzle position to maintain direction
	var original_direction = (end_pos - start_pos).normalized()
	var original_distance = start_pos.distance_to(end_pos)
	var corrected_end_pos = current_muzzle_pos + original_direction * original_distance
	
	# Create tracer line with corrected positions
	_create_hitscan_tracer(current_muzzle_pos, corrected_end_pos)
	
	# Create impact effect at corrected hit point
	if current_muzzle_pos.distance_to(corrected_end_pos) < 999.0:  # If we actually hit something
		_create_impact_effect(corrected_end_pos)

func _create_hitscan_tracer(start_pos: Vector3, end_pos: Vector3):
	"""Create a bright tracer line for hitscan weapons."""
	var tracer = MeshInstance3D.new()
	get_tree().current_scene.add_child(tracer)
	
	# Calculate line direction first
	var line_direction = (end_pos - start_pos).normalized()
	
	# Create cylinder mesh for tracer
	var cylinder = CylinderMesh.new()
	var line_length = start_pos.distance_to(end_pos)
	cylinder.height = line_length
	cylinder.top_radius = tracer_radius
	cylinder.bottom_radius = tracer_radius
	tracer.mesh = cylinder
	
	# Position at center of line (normal positioning)
	var center_pos = (start_pos + end_pos) / 2.0
	tracer.global_position = center_pos
	
	# Orient the cylinder along the line direction (Y-axis should align with line direction)
	if line_direction.length() > 0.001:
		var new_y = line_direction.normalized()
		var new_x = Vector3.RIGHT
		
		# Make sure X is perpendicular to Y
		if abs(new_y.dot(new_x)) > 0.9:
			new_x = Vector3.FORWARD
		
		new_x = (new_x - new_y * new_y.dot(new_x)).normalized()
		var new_z = new_x.cross(new_y).normalized()
		
		# Additional safety checks to prevent singular matrix
		if new_x.length() > 0.01 and new_y.length() > 0.01 and new_z.length() > 0.01:
			var determinant = new_x.cross(new_y).dot(new_z)
			if abs(determinant) > 0.001:  # Ensure non-singular matrix
				var new_basis = Basis(new_x, new_y, new_z)
				tracer.global_transform.basis = new_basis
	
	# Create glowing material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.CYAN
	material.emission_enabled = true
	material.emission = Color.CYAN
	material.emission_energy = 3.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	tracer.material_override = material
	
	# Add to active tracers list for manual animation
	var tracer_data = {
		"tracer": tracer,
		"age": 0.0,
		"total_duration": line_length / tracer_duration_divisor,
		"original_height": line_length,
		"impact_end": end_pos,
		"line_direction": line_direction
	}
	active_tracers.append(tracer_data)

func _create_impact_effect(pos: Vector3):
	"""Create impact effect at hit location."""
	# Use TracerManager to create impact effect
	if TracerManager:
		TracerManager.create_impact(pos, Color.ORANGE, impact_effect_duration)

func _animate_hitscan_tracer_fadeout(tracer: MeshInstance3D, tracer_length: float, impact_end: Vector3, line_dir: Vector3):
	"""Animate hitscan tracer fade out with consistent shrink rate."""
	if not tracer or not is_instance_valid(tracer):
		return
	
	# Get current time scale to adjust animation speed
	var time_manager = get_node_or_null("/root/TimeManager")
	var time_scale = time_manager.get_time_scale() if time_manager else 1.0
	
	# Calculate duration based on length for consistent shrink rate
	var base_duration = tracer_length / tracer_duration_divisor
	
	# Scale duration by time scale (slower when time is slowed)
	var duration = base_duration * time_scale
	
	# Animate the cylinder height and position to shrink from gun end
	var original_height = tracer.mesh.height
	
	# Capture ALL variables for use in animation callback
	var captured_tracer = tracer
	var captured_original_height = original_height
	var captured_impact_end = impact_end
	var captured_line_direction = line_dir
	
	# Custom animation that shrinks height while keeping impact end stationary
	var animation_tween = get_tree().create_tween()
	
	animation_tween.tween_method(
		func(value):
			var new_height = captured_original_height * (1.0 - value)
			if new_height < 0.01:
				new_height = 0.01  # Prevent zero height
			captured_tracer.mesh.height = new_height
			# Reposition so impact end stays at end_pos
			captured_tracer.global_position = captured_impact_end - captured_line_direction * (new_height / 2.0),
		0.0, 1.0, duration
	).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	
	# Clean up after animation
	animation_tween.tween_callback(func(): if is_instance_valid(captured_tracer): captured_tracer.queue_free())

func _animate_impact_fadeout(impact: MeshInstance3D):
	"""Animate impact effect fade out."""
	if not impact or not is_instance_valid(impact):
		return
	
	# Get current time scale to adjust animation speed
	var time_manager = get_node_or_null("/root/TimeManager")
	var time_scale = time_manager.get_time_scale() if time_manager else 1.0
	
	# Scale animation durations by time scale (slower when time is slowed)
	var scale_up_duration = 0.1 * time_scale
	var scale_down_duration = 0.4 * time_scale
	var total_duration = 0.5 * time_scale
		
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	
	# Scale up then down
	tween.tween_property(impact, "scale", Vector3(2.0, 2.0, 2.0), scale_up_duration)
	tween.tween_property(impact, "scale", Vector3.ZERO, scale_down_duration).set_delay(scale_up_duration)
	
	# Remove after animation
	tween.tween_callback(func(): if is_instance_valid(impact): impact.queue_free()).set_delay(total_duration)
	_prepare_next_bullet()

# === SHOTGUN SYSTEM ===
func _fire_shotgun(damage: int, travel_type: int):
	"""Fire multiple pellets simultaneously in a spread pattern."""
	var pellet_count = get_current_pellet_count()
	var shotgun_spread = get_current_shotgun_spread()
	var pellet_damage = max(1, damage / pellet_count)  # Distribute damage across pellets
	
	if debug_firing:
		print("FIRING SHOTGUN - ", pellet_count, " pellets, ", pellet_damage, " damage each, ", shotgun_spread, "° spread")
	
	# Note: Energy was already drained in _fire_bullet, so we don't drain again here
	
	# Fire each pellet
	for i in range(pellet_count):
		# Generate spread direction for this pellet
		var pellet_direction = _get_shotgun_pellet_direction(shotgun_spread)
		
		# Fire pellet based on travel type
		if travel_type == 0 or travel_type == 7:  # Hitscan
			_fire_shotgun_hitscan_pellet(pellet_damage, travel_type, pellet_direction)
		else:  # Projectile
			_fire_shotgun_projectile_pellet(pellet_damage, pellet_direction)

func _get_shotgun_pellet_direction(spread_degrees: float) -> Vector3:
	"""Generate a random direction within shotgun spread cone using cursor aim."""
	# Get base direction using same cursor aim logic as regular firing
	var base_direction = get_firing_direction(false)  # Get base direction without spread
	
	if spread_degrees <= 0.0:
		return base_direction
	
	# Convert degrees to radians
	var spread_radians = deg_to_rad(spread_degrees)
	
	# Generate random offset within spread cone
	var random_angle = randf() * TAU  # Random angle around circle
	var random_radius = randf() * spread_radians  # Random radius within cone
	
	# Calculate offset in camera's local coordinate system
	var right = camera.global_transform.basis.x
	var up = camera.global_transform.basis.y
	
	var offset_x = cos(random_angle) * sin(random_radius)
	var offset_y = sin(random_angle) * sin(random_radius)
	
	# Apply offset to base direction
	var spread_direction = base_direction + (right * offset_x) + (up * offset_y)
	return spread_direction.normalized()

func _fire_shotgun_hitscan_pellet(damage: int, travel_type: int, direction: Vector3):
	"""Fire a single hitscan pellet."""
	var spawn_position = get_muzzle_position()
	
	# For delayed hitscan, add a brief delay
	if travel_type == 7:  # DELAYED_HITSCAN
		await get_tree().create_timer(delayed_hitscan_delay).timeout
	
	# Perform raycast
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		spawn_position,
		spawn_position + direction * hitscan_max_range
	)
	
	# Set collision mask - hit Environment (4) + Enemy (128) = 132
	query.collision_mask = hitscan_collision_mask
	query.exclude = [get_tree().get_first_node_in_group("player")]  # Don't hit player
	
	var result = space_state.intersect_ray(query)
	var impact_position: Vector3
	
	if result:
		impact_position = result.position
		
		# Deal direct damage if we hit an enemy
		if result.collider.has_method("take_damage"):
			result.collider.take_damage(damage)
		else:
			# Hit environment - create wall ripple effect
			_create_wall_ripple(result.position, result.normal)
		
		# Create smaller visual effects for pellets (no tracer, just impact)
		_create_shotgun_impact_effect(result.position)
	else:
		impact_position = spawn_position + direction * 1000.0
	
	# Handle explosion if this weapon is explosive
	if is_current_mode_explosive():
		_create_explosion(impact_position)

func _fire_shotgun_projectile_pellet(damage: int, direction: Vector3):
	"""Fire a single projectile pellet."""
	var spawn_position = get_muzzle_position()
	
	# Create bullet
	var bullet = player_bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	
	# Setup bullet
	bullet.global_position = spawn_position
	# Area3D doesn't have freeze/sleeping properties
	
	# Configure bullet collision
	bullet.collision_layer = 2  # Bullets layer  
	bullet.collision_mask = hitscan_collision_mask  # Environment + Enemy (NO player layer)
	
	# Area3D automatically handles collision detection
	
	# Pass damage value
	if bullet.has_method("set_damage"):
		bullet.set_damage(damage)
	
	# Pass explosion properties if this weapon is explosive
	if is_current_mode_explosive() and bullet.has_method("set_explosion_properties"):
		bullet.set_explosion_properties(get_current_explosion_radius(), get_current_explosion_damage())
	
	# Pass piercing properties if bullet script supports it
	if bullet.has_method("set_piercing_properties"):
		bullet.set_piercing_properties(get_current_piercing())
	
	# Mark as player bullet (enables recall ability)
	if bullet.has_method("set_as_player_bullet"):
		bullet.set_as_player_bullet()
	
	# Configure travel behavior
	if bullet.has_method("set_travel_config"):
		var travel_type = get_current_travel_type()
		var travel_config = get_travel_config_for_mode()
		bullet.set_travel_config(travel_type, travel_config)
	
	# Fire the bullet
	if bullet.has_method("fire"):
		bullet.fire(direction)

func _create_shotgun_impact_effect(position: Vector3):
	"""Create smaller impact effect for shotgun pellets."""
	# Use TracerManager to create smaller impact effect
	if TracerManager:
		TracerManager.create_impact(position, Color.ORANGE, shotgun_impact_duration)
	


# === EXPLOSION SYSTEM ===
func _create_explosion(position: Vector3):
	"""Create explosion effect and apply area damage."""
	var explosion_radius = get_current_explosion_radius()
	var explosion_damage = get_current_explosion_damage()
	
	if explosion_radius <= 0.0:
		return
	
	if debug_explosions:
		print("EXPLOSION at ", position, " - Radius: ", explosion_radius, " Damage: ", explosion_damage)
	
	# Apply area damage
	_apply_explosion_damage(position, explosion_radius, explosion_damage)
	
	# Create visual explosion effect
	_create_explosion_visual(position, explosion_radius)

func _apply_explosion_damage(explosion_pos: Vector3, radius: float, damage: int):
	"""Apply damage to all enemies within explosion radius."""
	var space_state = get_world_3d().direct_space_state
	
	# Find all enemies within radius using sphere collision
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = radius
	query.shape = sphere
	query.transform.origin = explosion_pos
	query.collision_mask = 128  # Enemy layer (bit 8)
	
	var results = space_state.intersect_shape(query)
	
	for result in results:
		var enemy = result.collider
		if enemy.has_method("take_damage"):
			# Calculate distance-based damage falloff
			var distance = explosion_pos.distance_to(enemy.global_position)
			var damage_multiplier = 1.0 - (distance / radius)  # Linear falloff
			var final_damage = int(damage * damage_multiplier)
			
			if debug_explosions:
				print("Explosion damaged ", enemy.name, " for ", final_damage, " damage (distance: ", "%.1f" % distance, ")")
			enemy.take_damage(final_damage)

func _create_explosion_visual(position: Vector3, radius: float):
	"""Create visual explosion effect at position."""
	# Use TracerManager to create explosion effect
	if TracerManager:
		TracerManager.create_explosion(position, radius)

func _animate_explosion_effect(explosion: MeshInstance3D, max_radius: float):
	"""Animate explosion - rapid expansion then fade."""
	if not explosion or not is_instance_valid(explosion):
		return
	
	# Get current time scale to adjust animation speed
	var time_manager = get_node_or_null("/root/TimeManager")
	var time_scale = time_manager.get_time_scale() if time_manager else 1.0
	
	# Scale animation durations by time scale (slower when time is slowed)
	var expansion_duration = 0.2 * time_scale
	var fade_duration = 0.4 * time_scale
	var scale_down_duration = 0.3 * time_scale
	var delay_1 = 0.1 * time_scale
	var delay_2 = 0.3 * time_scale
	var total_duration = 0.6 * time_scale
	
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	
	# Rapid expansion
	explosion.scale = Vector3.ZERO
	tween.tween_property(explosion, "scale", Vector3.ONE, expansion_duration)
	
	# Color fade (from bright orange to dark red)
	var material = explosion.material_override as StandardMaterial3D
	if material:
		tween.tween_method(
			func(energy): material.emission_energy = energy,
			5.0, 0.0, fade_duration
		).set_delay(delay_1)
		tween.tween_property(material, "albedo_color", Color.DARK_RED, fade_duration).set_delay(delay_1)
	
	# Scale down and remove
	tween.tween_property(explosion, "scale", Vector3.ZERO, scale_down_duration).set_delay(delay_2)
	tween.tween_callback(func(): if is_instance_valid(explosion): explosion.queue_free()).set_delay(total_duration)

func get_muzzle_position() -> Vector3:
	# Calculate exact world position of muzzle
	return muzzle_marker.global_position

func get_firing_direction(apply_spread: bool = true) -> Vector3:
	# Get camera's aim raycast for cursor accuracy
	var aim_raycast = camera.get_node_or_null("AimRayCast3D") as RayCast3D
	if not aim_raycast:
		print("WARNING: No AimRaycast found on camera! Falling back to camera forward direction.")
		return -camera.global_transform.basis.z.normalized()
	
	# Always use a fixed focal point at focal_distance in the camera's aim direction
	var camera_direction = -camera.global_transform.basis.z.normalized()
	var focal_point = camera.global_position + (camera_direction * focal_distance)
	
	# Try to get raycast collision if available (without forcing update to avoid physics timing issues)
	if aim_raycast.is_colliding():
		var hit_distance = camera.global_position.distance_to(aim_raycast.get_collision_point())
		if hit_distance < focal_distance:
			focal_point = aim_raycast.get_collision_point()
	
	# Calculate direction from gun muzzle to focal point
	var muzzle_pos = get_muzzle_position()
	var base_direction = (focal_point - muzzle_pos).normalized()
	
	if not apply_spread:
		return base_direction
	
	# Apply spread based on current fire mode
	var spread_degrees = get_current_spread()
	if spread_degrees <= 0.0:
		return base_direction
	
	# Convert degrees to radians
	var spread_radians = deg_to_rad(spread_degrees)
	
	# Generate random offset within spread cone
	var random_angle = randf() * TAU  # Random angle around circle
	var random_radius = randf() * spread_radians  # Random radius within cone
	
	# Calculate offset in camera's local coordinate system
	var right = camera.global_transform.basis.x
	var up = camera.global_transform.basis.y
	
	var offset_x = cos(random_angle) * sin(random_radius)
	var offset_y = sin(random_angle) * sin(random_radius)
	
	# Apply offset to base direction
	var spread_direction = base_direction + (right * offset_x) + (up * offset_y)
	return spread_direction.normalized()

func get_current_spread() -> float:
	match current_fire_mode:
		FireMode.RAPID_FIRE:
			return rapid_fire_spread
		FireMode.CHARGE_BLAST:
			return charge_blast_spread
		FireMode.DASH_ATTACK:
			return dash_attack_spread
		FireMode.JUMP_BURST:
			return jump_burst_spread
		FireMode.SLOW_FIRE:
			return slow_fire_spread
		FireMode.FAST_FIRE:
			return fast_fire_spread
		FireMode.HEAVY_BLAST:
			return heavy_blast_spread
		FireMode.TRIPLE_SHOT:
			return triple_shot_spread
		FireMode.AUTO_CHARGE:
			return auto_charge_spread
		_:
			return 0.0

func get_current_recoil() -> float:
	match current_fire_mode:
		FireMode.RAPID_FIRE:
			return rapid_fire_recoil
		FireMode.CHARGE_BLAST:
			return charge_blast_recoil
		FireMode.DASH_ATTACK:
			return dash_attack_recoil
		FireMode.JUMP_BURST:
			return jump_burst_recoil
		FireMode.SLOW_FIRE:
			return slow_fire_recoil
		FireMode.FAST_FIRE:
			return fast_fire_recoil
		FireMode.HEAVY_BLAST:
			return heavy_blast_recoil
		FireMode.TRIPLE_SHOT:
			return triple_shot_recoil
		FireMode.AUTO_CHARGE:
			return auto_charge_recoil
		_:
			return 0.0

func get_current_recoil_duration() -> float:
	match current_fire_mode:
		FireMode.RAPID_FIRE:
			return rapid_fire_recoil_duration
		FireMode.CHARGE_BLAST:
			return charge_blast_recoil_duration
		FireMode.DASH_ATTACK:
			return dash_attack_recoil_duration
		FireMode.JUMP_BURST:
			return jump_burst_recoil_duration
		FireMode.SLOW_FIRE:
			return slow_fire_recoil_duration
		FireMode.FAST_FIRE:
			return fast_fire_recoil_duration
		FireMode.HEAVY_BLAST:
			return heavy_blast_recoil_duration
		FireMode.TRIPLE_SHOT:
			return triple_shot_recoil_duration
		FireMode.AUTO_CHARGE:
			return auto_charge_recoil_duration
		_:
			return 0.3

func is_current_mode_explosive() -> bool:
	"""Check if current gun is explosive based on gun data."""
	if current_gun_data:
		return current_gun_data.is_explosive
	else:
		# Fallback to hardcoded values if no gun data loaded
		match current_fire_mode:
			FireMode.SLOW_FIRE:
				return true  # Rocket launcher
			_:
				return false

func get_current_explosion_radius() -> float:
	"""Get explosion radius based on current gun data."""
	if current_gun_data:
		return current_gun_data.explosion_radius
	else:
		# Fallback to hardcoded values if no gun data loaded
		match current_fire_mode:
			FireMode.SLOW_FIRE:
				return 10.0  # Rocket launcher
			_:
				return 0.0

func get_current_explosion_damage() -> int:
	"""Get explosion damage based on current gun data."""
	if current_gun_data:
		return current_gun_data.explosion_damage
	else:
		# Fallback to hardcoded values if no gun data loaded
		match current_fire_mode:
			FireMode.SLOW_FIRE:
				return 200  # Rocket launcher
			_:
				return 0

func is_current_mode_shotgun() -> bool:
	"""Check if current gun is a shotgun based on gun data."""
	if current_gun_data:
		return current_gun_data.is_shotgun
	else:
		# Fallback to hardcoded values if no gun data loaded
		match current_fire_mode:
			FireMode.DASH_ATTACK:
				return true  # Shotgun mode
			_:
				return false

func get_current_pellet_count() -> int:
	"""Get pellet count based on current gun data."""
	if current_gun_data:
		return current_gun_data.pellet_count
	else:
		# Fallback to hardcoded values if no gun data loaded
		match current_fire_mode:
			FireMode.DASH_ATTACK:
				return 8  # Shotgun pellets
			_:
				return 1

func get_current_shotgun_spread() -> float:
	"""Get shotgun spread based on current gun data."""
	if current_gun_data:
		return current_gun_data.shotgun_spread
	else:
		# Fallback to hardcoded values if no gun data loaded
		match current_fire_mode:
			FireMode.DASH_ATTACK:
				return 20.0  # Shotgun spread
			_:
				return 0.0

func get_current_piercing() -> float:
	"""Get piercing value based on current gun data."""
	if current_gun_data:
		return 1.0 if current_gun_data.piercing else 0.0
	else:
		# Fallback to hardcoded values if no gun data loaded
		match current_fire_mode:
			FireMode.SLOW_FIRE:
				return 3.0  # Rocket launcher
			_:
				return 0.0

func get_current_knockback() -> float:
	"""Get knockback value based on current gun data."""
	if current_gun_data:
		return current_gun_data.knockback_force
	else:
		# Fallback to hardcoded values if no gun data loaded
		match current_fire_mode:
			FireMode.RAPID_FIRE:
				return 2.0
			FireMode.CHARGE_BLAST:
				return 1.5
			FireMode.DASH_ATTACK:
				return 8.0
			FireMode.JUMP_BURST:
				return 3.0
			FireMode.SLOW_FIRE:
				return 15.0
			_:
				return 1.0

func get_current_travel_type() -> int:
	"""Get travel type based on current gun data."""
	if current_gun_data:
		return current_gun_data.travel_type
	else:
		# Fallback to hardcoded values if no gun data loaded
		match current_fire_mode:
			FireMode.RAPID_FIRE:
				return 2  # CONSTANT_FAST
			FireMode.CHARGE_BLAST:
				return 2  # CONSTANT_FAST
			FireMode.DASH_ATTACK:
				return 2  # CONSTANT_FAST
			FireMode.JUMP_BURST:
				return 2  # CONSTANT_FAST
			FireMode.SLOW_FIRE:
				return 1  # CONSTANT_SLOW
			_:
				return 2

func get_travel_config_for_mode() -> Dictionary:
	"""Get travel configuration for current fire mode."""
	var config = {}
	
	match current_fire_mode:
		FireMode.RAPID_FIRE:
			config = {"max_speed": 25.0, "min_speed": 25.0}  # Reduced from 50.0
		FireMode.CHARGE_BLAST:
			config = {}  # Hitscan needs no config
		FireMode.DASH_ATTACK:
			config = {"hitscan_delay": 0.15}  # Brief delay before instant travel
		FireMode.JUMP_BURST:
			config = {"max_speed": 30.0, "min_speed": 3.0, "acceleration_rate": 50.0}  # Reduced speeds and acceleration
		FireMode.SLOW_FIRE:
			config = {"max_speed": 15.0, "min_speed": 15.0}  # Reduced from 20.0
		FireMode.FAST_FIRE:
			config = {"max_speed": 40.0, "min_speed": 15.0, "pulse_frequency": 4.0}  # Reduced from 80.0/30.0
		FireMode.HEAVY_BLAST:
			config = {}  # Hitscan needs no config
		FireMode.TRIPLE_SHOT:
			config = {"max_speed": 35.0, "min_speed": 8.0}  # Reduced from 70.0/15.0
		FireMode.AUTO_CHARGE:
			config = {"max_speed": 45.0, "min_speed": 12.0, "deceleration_rate": 22.0}  # Reduced from 90.0/25.0/45.0
	
	return config

# === PUBLIC API ===
func get_current_state() -> State:
	return current_state

func get_current_fire_mode() -> FireMode:
	return current_fire_mode

func get_charge_level() -> float:
	return charge_level

func is_charging() -> bool:
	return current_state == State.CHARGING

func is_charged() -> bool:
	return current_state == State.CHARGED

func is_firing() -> bool:
	return current_state == State.FIRING

func force_stop_charging():
	if current_state in [State.CHARGING, State.CHARGED]:
		_change_state(State.IDLE)

# === SPREAD SYSTEM API ===
func set_spread_for_mode(mode: FireMode, spread_degrees: float):
	"""Set spread value for a specific fire mode at runtime."""
	match mode:
		FireMode.RAPID_FIRE:
			rapid_fire_spread = spread_degrees
		FireMode.CHARGE_BLAST:
			charge_blast_spread = spread_degrees
		FireMode.DASH_ATTACK:
			dash_attack_spread = spread_degrees
		FireMode.JUMP_BURST:
			jump_burst_spread = spread_degrees
		FireMode.SLOW_FIRE:
			slow_fire_spread = spread_degrees
		FireMode.FAST_FIRE:
			fast_fire_spread = spread_degrees
		FireMode.HEAVY_BLAST:
			heavy_blast_spread = spread_degrees
		FireMode.TRIPLE_SHOT:
			triple_shot_spread = spread_degrees
		FireMode.AUTO_CHARGE:
			auto_charge_spread = spread_degrees

func get_all_spread_settings() -> Dictionary:
	"""Get all spread settings for debugging/configuration."""
	return {
		"rapid_fire": rapid_fire_spread,
		"charge_blast": charge_blast_spread,
		"dash_attack": dash_attack_spread,
		"jump_burst": jump_burst_spread,
		"slow_fire": slow_fire_spread,
		"fast_fire": fast_fire_spread,
		"heavy_blast": heavy_blast_spread,
		"triple_shot": triple_shot_spread,
		"auto_charge": auto_charge_spread
	}

func print_spread_settings():
	"""Debug function to print all current spread settings."""
	print("\n=== CURRENT SPREAD SETTINGS ===")
	var settings = get_all_spread_settings()
	for mode_name in settings:
		print(mode_name, ": ", "%.1f" % settings[mode_name], "°")
	print("================================\n")

# === RECOIL SYSTEM ===
func _update_recoil(delta: float):
	"""Update recoil state - apply upward camera nudge that tapers off."""
	if not is_recoiling:
		return
	
	# Count down recoil timer
	recoil_timer -= delta
	
	# Stop recoiling when timer expires
	if recoil_timer <= 0.0:
		is_recoiling = false
		return
	
	# Calculate recoil strength that tapers off over time (exponential decay)
	var recoil_duration = get_current_recoil_duration()
	var time_progress = (recoil_duration - recoil_timer) / recoil_duration  # 0.0 to 1.0
	var decay_factor = exp(-time_progress * 3.0)  # Adjust 3.0 to control decay rate
	var current_recoil_strength = get_current_recoil() * decay_factor
	
	# Apply upward camera nudge (only vertical recoil)
	var recoil_push_degrees = current_recoil_strength * delta * 60.0  # Scale by framerate
	
	# Update both the camera rotation AND the camera script's internal rotation tracking
	camera.rotation.x += deg_to_rad(recoil_push_degrees)  # Push camera up
	if camera.has_method("add_recoil_offset"):
		camera.add_recoil_offset(recoil_push_degrees)  # Update camera script's internal tracking

func _apply_recoil():
	"""Start recoil state and set timer."""
	var base_recoil = get_current_recoil()
	if base_recoil <= 0.0:
		return
	
	# Start recoiling and set timer
	is_recoiling = true
	recoil_timer = get_current_recoil_duration()
	
	# Add slight randomness to initial recoil kick
	var random_factor = 1.0 + (randf() - 0.5) * recoil_randomness
	var initial_kick_degrees = base_recoil * random_factor * 0.3  # Small immediate kick
	
	# Apply initial kick to both camera rotation and internal tracking
	camera.rotation.x += deg_to_rad(initial_kick_degrees)
	if camera.has_method("add_recoil_offset"):
		camera.add_recoil_offset(initial_kick_degrees)  # Update camera script's internal tracking
	
	if debug_recoil:
		print("Started recoil - Base: ", base_recoil, "° Duration: ", get_current_recoil_duration(), "s")

# === RECOIL SYSTEM API ===
func set_recoil_for_mode(mode: FireMode, recoil_degrees: float):
	"""Set recoil value for a specific fire mode at runtime."""
	match mode:
		FireMode.RAPID_FIRE:
			rapid_fire_recoil = recoil_degrees
		FireMode.CHARGE_BLAST:
			charge_blast_recoil = recoil_degrees
		FireMode.DASH_ATTACK:
			dash_attack_recoil = recoil_degrees
		FireMode.JUMP_BURST:
			jump_burst_recoil = recoil_degrees
		FireMode.SLOW_FIRE:
			slow_fire_recoil = recoil_degrees
		FireMode.FAST_FIRE:
			fast_fire_recoil = recoil_degrees
		FireMode.HEAVY_BLAST:
			heavy_blast_recoil = recoil_degrees
		FireMode.TRIPLE_SHOT:
			triple_shot_recoil = recoil_degrees
		FireMode.AUTO_CHARGE:
			auto_charge_recoil = recoil_degrees

func get_all_recoil_settings() -> Dictionary:
	"""Get all recoil settings for debugging/configuration."""
	return {
		"rapid_fire": rapid_fire_recoil,
		"charge_blast": charge_blast_recoil,
		"dash_attack": dash_attack_recoil,
		"jump_burst": jump_burst_recoil,
		"slow_fire": slow_fire_recoil,
		"fast_fire": fast_fire_recoil,
		"heavy_blast": heavy_blast_recoil,
		"triple_shot": triple_shot_recoil,
		"auto_charge": auto_charge_recoil
	}

func print_recoil_settings():
	"""Debug function to print all current recoil settings."""
	print("\n=== CURRENT RECOIL SETTINGS ===")
	var settings = get_all_recoil_settings()
	for mode_name in settings:
		print(mode_name, ": ", "%.1f" % settings[mode_name], "°")
	print("Randomness: ", "%.1f" % recoil_randomness)
	print("================================\n")

# === AMMO MANAGEMENT ===

func pickup_bullet():
	"""Called by player when a bullet is picked up."""
	if current_ammo >= max_ammo:
		return false
	
	var was_empty = (current_ammo == 0)
	current_ammo += 1
	ammo_changed.emit(current_ammo, max_ammo)
	
	# Play bullet pickup SFX
	AudioManager.play_bullet_pickup()
	
	if debug_ammo:
		print("Bullet picked up! Ammo: ", current_ammo, "/", max_ammo)
	
	# If we were empty and now have ammo, prepare a bullet
	if was_empty and not prepared_bullet:
		if debug_ammo:
			print("Was empty, preparing first bullet")
		_prepare_next_bullet()
	
	return true

func get_current_ammo() -> int:
	"""Get current ammo count."""
	return current_ammo

func get_max_ammo() -> int:
	"""Get maximum ammo capacity."""
	return max_ammo

func add_ammo(amount: int):
	"""Add ammo (used for pickups or cheats)."""
	current_ammo = min(max_ammo, current_ammo + amount)
	ammo_changed.emit(current_ammo, max_ammo)

# === FIRING VELOCITY EFFECTS ===

func _apply_firing_velocity_loss():
	"""Reduce player velocity when firing to create brief time flow moments."""
	if velocity_loss_on_firing <= 0.0:
		return  # No velocity loss configured
	
	# Get player reference
	if not player or not is_instance_valid(player):
		return
	
	# Apply velocity reduction (clamp to prevent negative values)
	var velocity_multiplier = 1.0 - clamp(velocity_loss_on_firing, 0.0, 1.0)
	var old_velocity = player.velocity
	var old_movement_intent = player.movement_intent
	
	# Reduce horizontal velocity (preserve vertical for jumping/gravity)
	player.velocity.x *= velocity_multiplier
	player.velocity.z *= velocity_multiplier
	
	# CRITICAL: Also reduce movement_intent which drives the time system
	player.movement_intent *= velocity_multiplier
	
	if debug_firing:
		print("Firing velocity loss:")
		print("  Velocity: ", old_velocity, " -> ", player.velocity)
		print("  Movement intent: ", old_movement_intent, " -> ", player.movement_intent)
		print("  Reduction: ", velocity_loss_on_firing * 100, "%")

# === GUN EQUIP/UNEQUIP SYSTEM ===

func equip_gun():
	"""Equip the gun with a simple animation."""
	if is_gun_equipped or equip_animation_active:
		return
	
	if debug_equipment:
		print("Equipping gun...")
	equip_animation_active = true
	is_gun_equipped = true
	
	# Make gun visible
	visible = true
	
	# Start small and animate to normal size
	scale = Vector3.ZERO
	
	# [[memory:6549429]] User prefers manual animations over tweens
	# Simple scale animation without using Godot's tween system
	_start_equip_animation()
	
	# Prepare the first bullet once equipped
	call_deferred("_prepare_next_bullet")

func unequip_gun():
	"""Unequip the gun (hide it)."""
	if debug_equipment:
		print("Unequipping gun...")
	is_gun_equipped = false
	equip_animation_active = false
	visible = false
	scale = Vector3.ONE
	
	# Stop any ongoing animations
	if prepared_bullet:
		prepared_bullet.queue_free()
		prepared_bullet = null

func _start_equip_animation():
	"""Start the equip animation using simple delta-based timer."""
	# Simple animation data with just what we need
	set_meta("equip_animation", {
		"elapsed": 0.0,
		"duration": equip_animation_duration,
		"bounce_factor": equip_animation_bounce_factor
	})

func _update_equip_animation(delta: float):
	"""Update the equip animation using normal delta time (ignores time scale)."""
	if not has_meta("equip_animation"):
		return false
	
	var animation_data = get_meta("equip_animation")
	var elapsed = animation_data.get("elapsed", 0.0)
	var duration = animation_data.get("duration", equip_animation_duration)
	var bounce_factor = animation_data.get("bounce_factor", equip_animation_bounce_factor)
	
	# Use raw delta time - ignore time manager for consistent animation speed
	elapsed += delta
	animation_data["elapsed"] = elapsed
	
	var progress = elapsed / duration
	
	if progress >= 1.0:
		# Animation complete
		scale = Vector3.ONE
		equip_animation_active = false
		remove_meta("equip_animation")
		if debug_equipment:
			print("Gun equip animation complete")
		return true
	
	# Calculate bouncy scale
	var scale_value: float
	if progress < equip_grow_phase_ratio:
		# Growing phase with bounce
		var bounce_progress = progress / equip_grow_phase_ratio
		scale_value = bounce_progress * bounce_factor
	else:
		# Settling phase
		var settle_progress = (progress - equip_grow_phase_ratio) / equip_settle_phase_ratio
		scale_value = bounce_factor - (bounce_factor - 1.0) * settle_progress
	
	scale = Vector3.ONE * scale_value
	return false

func is_equipped() -> bool:
	"""Check if the gun is currently equipped."""
	return is_gun_equipped

# === WALL RIPPLE EFFECTS ===

func _create_wall_ripple(impact_position: Vector3, surface_normal: Vector3):
	"""Create wall ripple effect at impact position."""
	if not wall_ripple_scene:
		if debug_firing:
			print("WARNING: No wall ripple scene assigned")
		return
	
	# Instantiate the ripple effect
	var ripple = wall_ripple_scene.instantiate()
	get_tree().current_scene.add_child(ripple)
	
	# Setup the ripple position and orientation
	if ripple.has_method("setup_ripple"):
		ripple.setup_ripple(impact_position, surface_normal)
	else:
		# Fallback setup
		ripple.global_position = impact_position
	
	if debug_firing:
		print("Wall ripple created at: ", impact_position, " with normal: ", surface_normal)

# === GUN TYPE AND SFX SYSTEM ===

func set_gun_type(gun_type: int):
	"""Set the current gun type (called by GunPickup)."""
	current_gun_type = gun_type
	_load_gun_data(gun_type)
	_apply_gun_properties()
	if debug_equipment:
		print("Gun type set to: ", _get_gun_type_name())

func _load_gun_data(gun_type: int):
	"""Load the GunData resource for the specified gun type."""
	if gun_type < 0 or gun_type >= gun_data_resources.size():
		print("ERROR: Invalid gun type: ", gun_type)
		return
	
	current_gun_data = gun_data_resources[gun_type]
	if debug_equipment:
		print("Loaded gun data: ", current_gun_data.gun_name)

func _initialize_gun_data_resources():
	"""Initialize the gun data resources array with all gun types."""
	if gun_data_resources.is_empty():
		# Load gun data resources
		gun_data_resources.append(load("res://assets/guns/pistol_data.tres"))
		gun_data_resources.append(load("res://assets/guns/rifle_data.tres"))
		gun_data_resources.append(load("res://assets/guns/shotgun_data.tres"))
		gun_data_resources.append(load("res://assets/guns/sniper_data.tres"))
		gun_data_resources.append(load("res://assets/guns/rocket_launcher_data.tres"))
		
		if debug_equipment:
			print("Loaded gun data resources: ", gun_data_resources.size(), " guns")

func _apply_gun_properties():
	"""Apply the current gun data properties to the gun system."""
	if not current_gun_data:
		print("ERROR: No gun data loaded!")
		return
	
	# Apply gun-specific properties
	max_ammo = current_gun_data.ammo_capacity
	current_ammo = max_ammo  # Start with full ammo
	
	# Update fire rate based on gun type
	rapid_fire_rate_start = current_gun_data.fire_rate
	rapid_fire_rate_min = current_gun_data.fire_rate
	
	# Update damage values
	rapid_fire_damage = current_gun_data.damage
	
	# Update spread
	rapid_fire_spread = current_gun_data.spread_angle
	
	# Update knockback
	rapid_fire_knockback = current_gun_data.knockback_force
	
	# Emit ammo changed signal so UI updates with correct values
	ammo_changed.emit(current_ammo, max_ammo)
	
	if debug_equipment:
		print("Applied gun properties - Ammo: ", max_ammo, " Fire Rate: ", rapid_fire_rate_start, " Damage: ", rapid_fire_damage)

func _get_gun_type_name() -> String:
	"""Get the string name for the current gun type."""
	if current_gun_data:
		return current_gun_data.sfx_name
	else:
		# Fallback to hardcoded names if no gun data loaded
		match current_gun_type:
			0: return "pistol"
			1: return "rifle"
			2: return "shotgun"
			3: return "sniper"
			4: return "rocket_launcher"
			_: return "pistol"

func _play_gunshot_sfx():
	"""Play the appropriate gunshot sound for the current gun type."""
	var gun_name = _get_gun_type_name()
	AudioManager.play_gunshot(gun_name)
