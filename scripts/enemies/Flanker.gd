extends BaseEnemy
class_name Flanker

# === FLANKER ENEMY ===
# Tactical enemy that tries to get behind the player for burst attacks
# Role: Tests situational awareness and positioning

## === FLANKER CONFIGURATION ===
@export_group("Flanker Stats")
## Health points for Flanker enemies
@export var flanker_health: int = 70
## Movement speed for Flanker enemies
@export var flanker_movement_speed: float = 7.0
## Detection range for Flanker enemies
@export var flanker_detection_range: float = 18.0
## Attack range for Flanker enemies
@export var flanker_attack_range: float = 12.0
## Rotation speed for Flanker enemies
@export var flanker_turn_speed: float = 8.0
## Piercing resistance for Flanker enemies (standard)
@export var flanker_piercability: float = 1.0

@export_group("Flanker Appearance")
## Color for Flanker enemies
@export var flanker_color: Color = Color.PURPLE
## Size scale for Flanker enemies
@export var flanker_size_scale: float = 0.9

@export_group("Flanker Behavior")
## Movement behavior type for Flanker enemies
@export var flanker_movement_behavior: MovementBehavior.Type = MovementBehavior.Type.FLANKING
## Attack behavior type for Flanker enemies
@export var flanker_attack_behavior: AttackBehavior.Type = AttackBehavior.Type.BURST

func _ready():
	# Configure as tactical flanker using exported values
	max_health = flanker_health
	movement_speed = flanker_movement_speed
	detection_range = flanker_detection_range
	attack_range = flanker_attack_range
	turn_speed = flanker_turn_speed
	piercability = flanker_piercability
	
	# Set behaviors
	movement_behavior_type = flanker_movement_behavior
	attack_behavior_type = flanker_attack_behavior
	
	# Appearance
	enemy_color = flanker_color
	size_scale = flanker_size_scale
	
	# Call parent ready
	super()
