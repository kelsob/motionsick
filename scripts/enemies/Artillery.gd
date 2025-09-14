extends BaseEnemy
class_name Artillery

# === ARTILLERY ENEMY ===
# Heavy enemy that circles the player and fires explosive projectiles
# Role: Tests area denial, dodging, and sustained combat

## === ARTILLERY CONFIGURATION ===
@export_group("Artillery Stats")
## Health points for Artillery enemies
@export var artillery_health: int = 120
## Movement speed for Artillery enemies
@export var artillery_movement_speed: float = 4.0
## Detection range for Artillery enemies
@export var artillery_detection_range: float = 22.0
## Attack range for Artillery enemies
@export var artillery_attack_range: float = 18.0
## Rotation speed for Artillery enemies
@export var artillery_turn_speed: float = 2.0
## Piercing resistance for Artillery enemies (high - hard to pierce)
@export var artillery_piercability: float = 2.0

@export_group("Artillery Appearance")
## Color for Artillery enemies
@export var artillery_color: Color = Color.DARK_GREEN
## Size scale for Artillery enemies
@export var artillery_size_scale: float = 1.3

@export_group("Artillery Behavior")
## Movement behavior type for Artillery enemies
@export var artillery_movement_behavior: MovementBehavior.Type = MovementBehavior.Type.CIRCLING
## Attack behavior type for Artillery enemies
@export var artillery_attack_behavior: AttackBehavior.Type = AttackBehavior.Type.EXPLOSIVE

func _ready():
	# Configure as heavy artillery using exported values
	max_health = artillery_health
	movement_speed = artillery_movement_speed
	detection_range = artillery_detection_range
	attack_range = artillery_attack_range
	turn_speed = artillery_turn_speed
	piercability = artillery_piercability
	
	# Set behaviors
	movement_behavior_type = artillery_movement_behavior
	attack_behavior_type = artillery_attack_behavior
	
	# Appearance
	enemy_color = artillery_color
	size_scale = artillery_size_scale
	
	# Call parent ready
	super()
