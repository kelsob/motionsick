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

# Gunfire telegraph system
var gunfire_telegraph_scene: PackedScene = preload("res://scenes/GunfireTelegraph.tscn")
var telegraph_duration: float = 1.0  # Short, snappy telegraph

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

func get_direction_to_player(from_position: Vector3 = Vector3.ZERO) -> Vector3:
	"""Get direction to player from a specific position (e.g., bullet spawn point)."""
	if enemy and enemy.player:
		var start_pos = from_position if from_position != Vector3.ZERO else enemy.global_position
		var target_pos = enemy.player.get_target_position(start_pos)
		return (target_pos - start_pos).normalized()
	return Vector3.ZERO

func is_player_in_range(range: float) -> bool:
	"""Check if player is in attack range."""
	if enemy:
		return enemy.is_player_in_range(range)
	return false

func create_gunfire_telegraph(fire_position: Vector3, callback: Callable, total_time_to_fire: float = 3.0):
	"""Create a telegraph that times perfectly with when the bullet will fire."""
	print("Creating telegraph on enemy: ", enemy.name, " for ", total_time_to_fire, " seconds")
	
	# Create a simple Node3D with MeshInstance3D
	var telegraph = Node3D.new()
	var mesh_instance = MeshInstance3D.new()
	telegraph.add_child(mesh_instance)
	
	# Create animated torus - start big and VERY thin
	var torus = TorusMesh.new()
	var start_outer = 4.0
	var start_inner = 3.98  # EXTREMELY thin at start
	var end_outer = 1.0
	var end_inner = 0.5    # Thicker at end
	
	torus.inner_radius = start_inner
	torus.outer_radius = start_outer
	mesh_instance.mesh = torus
	
	# Create bright orange material - start completely invisible
	var material = StandardMaterial3D.new()
	material.albedo_color = Color.ORANGE
	material.albedo_color.a = 0.0  # Start completely invisible
	material.emission_enabled = true
	material.emission = Color.ORANGE
	material.emission_energy = 2.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mesh_instance.material_override = material
	
	# Add to enemy
	enemy.add_child(telegraph)
	
	# Position at bullet spawn point
	var bullet_spawn_point = enemy.get_node_or_null("BulletSpawnPoint")
	if bullet_spawn_point:
		telegraph.global_position = bullet_spawn_point.global_position
	else:
		telegraph.position = Vector3.UP * 0.5  # Fallback
	telegraph.rotation_degrees.x = 90  # Rotate to face forward instead of lying flat
	
	print("Telegraph created and added to enemy")
	
	# Animate for the exact time until firing using TimeManager
	var time_manager = enemy.get_node_or_null("/root/TimeManager")
	var elapsed_time = 0.0
	
	while elapsed_time < total_time_to_fire:
		# Check if enemy is still valid before waiting
		if not is_instance_valid(enemy) or not enemy.is_inside_tree():
			print("Enemy destroyed during telegraph - aborting")
			telegraph.queue_free()
			return telegraph
		
		await enemy.get_tree().process_frame
		
		# Double-check enemy is still valid after await
		if not is_instance_valid(enemy) or not enemy.is_inside_tree():
			print("Enemy destroyed during telegraph - aborting")
			telegraph.queue_free()
			return telegraph
		
		# Use TimeManager-adjusted delta
		var frame_delta = enemy.get_process_delta_time()
		if time_manager:
			frame_delta *= time_manager.get_time_scale()
		
		elapsed_time += frame_delta
		
		var progress = elapsed_time / total_time_to_fire
		progress = clamp(progress, 0.0, 1.0)
		
		# Use exponential ease-in interpolation for dramatic effect
		var eased_progress = progress * progress * progress  # Cubic ease-in
		
		# Animate size (shrink from big to small) with easing
		var current_outer = lerp(start_outer, end_outer, eased_progress)
		var current_inner = lerp(start_inner, end_inner, eased_progress)
		torus.outer_radius = current_outer
		torus.inner_radius = current_inner
		
		# Animate visibility (fade in) with different easing for urgency
		var alpha_progress = progress * progress  # Quadratic ease-in for alpha
		var alpha = lerp(0.0, 0.9, alpha_progress)
		material.albedo_color.a = alpha
	
	print("Telegraph complete - callback firing!")
	callback.call()
	
	# Remove telegraph
	telegraph.queue_free()
	
	return telegraph

