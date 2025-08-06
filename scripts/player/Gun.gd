extends Node3D

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
@export var fast_fire_shotgun_spread: float = 0.0      # Unused
@export var heavy_blast_shotgun_spread: float = 0.0    # Unused
@export var triple_shot_shotgun_spread: float = 15.0   # Unused
@export var auto_charge_shotgun_spread: float = 0.0    # Unused

@export_group("Recoil Settings")
@export var recoil_randomness: float = 0.25  # Random variation in recoil direction

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

# === RECOIL STATE ===
var is_recoiling: bool = false
var recoil_timer: float = 0.0

# === TIME SYSTEM INTEGRATION ===
@export var affect_muzzle_flash: bool = true  # Whether muzzle flash should be time-scaled
@export var affect_visual_effects: bool = true  # Whether visual effects should be time-scaled
var time_manager: Node = null
var time_energy_manager: Node = null

# === COMPONENTS ===
@onready var bullet_scene = preload("res://scenes/bullet.tscn")
@onready var camera = get_parent()  # Gun is now child of camera
@onready var player = camera.get_parent()  # Player is camera's parent
@onready var muzzle_marker = $Marker3D
@onready var muzzle_flash: MeshInstance3D = create_muzzle_flash_node()

# === BULLET PRE-SPAWN SYSTEM ===
var prepared_bullet: RigidBody3D = null  # Bullet that is spawned ahead of time and ready to fire

# === SIGNALS ===
signal state_changed(new_state: State)
signal fire_mode_changed(new_mode: FireMode)
signal charge_level_changed(level: float)
signal fired_shot(damage: int)

func _process(delta):
	_update_recoil(delta)

func _ready():
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
		print("Gun connected to TimeManager for visual effects")
	
	# Connect to time energy manager
	time_energy_manager = get_node("/root/TimeEnergyManager")
	if time_energy_manager:
		print("Gun connected to TimeEnergyManager")
	else:
		print("WARNING: Gun can't find TimeEnergyManager!")
	
	# Set initial state
	_change_state(State.IDLE)
	
	# Apply auto-positioning if enabled
	if auto_position:
		position = screen_position
	
	# Prepare the first bullet
	_prepare_next_bullet()
	
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
	rapid_fire_current_rate = 0.15  # Fast fire rate for assault rifle
	_change_state(State.FIRING)

func _fire_shotgun_blast():
	# Shotgun: single blast with multiple pellets
	_fire_bullet(dash_attack_damage)
	fired_shot.emit(dash_attack_damage)
	print("Shotgun blast! Damage: ", dash_attack_damage)

func _start_slow_fire():
	# Rocket launcher: single shot with high damage
	_fire_bullet(slow_fire_damage)
	fired_shot.emit(slow_fire_damage)
	print("Rocket fired! Damage: ", slow_fire_damage)

func _start_fast_fire():
	rapid_fire_current_rate = 0.05  # Much faster than normal
	_change_state(State.FIRING)

func _fire_heavy_blast():
	_fire_bullet(300)  # Heavy damage single shot
	fired_shot.emit(300)
	print("Heavy blast! Damage: 300")

func _fire_triple_shot():
	# Now handled by shotgun system - this is just for backward compatibility
	_fire_bullet(rapid_fire_damage)
	fired_shot.emit(rapid_fire_damage)
	print("Shotgun blast!")

func _start_auto_charge():
	_change_state(State.CHARGING)

# === DEBUG FIRING (for movement-based mode) ===
func _start_debug_firing():
	print("Debug firing started")
	_change_state(State.FIRING)

func _stop_debug_firing():
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
			print("*** GUN FULLY CHARGED! Release to fire! ***")

func _fire_charged_blast():
	# We only call this when fully charged, so no need to check minimum
	var damage = int(lerp(charged_blast_damage_min, charged_blast_damage_max, charge_level))
	_fire_bullet(damage)
	fired_shot.emit(damage)
	
	print("Charged blast fired! Damage: ", damage, " (charge: ", "%.1f" % (charge_level * 100), "%)")
	charge_level = 0.0
	charge_level_changed.emit(0.0)

