extends BaseEnemy
class_name Sniper

# === SNIPER ENEMY ===
# Long-range enemy that maintains distance and charges powerful shots
# Role: Tests positioning, cover usage, and patience

## === SNIPER CONFIGURATION ===
@export_group("Sniper Stats")
## Health points for Sniper enemies
@export var sniper_health: int = 60
## Movement speed for Sniper enemies
@export var sniper_movement_speed: float = 3.0
## Detection range for Sniper enemies (unlimited by default)
@export var sniper_detection_range: float = 999.0
## Attack range for Sniper enemies (unlimited by default)
@export var sniper_attack_range: float = 999.0
## Rotation speed for Sniper enemies
@export var sniper_turn_speed: float = 3.0
## Piercing resistance for Sniper enemies (low - easy to pierce)
@export var sniper_piercability: float = 0.5

@export_group("Sniper Appearance")
## Color for Sniper enemies
@export var sniper_color: Color = Color.BLUE
## Size scale for Sniper enemies
@export var sniper_size_scale: float = 0.8

@export_group("Sniper Behavior")
## Movement behavior type for Sniper enemies
@export var sniper_movement_behavior: MovementBehavior.Type = MovementBehavior.Type.KEEP_DISTANCE
## Attack behavior type for Sniper enemies
@export var sniper_attack_behavior: AttackBehavior.Type = AttackBehavior.Type.CHARGED

func _ready():
	# Configure as long-range marksman using exported values
	max_health = sniper_health
	movement_speed = sniper_movement_speed
	detection_range = sniper_detection_range
	attack_range = sniper_attack_range
	turn_speed = sniper_turn_speed
	piercability = sniper_piercability
	
	# Set behaviors
	movement_behavior_type = sniper_movement_behavior
	attack_behavior_type = sniper_attack_behavior
	
	# Appearance
	enemy_color = sniper_color
	size_scale = sniper_size_scale
	
	# Call parent ready
	super()
