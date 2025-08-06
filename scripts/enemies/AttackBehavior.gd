extends Resource
class_name AttackBehavior

# === ATTACK BEHAVIOR SYSTEM ===
# Base class for enemy attack patterns

enum Type {
	MELEE,      # Close combat attacks
	RANGED,     # Single projectile shots
	BURST,      # Multiple shots in sequence
	CHARGED,    # Charge up then fire
	EXPLOSIVE   # Area damage attacks
}

# === CONFIGURATION ===
var enemy: BaseEnemy
var behavior_name: String = "Base"

# Common attack state
var attack_cooldown: float = 0.0
var is_on_cooldown: bool = false
var last_attack_time: float = 0.0

# === FACTORY METHOD ===
static func create(type: Type) -> AttackBehavior:
	"""Factory method to create specific attack behaviors."""
	match type:
		Type.MELEE:
			return MeleeAttack.new()
		Type.RANGED:
			return RangedAttack.new()
		Type.BURST:
			return BurstAttack.new()
		Type.CHARGED:
			return ChargedAttack.new()
		Type.EXPLOSIVE:
			return ExplosiveAttack.new()
		_:
			return MeleeAttack.new()

# === VIRTUAL METHODS ===

func setup(enemy_ref: BaseEnemy):
	"""Initialize the behavior with enemy reference."""
	enemy = enemy_ref
	_on_setup()

func _on_setup():
	"""Override in derived classes for specific setup."""
	pass

func should_attack(delta: float) -> bool:
	"""Check if the enemy should attack this frame."""
	if is_on_cooldown:
		attack_cooldown -= delta
		if attack_cooldown <= 0.0:
			is_on_cooldown = false
	
	return not is_on_cooldown and _can_attack()

func _can_attack() -> bool:
	"""Override in derived classes for specific attack conditions."""
	return true

func execute_attack():
	"""Execute the attack. Override in derived classes."""
	_start_cooldown()

func _start_cooldown():
	"""Start the attack cooldown."""
	is_on_cooldown = true
	attack_cooldown = _get_cooldown_time()

func _get_cooldown_time() -> float:
	"""Get the cooldown time for this attack. Override in derived classes."""
	return 1.0

func on_attack_timer_timeout():
	"""Called when the enemy's attack timer expires."""
	pass

func cleanup():
	"""Clean up resources when behavior is changed."""
	pass

# === UTILITY METHODS ===

func get_direction_to_player() -> Vector3:
	"""Get direction to player."""
	if enemy:
		return enemy.get_direction_to_player()
	return Vector3.ZERO

func is_player_in_range(range: float) -> bool:
	"""Check if player is in attack range."""
	if enemy:
		return enemy.is_player_in_range(range)
	return false

func create_bullet() -> RigidBody3D:
	"""Create a bullet using the same system as the player."""
	var bullet_scene = preload("res://scenes/bullet.tscn")
	var bullet = bullet_scene.instantiate()
	enemy.get_tree().current_scene.add_child(bullet)
	
	# Configure bullet for enemy use
	bullet.collision_layer = 256  # Enemy bullets layer (bit 9)
	bullet.collision_mask = 5     # Environment (4) + Player (1) = 5
	bullet.contact_monitor = true
	bullet.max_contacts_reported = 10
	
	return bullet

# === MELEE ATTACK ===
class MeleeAttack extends AttackBehavior:
	"""Close combat melee attacks."""
	
	var melee_damage: int = 25
	var melee_range: float = 2.5
	var cooldown_time: float = 1.5
	
	func _on_setup():
		behavior_name = "Melee"
	
	func _can_attack() -> bool:
		return is_player_in_range(melee_range)
	
	func execute_attack():
		super()
		
		if not enemy or not enemy.get_player():
			return
		
		print(enemy.name, " performs melee attack!")
		
		# Deal damage to player if still in range
		if is_player_in_range(melee_range):
			var player = enemy.get_player()
			if player.has_method("take_damage"):
				player.take_damage(melee_damage)
		
		# Finish attack after brief delay
		enemy.get_tree().create_timer(0.3).timeout.connect(enemy._finish_attack)
	
	func _get_cooldown_time() -> float:
		return cooldown_time

# === RANGED ATTACK ===
class RangedAttack extends AttackBehavior:
	"""Single projectile ranged attacks."""
	
	var projectile_damage: int = 20
	var projectile_speed: float = 25.0
	var cooldown_time: float = 2.0
	var max_range: float = 15.0
	
	func _on_setup():
		behavior_name = "Ranged"
	
	func _can_attack() -> bool:
		return is_player_in_range(max_range) and enemy.is_player_visible()
	
	func execute_attack():
		super()
		
		if not enemy or not enemy.get_player():
			return
		
		print(enemy.name, " fires ranged shot!")
		
		# Create and fire bullet
		var bullet = create_bullet()
		bullet.global_position = enemy.global_position + Vector3.UP * 0.5
		
		# Set bullet properties
		if bullet.has_method("set_damage"):
			bullet.set_damage(projectile_damage)
		
		if bullet.has_method("set_travel_config"):
			bullet.set_travel_config(2, {"max_speed": projectile_speed, "min_speed": projectile_speed})
		
		# Fire toward player
		var direction = get_direction_to_player()
		if bullet.has_method("fire"):
			bullet.fire(direction)
		
		# Finish attack
		enemy._finish_attack()
	
	func _get_cooldown_time() -> float:
		return cooldown_time