# === SPECIAL ATTACKS ===
func _fire_dash_attack():
	_fire_bullet(dash_attack_damage)
	fired_shot.emit(dash_attack_damage)
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
	# Instantiate a bullet ahead of time so it's ready when we need to fire
	prepared_bullet = bullet_scene.instantiate()
	# Add directly to main scene since bullets are now scene children
	get_tree().current_scene.add_child.call_deferred(prepared_bullet)
	
	# Setup the bullet after it's added to the scene
	_setup_prepared_bullet.call_deferred()

func _setup_prepared_bullet():
	if not prepared_bullet:
		return
		
	# Give the bullet reference to gun and muzzle so it can track position
	if prepared_bullet.has_method("set_gun_reference"):
		prepared_bullet.set_gun_reference(self, muzzle_marker)
	
	# Position the bullet at the muzzle (it will continue tracking via script)
	prepared_bullet.global_position = get_muzzle_position()
	
	# Keep the bullet inactive until fired
	if prepared_bullet is RigidBody3D:
		prepared_bullet.freeze = true
		prepared_bullet.sleeping = true
		prepared_bullet.linear_velocity = Vector3.ZERO
		prepared_bullet.angular_velocity = Vector3.ZERO

func _fire_bullet(damage: int):
	# Check if firing is allowed by energy system
	if time_energy_manager and not time_energy_manager.can_fire():
		print("Firing blocked - insufficient energy or in forced recharge")
		return
	
	# Drain energy for firing
	if time_energy_manager:
		var energy_drained = time_energy_manager.drain_energy_for_firing()
		if not energy_drained:
			print("Firing blocked - energy drain failed")
			return
	
	var travel_type = get_current_travel_type()
	
	# Show muzzle flash for all weapon types
	_show_muzzle_flash()
	
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
	
	print("FIRING HITSCAN - Type: ", travel_type, " Damage: ", damage)
	
	# For delayed hitscan, add a brief delay
	if travel_type == 7:  # DELAYED_HITSCAN
		await get_tree().create_timer(0.15).timeout
	
	# Perform raycast
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		spawn_position,
		spawn_position + fire_direction * 1000.0  # 1000 unit range
	)
	
	# Set collision mask - hit Environment (4) + Enemy (128) = 132
	query.collision_mask = 132
	query.exclude = [get_tree().get_first_node_in_group("player")]  # Don't hit player
	
	var result = space_state.intersect_ray(query)
	var impact_position: Vector3
	
	if result:
		print("Hitscan hit: ", result.collider.name, " at ", result.position)
		impact_position = result.position
		
		# Deal direct damage if we hit an enemy
		if result.collider.has_method("take_damage"):
			result.collider.take_damage(damage)
		
		# Create visual effects
		_create_hitscan_effects(spawn_position, result.position)
	else:
		print("Hitscan missed")
		impact_position = spawn_position + fire_direction * 1000.0
		# Create tracer to max range
		_create_hitscan_effects(spawn_position, impact_position)
	
	# Handle explosion if this weapon is explosive
	if is_current_mode_explosive():
		_create_explosion(impact_position)

func _fire_projectile(damage: int):
	"""Fire a projectile bullet."""
	var spawn_position = get_muzzle_position()
	var fire_direction = get_firing_direction()
	
	var bullet: RigidBody3D
	if prepared_bullet:
		bullet = prepared_bullet
		prepared_bullet = null
	else:
		# Fallback if no prepared bullet
		bullet = bullet_scene.instantiate()
		get_tree().current_scene.add_child(bullet)
		if bullet.has_method("set_gun_reference"):
			bullet.set_gun_reference(self, muzzle_marker)
	
	# Bullet is already in scene root, just activate physics
	bullet.global_position = spawn_position
	bullet.freeze = false
	bullet.sleeping = false
	
	# Configure bullet collision
	bullet.collision_layer = 2  # Bullets layer  
	bullet.collision_mask = 133  # Environment + Enemy + Player
	
	# Ensure contact monitoring is enabled for collision detection
	bullet.contact_monitor = true
	bullet.max_contacts_reported = 10
	
	# Pass damage value if bullet script supports it
	if bullet.has_method("set_damage"):
		bullet.set_damage(damage)
	
	# Pass explosion properties if this weapon is explosive
	if is_current_mode_explosive() and bullet.has_method("set_explosion_properties"):
		bullet.set_explosion_properties(get_current_explosion_radius(), get_current_explosion_damage())
	
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

