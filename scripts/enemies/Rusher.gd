extends BaseEnemy
class_name Rusher

# === RUSHER ENEMY ===
# Fast, aggressive enemy that rapidly closes distance while firing
# Role: Tests reaction time and movement under pressure

## === RUSHER CONFIGURATION ===
@export_group("Rusher Stats")
## Health points for Rusher enemies
@export var rusher_health: int = 50
## Movement speed for Rusher enemies
@export var rusher_movement_speed: float = 10.0
## Detection range for Rusher enemies
@export var rusher_detection_range: float = 20.0
## Attack range for Rusher enemies
@export var rusher_attack_range: float = 15.0
## Rotation speed for Rusher enemies
@export var rusher_turn_speed: float = 10.0
## Piercing resistance for Rusher enemies (standard)
@export var rusher_piercability: float = 1.0

@export_group("Rusher Appearance")
## Color for Rusher enemies
@export var rusher_color: Color = Color.YELLOW
## Size scale for Rusher enemies
@export var rusher_size_scale: float = 1.1

@export_group("Rusher Behavior")
## Movement behavior type for Rusher enemies
@export var rusher_movement_behavior: MovementBehavior.Type = MovementBehavior.Type.CHASE
## Attack behavior type for Rusher enemies
@export var rusher_attack_behavior: AttackBehavior.Type = AttackBehavior.Type.RANGED

func _ready():
	# Configure as fast aggressive attacker using exported values
	max_health = rusher_health
	movement_speed = rusher_movement_speed
	detection_range = rusher_detection_range
	attack_range = rusher_attack_range
	turn_speed = rusher_turn_speed
	piercability = rusher_piercability
	
	# Set behaviors
	movement_behavior_type = rusher_movement_behavior
	attack_behavior_type = rusher_attack_behavior
	
	# Appearance
	enemy_color = rusher_color
	size_scale = rusher_size_scale
	
	# Call parent ready
	super()