# === BURST ATTACK ===
class BurstAttack extends AttackBehavior:
	"""Multiple projectiles in quick succession."""
	
	var burst_damage: int = 15
	var burst_count: int = 3
	var burst_interval: float = 0.2
	var burst_speed: float = 30.0
	var cooldown_time: float = 3.0
	var max_range: float = 12.0
	
	var current_burst_count: int = 0
	var burst_timer: Timer
	
	func _on_setup():
		behavior_name = "Burst"
		
		# Create burst timer
		burst_timer = Timer.new()
		burst_timer.wait_time = burst_interval
		burst_timer.timeout.connect(_fire_burst_shot)
		enemy.add_child(burst_timer)
	
	func _can_attack() -> bool:
		return is_player_in_range(max_range) and enemy.is_player_visible()
	
	func execute_attack():
		super()
		
		if not enemy or not enemy.get_player():
			return
		
		print(enemy.name, " starts burst attack!")
		
		current_burst_count = 0
		_fire_burst_shot()
	
	func _fire_burst_shot():
		if current_burst_count >= burst_count:
			enemy._finish_attack()
			return
		
		# Create and fire bullet
		var bullet = create_bullet()
		bullet.global_position = enemy.global_position + Vector3.UP * 0.5
		
		# Set bullet properties
		if bullet.has_method("set_damage"):
			bullet.set_damage(burst_damage)
		
		if bullet.has_method("set_travel_config"):
			bullet.set_travel_config(2, {"max_speed": burst_speed, "min_speed": burst_speed})
		
		# Fire toward player with slight spread
		var direction = get_direction_to_player()
		var spread_angle = (randf() - 0.5) * 0.2  # Small spread
		direction = direction.rotated(Vector3.UP, spread_angle).normalized()
		
		if bullet.has_method("fire"):
			bullet.fire(direction)
		
		current_burst_count += 1
		
		# Schedule next shot if more to fire
		if current_burst_count < burst_count:
			burst_timer.start()
		else:
			enemy._finish_attack()
	
	func _get_cooldown_time() -> float:
		return cooldown_time
	
	func cleanup():
		if burst_timer and is_instance_valid(burst_timer):
			burst_timer.queue_free()

# === CHARGED ATTACK ===
class ChargedAttack extends AttackBehavior:
	"""Charge up then fire powerful shot."""
	
	var charged_damage: int = 50
	var charge_time: float = 1.5
	var projectile_speed: float = 40.0
	var cooldown_time: float = 4.0
	var max_range: float = 20.0
	
	var is_charging: bool = false
	var charge_timer: Timer
	
	func _on_setup():
		behavior_name = "Charged"
		
		# Create charge timer
		charge_timer = Timer.new()
		charge_timer.wait_time = charge_time
		charge_timer.one_shot = true
		charge_timer.timeout.connect(_fire_charged_shot)
		enemy.add_child(charge_timer)
	
	func _can_attack() -> bool:
		return is_player_in_range(max_range) and enemy.is_player_visible() and not is_charging
	
	func execute_attack():
		super()
		
		if not enemy or not enemy.get_player():
			return
		
		print(enemy.name, " charging attack...")
		
		is_charging = true
		charge_timer.start()
		
		# TODO: Add charging visual effect
	
	func _fire_charged_shot():
		if not is_charging:
			return
		
		print(enemy.name, " fires charged shot!")
		
		# Create and fire powerful bullet
		var bullet = create_bullet()
		bullet.global_position = enemy.global_position + Vector3.UP * 0.5
		
		# Set bullet properties
		if bullet.has_method("set_damage"):
			bullet.set_damage(charged_damage)
		
		if bullet.has_method("set_travel_config"):
			bullet.set_travel_config(2, {"max_speed": projectile_speed, "min_speed": projectile_speed})
		
		# Fire toward player
		var direction = get_direction_to_player()
		if bullet.has_method("fire"):
			bullet.fire(direction)
		
		is_charging = false
		enemy._finish_attack()
	
	func _get_cooldown_time() -> float:
		return cooldown_time
	
	func cleanup():
		if charge_timer and is_instance_valid(charge_timer):
			charge_timer.queue_free()

# === EXPLOSIVE ATTACK ===
class ExplosiveAttack extends AttackBehavior:
	"""High damage area attacks."""
	
	var explosive_damage: int = 40
	var explosion_radius: float = 5.0
	var projectile_speed: float = 20.0
	var cooldown_time: float = 5.0
	var max_range: float = 18.0
	
	func _on_setup():
		behavior_name = "Explosive"
	
	func _can_attack() -> bool:
		return is_player_in_range(max_range) and enemy.is_player_visible()
	
	func execute_attack():
		super()
		
		if not enemy or not enemy.get_player():
			return
		
		print(enemy.name, " fires explosive!")
		
		# Create and fire explosive bullet
		var bullet = create_bullet()
		bullet.global_position = enemy.global_position + Vector3.UP * 0.5
		
		# Set bullet properties
		if bullet.has_method("set_damage"):
			bullet.set_damage(explosive_damage)
		
		if bullet.has_method("set_explosion_properties"):
			bullet.set_explosion_properties(explosion_radius, explosive_damage)
		
		if bullet.has_method("set_travel_config"):
			bullet.set_travel_config(1, {"max_speed": projectile_speed, "min_speed": projectile_speed})
		
		# Fire toward player
		var direction = get_direction_to_player()
		if bullet.has_method("fire"):
			bullet.fire(direction)
		
		enemy._finish_attack()
	
	func _get_cooldown_time() -> float:
		return cooldown_time