func create_muzzle_flash_node() -> MeshInstance3D:
	"""Create and setup the muzzle flash node attached to the gun."""
	var flash = MeshInstance3D.new()
	flash.name = "MuzzleFlash"
	
	# Create sphere mesh
	var sphere = SphereMesh.new()
	sphere.radius = 0.3
	sphere.height = 0.6
	flash.mesh = sphere
	
	# Create bright yellow material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.YELLOW
	material.emission_enabled = true
	material.emission = Color.YELLOW
	material.emission_energy = 5.0
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
	
	# Quick scale animation
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	
	# Flash grows then shrinks
	muzzle_flash.scale = Vector3(0.5, 0.5, 0.5)
	tween.tween_property(muzzle_flash, "scale", Vector3(1.2, 1.2, 1.2), 0.05)
	tween.tween_property(muzzle_flash, "scale", Vector3.ZERO, 0.15).set_delay(0.05)
	
	# Hide after animation
	tween.tween_callback(func(): muzzle_flash.visible = false).set_delay(0.2)

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
	cylinder.top_radius = 0.02
	cylinder.bottom_radius = 0.02
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
	
	# Animate fadeout proportional to length
	_animate_hitscan_tracer_fadeout(tracer, line_length, end_pos, line_direction)

func _create_impact_effect(pos: Vector3):
	"""Create impact effect at hit location."""
	var impact = MeshInstance3D.new()
	get_tree().current_scene.add_child(impact)
	
	# Create small sphere for impact
	var sphere = SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	impact.mesh = sphere
	
	# Position at impact point
	impact.global_position = pos
	
	# Create bright orange material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.ORANGE
	material.emission_enabled = true
	material.emission = Color.ORANGE
	material.emission_energy = 4.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	impact.material_override = material
	
	# Animate fadeout
	_animate_impact_fadeout(impact)

func _animate_hitscan_tracer_fadeout(tracer: MeshInstance3D, tracer_length: float, impact_end: Vector3, line_dir: Vector3):
	"""Animate hitscan tracer fade out with consistent shrink rate."""
	if not tracer or not is_instance_valid(tracer):
		return
	
	# Calculate duration based on length for consistent shrink rate
	# Shrink rate: 400 units per second (adjust this value to taste)
	var shrink_rate = 400.0  # units per second

	
	var duration = tracer_length / 16.0
	
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
		
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	
	# Scale up then down
	tween.tween_property(impact, "scale", Vector3(2.0, 2.0, 2.0), 0.1)
	tween.tween_property(impact, "scale", Vector3.ZERO, 0.4).set_delay(0.1)
	
	# Remove after animation
	tween.tween_callback(func(): if is_instance_valid(impact): impact.queue_free()).set_delay(0.5)
	_prepare_next_bullet()

