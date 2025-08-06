extends BaseEnemy
class_name Rusher

# === RUSHER ENEMY ===
# Fast, aggressive enemy that rapidly closes distance while firing
# Role: Tests reaction time and movement under pressure

func _ready():
	# Configure as fast aggressive attacker
	max_health = 50
	movement_speed = 10.0
	detection_range = 20.0
	attack_range = 15.0
	turn_speed = 10.0
	
	# Set behaviors
	movement_behavior_type = MovementBehavior.Type.CHASE
	attack_behavior_type = AttackBehavior.Type.RANGED
	
	# Appearance
	enemy_color = Color.YELLOW
	size_scale = 1.1
	
	# Call parent ready
	super()