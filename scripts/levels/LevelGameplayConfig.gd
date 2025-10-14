extends Resource
class_name LevelGameplayConfig

## Comprehensive level-specific gameplay configuration
## All parameters default to "use global settings" values
## Only modify the ones you want to override for this specific level

# === PLAYER CONFIGURATION ===
@export_group("Player Settings")
## Starting bullet count (-1 = use default)
@export var starting_bullet_count: int = -1
## Starting gun type (-1 = use default, 0 = pistol, 1 = rifle, etc.)
@export var starting_gun_type: int = -1
## Player movement speed multiplier (1.0 = normal, 0.5 = half speed, 2.0 = double speed)
@export var player_movement_speed_multiplier: float = 1.0
## Player jump height multiplier (1.0 = normal)
@export var player_jump_height_multiplier: float = 1.0
## Player time energy capacity multiplier (1.0 = normal)
@export var player_time_energy_multiplier: float = 1.0
## Player time energy regeneration rate multiplier (1.0 = normal)
@export var player_time_energy_regen_multiplier: float = 1.0

# === BULLET CONFIGURATION ===
@export_group("Bullet Physics")
## Global bullet speed multiplier (1.0 = normal, 0.5 = half speed, 2.0 = double speed)
@export var bullet_speed_multiplier: float = 1.0
## Global bullet damage multiplier (1.0 = normal)
@export var bullet_damage_multiplier: float = 1.0
## Global bullet bounce count multiplier (1.0 = normal, 0 = no bouncing, 2.0 = double bounces)
@export var bullet_bounce_multiplier: float = 1.0
## Global bullet lifetime multiplier (1.0 = normal)
@export var bullet_lifetime_multiplier: float = 1.0
## Bullet gravity multiplier (1.0 = normal, 0 = no gravity, 2.0 = double gravity)
@export var bullet_gravity_multiplier: float = 1.0

# === TIME SYSTEM CONFIGURATION ===
@export_group("Time System")
## Time dilation strength multiplier (1.0 = normal)
@export var time_dilation_strength_multiplier: float = 1.0
## Time dilation duration multiplier (1.0 = normal)
@export var time_dilation_duration_multiplier: float = 1.0
## Time energy cost multiplier (1.0 = normal, 0.5 = half cost, 2.0 = double cost)
@export var time_energy_cost_multiplier: float = 1.0

# === ENEMY CONFIGURATION ===
@export_group("Enemy Settings")
## Enemy health multiplier (1.0 = normal)
@export var enemy_health_multiplier: float = 1.0
## Enemy speed multiplier (1.0 = normal)
@export var enemy_speed_multiplier: float = 1.0
## Enemy damage multiplier (1.0 = normal)
@export var enemy_damage_multiplier: float = 1.0
## Enemy accuracy multiplier (1.0 = normal, 0.5 = half accuracy)
@export var enemy_accuracy_multiplier: float = 1.0

# === ENVIRONMENTAL EFFECTS ===
@export_group("Environmental Effects")
## Global gravity multiplier (1.0 = normal, 0.5 = moon gravity, 2.0 = heavy gravity)
@export var gravity_multiplier: float = 1.0
## Air resistance multiplier (1.0 = normal, 0 = no air resistance, 2.0 = thick air)
@export var air_resistance_multiplier: float = 1.0
## Wind force vector (Vector3.ZERO = no wind)
@export var wind_force: Vector3 = Vector3.ZERO
## Fog density (0.0 = no fog, 1.0 = heavy fog)
@export var fog_density: float = 0.0

# === AUDIO/VISUAL EFFECTS ===
@export_group("Audio Visual")
## Music track to play for this level (empty = no music)
@export var music_track_name: String = ""
## Master volume multiplier (1.0 = normal)
@export var master_volume_multiplier: float = 1.0
## Music volume multiplier (1.0 = normal)
@export var music_volume_multiplier: float = 1.0
## SFX volume multiplier (1.0 = normal)
@export var sfx_volume_multiplier: float = 1.0
## Visual effects intensity multiplier (1.0 = normal)
@export var vfx_intensity_multiplier: float = 1.0

# === SPECIAL LEVEL MECHANICS ===
@export_group("Special Mechanics")
## Enable infinite ammo for this level
@export var infinite_ammo: bool = false
## Enable god mode for this level
@export var god_mode: bool = false
## Disable time dilation for this level
@export var disable_time_dilation: bool = false
## Force specific lighting conditions
@export var override_lighting: bool = false
## Custom lighting environment (if override_lighting is true)
@export var custom_environment: Environment = null

# === LEVEL COMPLETION ===
@export_group("Level Goals")
## Required score to complete level (-1 = no requirement)
@export var required_score: int = -1
## Time limit in seconds (-1 = no time limit)
@export var time_limit: float = -1.0
## Required survival time in seconds (-1 = no requirement)
@export var required_survival_time: float = -1.0
## Maximum allowed deaths (-1 = unlimited)
@export var max_deaths: int = -1

# === DEBUG SETTINGS ===
@export_group("Debug")
## Enable debug mode for this level
@export var debug_mode: bool = false
## Show debug info overlay
@export var show_debug_overlay: bool = false

## Get a summary of all non-default settings
func get_active_overrides() -> Dictionary:
	var overrides = {}
	
	if starting_bullet_count != -1:
		overrides["starting_bullet_count"] = starting_bullet_count
	if starting_gun_type != -1:
		overrides["starting_gun_type"] = starting_gun_type
	if player_movement_speed_multiplier != 1.0:
		overrides["player_movement_speed_multiplier"] = player_movement_speed_multiplier
	if bullet_speed_multiplier != 1.0:
		overrides["bullet_speed_multiplier"] = bullet_speed_multiplier
	if bullet_damage_multiplier != 1.0:
		overrides["bullet_damage_multiplier"] = bullet_damage_multiplier
	if gravity_multiplier != 1.0:
		overrides["gravity_multiplier"] = gravity_multiplier
	if wind_force != Vector3.ZERO:
		overrides["wind_force"] = wind_force
	if infinite_ammo:
		overrides["infinite_ammo"] = true
	if god_mode:
		overrides["god_mode"] = true
	if time_limit > 0:
		overrides["time_limit"] = time_limit
	
	return overrides

## Check if this config has any overrides
func has_overrides() -> bool:
	return get_active_overrides().size() > 0