# === SHOTGUN SYSTEM ===
func _fire_shotgun(damage: int, travel_type: int):
	"""Fire multiple pellets simultaneously in a spread pattern."""
	var pellet_count = get_current_pellet_count()
	var shotgun_spread = get_current_shotgun_spread()
	var pellet_damage = max(1, damage / pellet_count)  # Distribute damage across pellets
	
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
		await get_tree().create_timer(0.15).timeout
	
	# Perform raycast
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(
		spawn_position,
		spawn_position + direction * 1000.0  # 1000 unit range
	)
	
	# Set collision mask - hit Environment (4) + Enemy (128) = 132
	query.collision_mask = 132
	query.exclude = [get_tree().get_first_node_in_group("player")]  # Don't hit player
	
	var result = space_state.intersect_ray(query)
	var impact_position: Vector3
	
	if result:
		impact_position = result.position
		
		# Deal direct damage if we hit an enemy
		if result.collider.has_method("take_damage"):
			result.collider.take_damage(damage)
		
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
	var bullet = bullet_scene.instantiate()
	get_tree().current_scene.add_child(bullet)
	
	# Setup bullet
	bullet.global_position = spawn_position
	bullet.freeze = false
	bullet.sleeping = false
	
	# Configure bullet collision
	bullet.collision_layer = 2  # Bullets layer  
	bullet.collision_mask = 133  # Environment + Enemy + Player
	
	# Ensure contact monitoring is enabled for collision detection
	bullet.contact_monitor = true
	bullet.max_contacts_reported = 10
	
	# Pass damage value
	if bullet.has_method("set_damage"):
		bullet.set_damage(damage)
	
	# Pass explosion properties if this weapon is explosive
	if is_current_mode_explosive() and bullet.has_method("set_explosion_properties"):
		bullet.set_explosion_properties(get_current_explosion_radius(), get_current_explosion_damage())
	
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
	var impact = MeshInstance3D.new()
	get_tree().current_scene.add_child(impact)
	
	# Create small sphere for impact (smaller than normal impacts)
	var sphere = SphereMesh.new()
	sphere.radius = 0.1  # Smaller than normal 0.2
	sphere.height = 0.2  # Smaller than normal 0.4
	impact.mesh = sphere
	
	# Position at impact point
	impact.global_position = position
	
	# Create bright orange material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.ORANGE
	material.emission_enabled = true
	material.emission = Color.ORANGE
	material.emission_energy = 2.0  # Less bright than normal impacts
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	impact.material_override = material
	
	# Quick fadeout
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	
	# Scale up then down (faster than normal)
	tween.tween_property(impact, "scale", Vector3(1.5, 1.5, 1.5), 0.05)
	tween.tween_property(impact, "scale", Vector3.ZERO, 0.2).set_delay(0.05)
	
	# Remove after animation
	tween.tween_callback(func(): if is_instance_valid(impact): impact.queue_free()).set_delay(0.3)

# === EXPLOSION SYSTEM ===
func _create_explosion(position: Vector3):
	"""Create explosion effect and apply area damage."""
	var explosion_radius = get_current_explosion_radius()
	var explosion_damage = get_current_explosion_damage()
	
	if explosion_radius <= 0.0:
		return
	
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
			
			print("Explosion damaged ", enemy.name, " for ", final_damage, " damage (distance: ", "%.1f" % distance, ")")
			enemy.take_damage(final_damage)

func _create_explosion_visual(position: Vector3, radius: float):
	"""Create visual explosion effect at position."""
	var explosion = MeshInstance3D.new()
	get_tree().current_scene.add_child(explosion)
	
	# Create sphere mesh for explosion
	var sphere = SphereMesh.new()
	sphere.radius = radius * 0.3  # Start smaller
	sphere.height = radius * 0.6
	explosion.mesh = sphere
	explosion.global_position = position
	
	# Create bright explosion material
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.ORANGE_RED
	material.emission_enabled = true
	material.emission = Color.ORANGE_RED
	material.emission_energy = 5.0
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	explosion.material_override = material
	
	# Animate explosion
	_animate_explosion_effect(explosion, radius)

func _animate_explosion_effect(explosion: MeshInstance3D, max_radius: float):
	"""Animate explosion - rapid expansion then fade."""
	if not explosion or not is_instance_valid(explosion):
		return
	
	var tween = get_tree().create_tween()
	tween.set_parallel(true)
	
	# Rapid expansion
	explosion.scale = Vector3.ZERO
	tween.tween_property(explosion, "scale", Vector3.ONE, 0.2)
	
	# Color fade (from bright orange to dark red)
	var material = explosion.material_override as StandardMaterial3D
	if material:
		tween.tween_method(
			func(energy): material.emission_energy = energy,
			5.0, 0.0, 0.4
		).set_delay(0.1)
		tween.tween_property(material, "albedo_color", Color.DARK_RED, 0.4).set_delay(0.1)
	
	# Scale down and remove
	tween.tween_property(explosion, "scale", Vector3.ZERO, 0.3).set_delay(0.3)
	tween.tween_callback(func(): if is_instance_valid(explosion): explosion.queue_free()).set_delay(0.6)

