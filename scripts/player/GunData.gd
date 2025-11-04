class_name GunData
extends Resource

# === GUN DATA RESOURCE ===
# Defines all properties and behaviors for a specific gun type
# This allows for data-driven gun design and easy balancing

@export_group("Basic Info")
## Display name for this gun type
@export var gun_name: String = "Pistol"
## Gun type ID (0=Pistol, 1=Rifle, 2=Shotgun, 3=Sniper, 4=RocketLauncher)
@export var gun_type: int = 0

@export_group("Firing Properties")
## Fire rate (seconds between shots)
@export var fire_rate: float = 0.5
## Damage per shot
@export var damage: int = 45
## Ammo capacity
@export var ammo_capacity: int = 12
## Bullet spread angle in degrees
@export var spread_angle: float = 2.0
## Bullet travel speed
@export var bullet_speed: float = 100.0

@export_group("Shotgun Properties")
## Whether this gun fires multiple pellets
@export var is_shotgun: bool = false
## Number of pellets to fire (only used if is_shotgun = true)
@export var pellet_count: int = 1
## Spread angle for shotgun pellets
@export var shotgun_spread: float = 15.0

@export_group("Explosive Properties")
## Whether this gun fires explosive projectiles
@export var is_explosive: bool = false
## Explosion radius (only used if is_explosive = true)
@export var explosion_radius: float = 0.0
## Explosion damage (only used if is_explosive = true)
@export var explosion_damage: int = 0

@export_group("Behavior Settings")
## Which fire mode this gun uses (from Gun.FireMode enum)
@export var fire_mode: int = 0  # 0 = RAPID_FIRE
## Bullet travel type (0=hitscan, 1=slow, 2=fast, etc.)
@export var travel_type: int = 2
## Knockback force applied to enemies
@export var knockback_force: float = 10.0
## Whether bullets can pierce through enemies
@export var piercing: bool = false

@export_group("Audio")
## Texture for this gun type (optional)
@export var gun_texture: Texture2D
## Sound effect name for gunshots
@export var sfx_name: String = "pistol"

@export_group("Visual Effects")
## Muzzle flash size multiplier
@export var muzzle_flash_size: float = 1.0
## Recoil intensity multiplier
@export var recoil_intensity: float = 1.0
## Bullet trail color
@export var bullet_trail_color: Color = Color.WHITE

@export_group("Scenes")
## Gun scene to instantiate for this gun type (inherits from GunParent)
@export var gun_scene: PackedScene
## Bullet scene to instantiate for this gun type
@export var bullet_scene: PackedScene

func _init():
	# Set default values for pistol
	gun_name = "Pistol"
	gun_type = 0
	fire_rate = 0.5
	damage = 45
	ammo_capacity = 12
	spread_angle = 2.0
	bullet_speed = 100.0
	is_shotgun = false
	pellet_count = 1
	shotgun_spread = 15.0
	is_explosive = false
	explosion_radius = 0.0
	explosion_damage = 0
	fire_mode = 0  # RAPID_FIRE
	travel_type = 2  # CONSTANT_FAST
	knockback_force = 10.0
	piercing = false
	sfx_name = "pistol"
	muzzle_flash_size = 1.0
	recoil_intensity = 1.0
	bullet_trail_color = Color.WHITE
