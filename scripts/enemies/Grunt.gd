extends BaseEnemy
class_name Grunt

# === GRUNT ENEMY ===
# Basic melee enemy that chases the player relentlessly
# Role: Tests basic movement and close combat awareness

## === GRUNT CONFIGURATION ===
@export_group("Grunt Stats")
## Health points for Grunt enemies
@export var grunt_health: int = 80
## Movement speed for Grunt enemies
@export var grunt_movement_speed: float = 6.0
## Detection range for Grunt enemies
@export var grunt_detection_range: float = 15.0
## Attack range for Grunt enemies
@export var grunt_attack_range: float = 3.0
## Rotation speed for Grunt enemies
@export var grunt_turn_speed: float = 15.0
## Piercing resistance for Grunt enemies
@export var grunt_piercability: float = 1.0

@export_group("Grunt Appearance")
## Color for Grunt enemies
@export var grunt_color: Color = Color.ORANGE_RED
## Size scale for Grunt enemies
@export var grunt_size_scale: float = 1.0

@export_group("Grunt Behavior")
## Movement behavior type for Grunt enemies
@export var grunt_movement_behavior: MovementBehavior.Type = MovementBehavior.Type.CHASE
## Attack behavior type for Grunt enemies
@export var grunt_attack_behavior: AttackBehavior.Type = AttackBehavior.Type.MELEE

func _ready():
	# Configure as melee chaser using exported values
	max_health = grunt_health
	movement_speed = grunt_movement_speed
	detection_range = grunt_detection_range
	attack_range = grunt_attack_range
	turn_speed = grunt_turn_speed
	piercability = grunt_piercability
	
	# Set behaviors
	movement_behavior_type = grunt_movement_behavior
	attack_behavior_type = grunt_attack_behavior
	
	# Appearance
	enemy_color = grunt_color
	size_scale = grunt_size_scale
	
	# Call parent ready
	super()