func get_muzzle_position() -> Vector3:
	# Calculate exact world position of muzzle
	return muzzle_marker.global_position

func get_firing_direction(apply_spread: bool = true) -> Vector3:
	# Get camera's aim raycast for cursor accuracy
	var aim_raycast = camera.get_node_or_null("AimRayCast3D") as RayCast3D
	if not aim_raycast:
		print("WARNING: No AimRaycast found on camera! Falling back to camera forward direction.")
		return -camera.global_transform.basis.z.normalized()
	
	# Force raycast update to get current aim direction
	aim_raycast.force_raycast_update()
	
	# Always use a fixed focal point at focal_distance in the camera's aim direction
	var camera_direction = -camera.global_transform.basis.z.normalized()
	var focal_point = camera.global_position + (camera_direction * focal_distance)
	
	# If raycast hits something closer than focal distance, use that instead
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
	match current_fire_mode:
		FireMode.RAPID_FIRE:
			return rapid_fire_explosive
		FireMode.CHARGE_BLAST:
			return charge_blast_explosive
		FireMode.DASH_ATTACK:
			return dash_attack_explosive
		FireMode.JUMP_BURST:
			return jump_burst_explosive
		FireMode.SLOW_FIRE:
			return slow_fire_explosive
		FireMode.FAST_FIRE:
			return fast_fire_explosive
		FireMode.HEAVY_BLAST:
			return heavy_blast_explosive
		FireMode.TRIPLE_SHOT:
			return triple_shot_explosive
		FireMode.AUTO_CHARGE:
			return auto_charge_explosive
		_:
			return false

func get_current_explosion_radius() -> float:
	match current_fire_mode:
		FireMode.RAPID_FIRE:
			return rapid_fire_explosion_radius
		FireMode.CHARGE_BLAST:
			return charge_blast_explosion_radius
		FireMode.DASH_ATTACK:
			return dash_attack_explosion_radius
		FireMode.JUMP_BURST:
			return jump_burst_explosion_radius
		FireMode.SLOW_FIRE:
			return slow_fire_explosion_radius
		FireMode.FAST_FIRE:
			return fast_fire_explosion_radius
		FireMode.HEAVY_BLAST:
			return heavy_blast_explosion_radius
		FireMode.TRIPLE_SHOT:
			return triple_shot_explosion_radius
		FireMode.AUTO_CHARGE:
			return auto_charge_explosion_radius
		_:
			return 0.0

func get_current_explosion_damage() -> int:
	match current_fire_mode:
		FireMode.RAPID_FIRE:
			return rapid_fire_explosion_damage
		FireMode.CHARGE_BLAST:
			return charge_blast_explosion_damage
		FireMode.DASH_ATTACK:
			return dash_attack_explosion_damage
		FireMode.JUMP_BURST:
			return jump_burst_explosion_damage
		FireMode.SLOW_FIRE:
			return slow_fire_explosion_damage
		FireMode.FAST_FIRE:
			return fast_fire_explosion_damage
		FireMode.HEAVY_BLAST:
			return heavy_blast_explosion_damage
		FireMode.TRIPLE_SHOT:
			return triple_shot_explosion_damage
		FireMode.AUTO_CHARGE:
			return auto_charge_explosion_damage
		_:
			return 0

