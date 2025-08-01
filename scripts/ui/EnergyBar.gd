extends ProgressBar

# === ENERGY BAR UI ===
# Displays player's time energy level with visual feedback

# === CONFIGURATION ===
@export_group("Visual Settings")
@export var normal_color: Color = Color.CYAN
@export var low_energy_color: Color = Color.YELLOW
@export var critical_energy_color: Color = Color.RED
@export var forced_recharge_color: Color = Color.PURPLE
@export var depleted_color: Color = Color.DARK_RED

@export_group("Thresholds")
@export var low_energy_threshold: float = 50.0     # Yellow warning at 50%
@export var critical_energy_threshold: float = 25.0 # Red warning at 25% (matches movement unlock threshold)

@export_group("Effects")
@export var enable_pulse_effect: bool = true       # Pulse when energy is low
@export var enable_flash_effect: bool = true       # Flash when energy depleted
@export var pulse_speed: float = 3.0               # Speed of pulsing effect
@export var flash_speed: float = 8.0               # Speed of flashing effect

# === STATE ===
var time_energy_manager: Node = null
var current_energy_percentage: float = 100.0
var is_forced_recharging: bool = false
var is_energy_depleted: bool = false
var is_movement_locked: bool = false

# Effect state
var pulse_time: float = 0.0
var is_pulsing: bool = false
var is_flashing: bool = false

# Original style for restoration
var original_stylebox: StyleBox = null

func _ready():
	# Store original style
	original_stylebox = get_theme_stylebox("fill").duplicate()
	
	# Connect to TimeEnergyManager
	time_energy_manager = get_node("/root/TimeEnergyManager")
	if time_energy_manager:
		print("EnergyBar connected to TimeEnergyManager")
		
		# Connect to all relevant signals
		time_energy_manager.energy_changed.connect(_on_energy_changed)
		time_energy_manager.energy_depleted.connect(_on_energy_depleted)
		time_energy_manager.energy_restored.connect(_on_energy_restored)
		time_energy_manager.forced_recharge_started.connect(_on_forced_recharge_started)
		time_energy_manager.forced_recharge_ended.connect(_on_forced_recharge_ended)
		time_energy_manager.movement_lock_started.connect(_on_movement_locked)
		time_energy_manager.movement_unlocked.connect(_on_movement_unlocked)
		
		# Initialize with current values
		_update_display()
	else:
		print("ERROR: EnergyBar cannot find TimeEnergyManager!")
		# Set error state
		value = 0
		_set_bar_color(Color.MAGENTA)  # Magenta indicates connection error

func _process(delta):
	if enable_pulse_effect and is_pulsing:
		_update_pulse_effect(delta)
	
	if enable_flash_effect and is_flashing:
		_update_flash_effect(delta)

func _update_pulse_effect(delta):
	"""Create pulsing effect for low energy warning."""
	pulse_time += delta * pulse_speed
	
	# Create a pulsing alpha between 0.6 and 1.0
	var alpha = 0.6 + 0.4 * (sin(pulse_time) + 1.0) / 2.0
	var current_color = _get_current_base_color()
	current_color.a = alpha
	_set_bar_color(current_color)

func _update_flash_effect(delta):
	"""Create flashing effect for energy depletion."""
	pulse_time += delta * flash_speed
	
	# Flash between depleted color and dark
	var flash_intensity = (sin(pulse_time) + 1.0) / 2.0
	var flash_color = depleted_color.lerp(Color.BLACK, 1.0 - flash_intensity)
	_set_bar_color(flash_color)

func _get_current_base_color() -> Color:
	"""Get the base color for current energy state (without effects)."""
	if is_forced_recharging:
		return forced_recharge_color
	elif is_energy_depleted:
		return depleted_color
	elif current_energy_percentage <= critical_energy_threshold:
		return critical_energy_color
	elif current_energy_percentage <= low_energy_threshold:
		return low_energy_color
	else:
		return normal_color

