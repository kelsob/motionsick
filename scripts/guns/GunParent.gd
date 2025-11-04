class_name GunParent
extends Node3D

# === GUN PARENT SCRIPT ===
# Base class for all guns with common functionality

# Common gun components (will be set up in scene)
@onready var animation_player: AnimationPlayer = $AnimationPlayer
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D
@onready var muzzle_flash_particles: GPUParticles3D = $MuzzleFlashParticles
@onready var gun_mesh: MeshInstance3D = $GunMesh

# Gun state
var is_equipped: bool = false
var is_pickup: bool = false
var gun_data: Resource = null

# Common gun properties (can be overridden by child classes)
@export var gun_name: String = "Generic Gun"
@export var gun_type: int = 0
@export var fire_rate: float = 1.0
@export var damage: float = 10.0
@export var ammo_capacity: int = 12
@export var current_ammo: int = 12
@export var spread_angle: float = 0.1
@export var bullet_speed: float = 50.0
@export var knockback_force: float = 5.0


# Common gun methods
func fire():
	"""Fire the gun - override in child classes for specific behavior"""
	if current_ammo <= 0:
		return false
	
	current_ammo -= 1
	_play_fire_animation()
	_play_fire_sound()
	_play_muzzle_flash()
	return true

func reload():
	"""Reload the gun - override in child classes for specific behavior"""
	current_ammo = ammo_capacity
	_play_reload_animation()
	_play_reload_sound()

func equip():
	"""Equip the gun - common functionality"""
	is_equipped = true
	if animation_player:
		animation_player.play("equip")

func unequip():
	"""Unequip the gun - common functionality"""
	is_equipped = false
	if animation_player:
		animation_player.play("unequip")

# Animation methods
func _play_fire_animation():
	"""Play fire animation - override in child classes"""
	if animation_player and animation_player.has_animation("fire"):
		animation_player.play("fire")

func _play_reload_animation():
	"""Play reload animation - override in child classes"""
	if animation_player and animation_player.has_animation("reload"):
		animation_player.play("reload")

# Audio methods
func _play_fire_sound():
	"""Play fire sound - override in child classes"""
	if audio_player:
		# Default fire sound - child classes can override
		pass

func _play_reload_sound():
	"""Play reload sound - override in child classes"""
	if audio_player:
		# Default reload sound - child classes can override
		pass

# Visual effects
func _play_muzzle_flash():
	"""Play muzzle flash effect - override in child classes"""
	if muzzle_flash_particles:
		muzzle_flash_particles.restart()

# Pickup functionality
func _on_pickup_area_body_entered(body):
	"""Handle pickup detection"""
	if body.is_in_group("player") and is_pickup:
		_try_pickup(body)

func _on_pickup_area_body_exited(body):
	"""Handle pickup area exit"""
	pass

func _try_pickup(player):
	"""Try to pick up the gun - override in child classes"""
	# This should be handled by GunPickup.gd, but can be overridden
	pass

# Utility methods
func get_ammo_info() -> Dictionary:
	"""Get current ammo information"""
	return {
		"current": current_ammo,
		"max": ammo_capacity,
		"percentage": float(current_ammo) / float(ammo_capacity)
	}

func set_gun_data(data: Resource):
	"""Set gun data from resource"""
	gun_data = data
	if data:
		# Apply common properties from gun data
		if data.has_method("get") and data.get("gun_name") != null:
			gun_name = data.get("gun_name")
		if data.has_method("get") and data.get("gun_type") != null:
			gun_type = data.get("gun_type")
		if data.has_method("get") and data.get("fire_rate") != null:
			fire_rate = data.get("fire_rate")
		if data.has_method("get") and data.get("damage") != null:
			damage = data.get("damage")
		if data.has_method("get") and data.get("ammo_capacity") != null:
			ammo_capacity = data.get("ammo_capacity")
		if data.has_method("get") and data.get("current_ammo") != null:
			current_ammo = data.get("current_ammo")
		if data.has_method("get") and data.get("spread_angle") != null:
			spread_angle = data.get("spread_angle")
		if data.has_method("get") and data.get("bullet_speed") != null:
			bullet_speed = data.get("bullet_speed")
		if data.has_method("get") and data.get("knockback_force") != null:
			knockback_force = data.get("knockback_force")

func is_empty() -> bool:
	"""Check if gun is empty"""
	return current_ammo <= 0

func is_full() -> bool:
	"""Check if gun is full"""
	return current_ammo >= ammo_capacity