func is_current_mode_shotgun() -> bool:
	match current_fire_mode:
		FireMode.RAPID_FIRE:
			return rapid_fire_shotgun
		FireMode.CHARGE_BLAST:
			return charge_blast_shotgun
		FireMode.DASH_ATTACK:
			return dash_attack_shotgun
		FireMode.JUMP_BURST:
			return jump_burst_shotgun
		FireMode.SLOW_FIRE:
			return slow_fire_shotgun
		FireMode.FAST_FIRE:
			return fast_fire_shotgun
		FireMode.HEAVY_BLAST:
			return heavy_blast_shotgun
		FireMode.TRIPLE_SHOT:
			return triple_shot_shotgun
		FireMode.AUTO_CHARGE:
			return auto_charge_shotgun
		_:
			return false

func get_current_pellet_count() -> int:
	match current_fire_mode:
		FireMode.RAPID_FIRE:
			return rapid_fire_pellets
		FireMode.CHARGE_BLAST:
			return charge_blast_pellets
		FireMode.DASH_ATTACK:
			return dash_attack_pellets
		FireMode.JUMP_BURST:
			return jump_burst_pellets
		FireMode.SLOW_FIRE:
			return slow_fire_pellets
		FireMode.FAST_FIRE:
			return fast_fire_pellets
		FireMode.HEAVY_BLAST:
			return heavy_blast_pellets
		FireMode.TRIPLE_SHOT:
			return triple_shot_pellets
		FireMode.AUTO_CHARGE:
			return auto_charge_pellets
		_:
			return 1

func get_current_shotgun_spread() -> float:
	match current_fire_mode:
		FireMode.RAPID_FIRE:
			return rapid_fire_shotgun_spread
		FireMode.CHARGE_BLAST:
			return charge_blast_shotgun_spread
		FireMode.DASH_ATTACK:
			return dash_attack_shotgun_spread
		FireMode.JUMP_BURST:
			return jump_burst_shotgun_spread
		FireMode.SLOW_FIRE:
			return slow_fire_shotgun_spread
		FireMode.FAST_FIRE:
			return fast_fire_shotgun_spread
		FireMode.HEAVY_BLAST:
			return heavy_blast_shotgun_spread
		FireMode.TRIPLE_SHOT:
			return triple_shot_shotgun_spread
		FireMode.AUTO_CHARGE:
			return auto_charge_shotgun_spread
		_:
			return 0.0

func get_current_travel_type() -> int:
	match current_fire_mode:
		FireMode.RAPID_FIRE:
			return rapid_fire_travel
		FireMode.CHARGE_BLAST:
			return charge_blast_travel
		FireMode.DASH_ATTACK:
			return dash_attack_travel
		FireMode.JUMP_BURST:
			return jump_burst_travel
		FireMode.SLOW_FIRE:
			return slow_fire_travel
		FireMode.FAST_FIRE:
			return fast_fire_travel
		FireMode.HEAVY_BLAST:
			return heavy_blast_travel
		FireMode.TRIPLE_SHOT:
			return triple_shot_travel
		FireMode.AUTO_CHARGE:
			return auto_charge_travel
		_:
			return 2  # Default to CONSTANT_FAST

func get_travel_config_for_mode() -> Dictionary:
	"""Get travel configuration for current fire mode."""
	var config = {}
	
	match current_fire_mode:
		FireMode.RAPID_FIRE:
			config = {"max_speed": 50.0, "min_speed": 50.0}
		FireMode.CHARGE_BLAST:
			config = {}  # Hitscan needs no config
		FireMode.DASH_ATTACK:
			config = {"hitscan_delay": 0.15}  # Brief delay before instant travel
		FireMode.JUMP_BURST:
			config = {"max_speed": 60.0, "min_speed": 5.0, "acceleration_rate": 100.0}
		FireMode.SLOW_FIRE:
			config = {"max_speed": 20.0, "min_speed": 20.0}
		FireMode.FAST_FIRE:
			config = {"max_speed": 80.0, "min_speed": 30.0, "pulse_frequency": 4.0}
		FireMode.HEAVY_BLAST:
			config = {}  # Hitscan needs no config
		FireMode.TRIPLE_SHOT:
			config = {"max_speed": 70.0, "min_speed": 15.0}
		FireMode.AUTO_CHARGE:
			config = {"max_speed": 90.0, "min_speed": 25.0, "deceleration_rate": 45.0}
	
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