func _update_display():
	"""Update the progress bar display based on current state."""
	if not time_energy_manager:
		return
	
	# Update bar value
	value = current_energy_percentage
	
	# Determine color and effects
	var should_pulse = false
	var should_flash = false
	var bar_color = _get_current_base_color()
	
	# Determine if effects should be active
	if is_energy_depleted and enable_flash_effect:
		should_flash = true
	elif (current_energy_percentage <= critical_energy_threshold or is_forced_recharging) and enable_pulse_effect:
		should_pulse = true
	
	# Update effects
	if should_flash != is_flashing:
		is_flashing = should_flash
		pulse_time = 0.0
	
	if should_pulse != is_pulsing:
		is_pulsing = should_pulse
		pulse_time = 0.0
	
	# Set color if not using effects
	if not is_pulsing and not is_flashing:
		_set_bar_color(bar_color)

func _set_bar_color(color: Color):
	"""Set the progress bar fill color."""
	var stylebox = get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	if stylebox:
		stylebox.bg_color = color
		add_theme_stylebox_override("fill", stylebox)

# === SIGNAL HANDLERS ===

func _on_energy_changed(current: float, max_energy: float, percentage: float):
	"""Called when energy level changes."""
	current_energy_percentage = percentage
	_update_display()
	
	# Debug info (can remove later)
	if percentage <= 10.0:
		print("EnergyBar: CRITICAL ENERGY - ", "%.1f" % percentage, "%")

func _on_energy_depleted():
	"""Called when energy is completely depleted."""
	print("EnergyBar: Energy depleted - activating flash effect")
	is_energy_depleted = true
	_update_display()

func _on_energy_restored():
	"""Called when energy is restored after depletion."""
	print("EnergyBar: Energy restored - deactivating flash effect")
	is_energy_depleted = false
	_update_display()

func _on_forced_recharge_started():
	"""Called when forced recharge begins."""
	print("EnergyBar: Forced recharge started")
	is_forced_recharging = true
	_update_display()

func _on_forced_recharge_ended():
	"""Called when forced recharge ends."""
	print("EnergyBar: Forced recharge ended")
	is_forced_recharging = false
	_update_display()

func _on_movement_locked():
	"""Called when movement is locked."""
	print("EnergyBar: Movement locked")
	is_movement_locked = true
	# Could add additional visual feedback here if desired

func _on_movement_unlocked():
	"""Called when movement is unlocked."""
	print("EnergyBar: Movement unlocked")
	is_movement_locked = false
	# Could add additional visual feedback here if desired

# === PUBLIC API ===

func get_current_energy_percentage() -> float:
	"""Get the current energy percentage being displayed."""
	return current_energy_percentage

func set_color_scheme(normal: Color, low: Color, critical: Color, forced: Color, depleted: Color):
	"""Update the color scheme at runtime."""
	normal_color = normal
	low_energy_color = low
	critical_energy_color = critical
	forced_recharge_color = forced
	depleted_color = depleted
	_update_display()

func set_thresholds(low_threshold: float, critical_threshold: float):
	"""Update the warning thresholds at runtime."""
	low_energy_threshold = low_threshold
	critical_energy_threshold = critical_threshold
	_update_display()

func enable_effects(pulse: bool, flash: bool):
	"""Enable or disable visual effects."""
	enable_pulse_effect = pulse
	enable_flash_effect = flash
	
	# Stop current effects if disabled
	if not pulse:
		is_pulsing = false
	if not flash:
		is_flashing = false
	
	_update_display()

# === DEBUG FUNCTIONS ===

func print_status():
	"""Debug function to print current UI state."""
	print("\n=== ENERGY BAR STATUS ===")
	print("Energy: ", "%.1f" % current_energy_percentage, "%")
	print("Forced recharge: ", is_forced_recharging)
	print("Energy depleted: ", is_energy_depleted)
	print("Movement locked: ", is_movement_locked)
	print("Pulsing: ", is_pulsing)
	print("Flashing: ", is_flashing)
	print("Current color: ", _get_current_base_color())
	print("========================\n")
