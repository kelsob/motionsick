extends Node

# === TIME ENERGY SYSTEM ===
# Manages the player's time energy meter that controls movement and time manipulation

## === EXPORTED CONFIGURATION ===
@export_group("Energy Capacity")
## Maximum energy the player can have
@export var max_energy: float = 100.0
## Energy value to initialize with (typically max_energy)
@export var initial_energy: float = 100.0

@export_group("Energy Rates")
## Energy gained per second when idle
@export var charge_rate: float = 25.0
## Energy lost per second when moving (multiplied by movement intent)
@export var movement_drain_rate: float = 7.5
## Energy lost per shot fired
@export var firing_drain_amount: float = 2.5

@export_group("Thresholds")
## Energy threshold that triggers forced recharge (0.0 = only on complete depletion)
@export var forced_recharge_threshold: float = 0.0
## Energy percentage needed to unlock movement after depletion
@export var movement_unlock_threshold: float = 25.0
## Minimum energy required to fire weapons
@export var minimum_firing_energy: float = 0.0

@export_group("Movement Intent Detection")
## Minimum change in movement intent to trigger debug output
@export var movement_intent_debug_threshold: float = 0.1
## Clamp values for movement intent (min, max)
@export var movement_intent_min: float = 0.0
@export var movement_intent_max: float = 1.0

@export_group("Percentage Calculation")
## Multiplier to convert energy ratio to percentage (typically 100.0)
@export var percentage_multiplier: float = 100.0

@export_group("Debug Settings")
## Enable debug print statements for energy state changes
@export var debug_energy_changes: bool = true
## Enable debug print statements for movement state changes
@export var debug_movement_changes: bool = true
## Enable debug print statements for recharge state changes
@export var debug_recharge_changes: bool = true
## Enable debug print statements for firing events
@export var debug_firing_events: bool = true
## Enable debug print statements for configuration changes
@export var debug_config_changes: bool = true

## === RUNTIME STATE ===
# Current energy amount
var current_energy: float
# Forced recharge state
var is_forced_recharging: bool = false
# Movement lock state
var movement_locked: bool = false
# Movement tracking
var player_is_moving: bool = false
# Current movement intent (0.0 to 1.0 intensity)
var player_movement_intent: float = 0.0

# === SIGNALS ===
signal energy_changed(current: float, max: float, percentage: float)
signal energy_depleted()
signal energy_restored()
signal forced_recharge_started()
signal forced_recharge_ended()
signal movement_lock_started()
signal movement_unlocked()

func _ready():
	# Initialize energy to configured initial value
	current_energy = initial_energy
	
	# Add to time energy group for easy access
	add_to_group("time_energy_manager")
	
	if debug_energy_changes:
		print("TimeEnergyManager initialized - Max energy: ", max_energy, " | Initial energy: ", initial_energy)
	
	# Emit initial state
	_emit_energy_changed()

func _process(delta):
	_update_energy(delta)

func _update_energy(delta):
	var energy_change = 0.0
	
	# During forced recharge, always charge at full rate and reset movement intent
	if is_forced_recharging:
		energy_change += charge_rate * delta
		player_movement_intent = movement_intent_min  # Force movement intent to minimum during recharge
		player_is_moving = false
	else:
		# Normal energy processing when not in forced recharge
		if player_movement_intent > movement_intent_min:
			energy_change -= movement_drain_rate * player_movement_intent * delta
			player_is_moving = true
		else:
			# Charge energy when idle
			energy_change += charge_rate * delta
			player_is_moving = false
	
	# Apply energy change
	_change_energy(energy_change)

func _change_energy(amount: float):
	var old_energy = current_energy
	current_energy = clamp(current_energy + amount, 0.0, max_energy)
	
	# Check for energy depletion (hitting threshold)
	if old_energy > forced_recharge_threshold and current_energy <= forced_recharge_threshold:
		_on_energy_depleted()
		# Start forced recharge when energy hits threshold
		if not is_forced_recharging:
			_start_forced_recharge()
	
	# Check for energy restoration after depletion
	if old_energy <= forced_recharge_threshold and current_energy > forced_recharge_threshold:
		_on_energy_restored()
	
	# Check if we can unlock movement based on energy percentage
	if movement_locked and current_energy >= movement_unlock_threshold:
		_unlock_movement()
		# Also end forced recharge if energy is sufficient
		if is_forced_recharging:
			_end_forced_recharge()
	
	_emit_energy_changed()

func _on_energy_depleted():
	if debug_energy_changes:
		print("ENERGY DEPLETED!")
	energy_depleted.emit()
	# Movement locking is handled by forced recharge

func _on_energy_restored():
	if debug_energy_changes:
		print("Energy restored from depletion.")
	energy_restored.emit()

func _start_forced_recharge():
	if is_forced_recharging:
		return
	
	if debug_recharge_changes:
		print("FORCED RECHARGE STARTED - Energy depleted: ", current_energy, " | Movement locked until ", movement_unlock_threshold, "% energy")
	is_forced_recharging = true
	forced_recharge_started.emit()
	
	# Lock movement during forced recharge
	if not movement_locked:
		if debug_movement_changes:
			print("MOVEMENT LOCKED (forced recharge)")
		movement_locked = true
		movement_lock_started.emit()

