extends BaseEnemy
class_name Grunt

# === GRUNT ENEMY ===
# Basic melee enemy that chases the player relentlessly
# Role: Tests basic movement and close combat awareness

func _ready():
	# Configure as melee chaser
	max_health = 80
	movement_speed = 6.0
	detection_range = 15.0
	attack_range = 3.0
	turn_speed = 15.0  # Faster rotation to keep up with direction changes
	
	# Set behaviors
	movement_behavior_type = MovementBehavior.Type.CHASE
	attack_behavior_type = AttackBehavior.Type.MELEE
	
	# Appearance
	enemy_color = Color.ORANGE_RED
	size_scale = 1.0
	
	# Piercing resistance
	piercability = 1.0  # Standard piercability
	
	# Call parent ready
	super()