func create_bullet(bullet_scene_path: String = "") -> Area3D:
	"""Create a bullet using specified scene or fallback."""
	var bullet_scene: PackedScene
	
	# Use provided scene path or fallback to default
	if bullet_scene_path != "":
		bullet_scene = load(bullet_scene_path)
	else:
		bullet_scene = preload("res://scenes/bullets/bullet.tscn")  # Default fallback
	
	print(bullet_scene_path)
	var bullet = bullet_scene.instantiate()
	enemy.get_tree().current_scene.add_child(bullet)
	
	# Position bullet at BulletSpawnPoint marker if available
	var spawn_point = enemy.get_node_or_null("BulletSpawnPoint")
	
	if spawn_point and bullet.has_method("set_spawn_point"):
		bullet.set_spawn_point(spawn_point)
	else:
		# Fallback to old positioning
		bullet.global_position = enemy.global_position + Vector3.UP * 0.5
	
	# Configure bullet for enemy use
	bullet.collision_layer = 256  # Enemy bullets layer (bit 9)
	bullet.collision_mask = 5     # Environment (bit 3=4) + Player (bit 1=1) = 5
	
	# Mark as enemy bullet
	if bullet.has_method("set_as_enemy_bullet"):
		bullet.set_as_enemy_bullet()
	
	# Set shooter reference for self-collision detection
	if bullet.has_method("set_shooter"):
		bullet.set_shooter(enemy)
	
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
		
		print(enemy.name, " telegraphs ranged shot!")
		
		# Telegraph the gunfire first
		var fire_position = enemy.global_position + Vector3.UP * 0.5
		create_gunfire_telegraph(fire_position, _execute_ranged_shot)
	
	func _execute_ranged_shot():
		"""Called after telegraph completes - fire the actual ranged bullet."""
		# Create and fire regular enemy bullet (positioned automatically)
		var bullet = create_bullet("res://scenes/bullets/RegularBullet.tscn")
		
		# Fire toward player using bullet's spawn position for accurate targeting
		var spawn_pos = bullet.global_position
		var direction = get_direction_to_player(spawn_pos)
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
	
	# Cache method checks for performance
	var bullet_has_set_damage: bool = false
	var bullet_has_set_travel_config: bool = false
	var bullet_has_fire: bool = false
	var methods_checked: bool = false
	
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
		
		current_burst_count = 0
		_fire_burst_shot()
	
	func _fire_burst_shot():
		if current_burst_count >= burst_count:
			enemy._finish_attack()
			return
		
		# Telegraph the gunfire first
		var fire_position = enemy.global_position + Vector3.UP * 0.5
		create_gunfire_telegraph(fire_position, _execute_actual_shot)
	
	func _execute_actual_shot():
		"""Called after telegraph completes - fire the actual bullet."""
		# Create and fire close-range bullet (positioned automatically)
		var bullet = create_bullet("res://scenes/bullets/BurstBullet.tscn")
		
		# Cache method checks on first bullet creation
		if not methods_checked:
			bullet_has_set_damage = bullet.has_method("set_damage")
			bullet_has_set_travel_config = bullet.has_method("set_travel_config")  
			bullet_has_fire = bullet.has_method("fire")
			methods_checked = true
		
		# Fire toward player with slight spread using bullet's spawn position
		var spawn_pos = bullet.global_position
		var direction = get_direction_to_player(spawn_pos)
		var spread_angle = (randf() - 0.5) * 0.2  # Small spread
		direction = direction.rotated(Vector3.UP, spread_angle).normalized()
		
		if bullet_has_fire:
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
	"""Charge up then fire powerful shot. Used by Sniper for telegraphed long-range shots."""
	
	var charged_damage: int = 100  # High damage to one-shot other enemies
	var charge_time: float = 2.0  # Default telegraph duration (will be overridden by enemy setting)
	var projectile_speed: float = 100.0  # Ultra-fast bullets
	var cooldown_time: float = 6.0  # Longer cooldown for sniper shots
	var max_range: float = 999.0  # Unlimited range for snipers
	
	var is_charging: bool = false
	var charge_timer: Timer
	
	func _on_setup():
		behavior_name = "Charged"
		
		# Get telegraph duration from enemy configuration
		if enemy and enemy.has_method("get") and enemy.get("telegraph_duration"):
			charge_time = enemy.telegraph_duration
		
		# Create charge timer
		charge_timer = Timer.new()
		charge_timer.wait_time = charge_time
		charge_timer.one_shot = true
		charge_timer.timeout.connect(_fire_charged_shot)
		enemy.add_child(charge_timer)
	
	func _can_attack() -> bool:
		# Snipers can attack from any distance if they can see the player
		var can_see = enemy.is_player_visible()
		var not_charging = not is_charging
		var can_attack = can_see and not_charging
		
		# DEBUG: Print sniper attack logic
		print("SNIPER ATTACK DEBUG - ", enemy.name)
		print("  Can see player: ", can_see)
		print("  Not charging: ", not_charging)
		print("  Can attack: ", can_attack)
		
		return can_attack
	
	func execute_attack():
		super()
		
		if not enemy or not enemy.get_player():
			return
		
		print(enemy.name, " starting charge with telegraph...")
		
		# Play sniper shot telegraph SFX
		AudioManager.play_sfx("sniper_shot_telegraph")
		
		# Telegraph for ONLY the charge time (1.5 seconds)
		var fire_position = enemy.global_position + Vector3.UP * 0.5
		create_gunfire_telegraph(fire_position, _fire_charged_shot, charge_time)
		
		# Set charging state immediately so we don't attack again
		is_charging = true
	
	func _start_charging():
		"""DEPRECATED: No longer used since telegraph handles full timing."""
		print(enemy.name, " starting charge phase...")
		is_charging = true
		charge_timer.start()
	
	func _fire_charged_shot():
		if not is_charging:
			return
		
		print(enemy.name, " fires SNIPER SHOT!")
		
		# Create and fire sniper bullet (you'll create this scene)
		var bullet = create_bullet("res://scenes/bullets/SniperBullet.tscn")
		# Position is already set by create_bullet() using BulletSpawnPoint
		
		# Set high damage for one-shot potential
		if bullet.has_method("set_damage"):
			bullet.set_damage(charged_damage)
		
		# Fire toward player using bullet's spawn position for precise targeting
		var spawn_pos = bullet.global_position
		var direction = get_direction_to_player(spawn_pos)
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
		
		# Create and fire explosive bullet (positioned automatically)
		var bullet = create_bullet("res://scenes/bullets/ExplosiveBullet.tscn")
		
		# Set explosion properties
		if bullet.has_method("set_explosion_properties"):
			bullet.set_explosion_properties(explosion_radius, explosive_damage)
		
		# Fire toward player using bullet's spawn position for accurate targeting
		var spawn_pos = bullet.global_position
		var direction = get_direction_to_player(spawn_pos)
		if bullet.has_method("fire"):
			bullet.fire(direction)
		
		enemy._finish_attack()
	
	func _get_cooldown_time() -> float:
		return cooldown_time