func _end_forced_recharge():
	if not is_forced_recharging:
		return
	
	if debug_recharge_changes:
		print("FORCED RECHARGE ENDED - Energy: ", "%.1f" % current_energy, "% | Movement unlocked")
	is_forced_recharging = false
	forced_recharge_ended.emit()

func _unlock_movement():
	if not movement_locked:
		return
	
	if debug_movement_changes:
		print("MOVEMENT UNLOCKED - Energy reached ", "%.1f" % get_energy_percentage(), "% (threshold: ", movement_unlock_threshold, "%)")
	movement_locked = false
	movement_unlocked.emit()

func _emit_energy_changed():
	var percentage = (current_energy / max_energy) * percentage_multiplier
	energy_changed.emit(current_energy, max_energy, percentage)

# === PUBLIC API ===

func drain_energy_for_firing():
	"""Drain energy when player fires a weapon."""
	if is_forced_recharging:
		return false  # Can't fire during forced recharge
	
	_change_energy(-firing_drain_amount)
	if debug_firing_events:
		print("Energy drained for firing: -", firing_drain_amount, " (Current: ", "%.1f" % current_energy, ")")
	return true

func set_player_movement_intent(intent: float):
	"""Update player movement intensity (0.0 to 1.0)."""
	var old_intent = player_movement_intent
	player_movement_intent = clamp(intent, movement_intent_min, movement_intent_max)
	
	# Debug output when movement intent changes significantly
	if debug_movement_changes and abs(old_intent - player_movement_intent) > movement_intent_debug_threshold:
		print("Movement intent: ", "%.2f" % player_movement_intent, " | Energy: ", "%.1f" % current_energy, " | Can move: ", can_move(), " | Forced recharge: ", is_forced_recharging)

func can_move() -> bool:
	"""Check if player is allowed to move."""
	return not movement_locked and not is_forced_recharging

func can_fire() -> bool:
	"""Check if player can fire weapons."""
	return not is_forced_recharging and current_energy > minimum_firing_energy

func get_energy_percentage() -> float:
	"""Get current energy as percentage (0.0 to 100.0)."""
	return (current_energy / max_energy) * percentage_multiplier

func get_current_energy() -> float:
	"""Get current energy value."""
	return current_energy

func get_max_energy() -> float:
	"""Get maximum energy value."""
	return max_energy

func is_energy_depleted() -> bool:
	"""Check if energy is depleted (at or below threshold)."""
	return current_energy <= forced_recharge_threshold

func is_in_forced_recharge() -> bool:
	"""Check if currently in forced recharge state."""
	return is_forced_recharging

func is_movement_locked() -> bool:
	"""Check if movement is currently locked."""
	return movement_locked

# === CONFIGURATION API ===

func set_drain_rates(movement_drain: float, firing_drain: float):
	"""Update drain rates at runtime."""
	movement_drain_rate = movement_drain
	firing_drain_amount = firing_drain
	if debug_config_changes:
		print("Updated drain rates - Movement: ", movement_drain, "/s, Firing: ", firing_drain, " per shot")

func set_charge_rate(rate: float):
	"""Update charge rate at runtime."""
	charge_rate = rate
	if debug_config_changes:
		print("Updated charge rate: ", rate, "/s")

func set_movement_unlock_threshold(threshold: float):
	"""Update the energy percentage needed to unlock movement."""
	movement_unlock_threshold = threshold
	if debug_config_changes:
		print("Updated movement unlock threshold: ", threshold, "%")

# === DEBUG FUNCTIONS ===

func add_energy(amount: float):
	"""Debug function to add energy."""
	_change_energy(amount)
	if debug_energy_changes:
		print("DEBUG: Added ", amount, " energy (Current: ", "%.1f" % current_energy, ")")

func drain_energy(amount: float):
	"""Debug function to drain energy."""
	_change_energy(-amount)
	if debug_energy_changes:
		print("DEBUG: Drained ", amount, " energy (Current: ", "%.1f" % current_energy, ")")

func reset_energy():
	"""Debug function to reset energy to full."""
	current_energy = max_energy
	_emit_energy_changed()
	if debug_energy_changes:
		print("DEBUG: Energy reset to full")

func print_status():
	"""Debug function to print current status."""
	print("\n=== TIME ENERGY STATUS ===")
	print("Energy: ", "%.1f" % current_energy, "/", max_energy, " (", "%.1f" % get_energy_percentage(), "%)")
	print("Moving: ", player_is_moving, " (Intent: ", "%.2f" % player_movement_intent, ")")
	print("Forced recharge: ", is_forced_recharging)
	print("Movement locked: ", movement_locked)
	if movement_locked:
		print("Unlock threshold: ", movement_unlock_threshold, "% (need ", "%.1f" % (movement_unlock_threshold - get_energy_percentage()), "% more)")
	print("========================\n")
