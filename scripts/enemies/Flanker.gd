extends BaseEnemy
class_name Flanker

# === FLANKER ENEMY ===
# Tactical enemy that tries to get behind the player for burst attacks
# Role: Tests situational awareness and positioning

func _ready():
	# Configure as tactical flanker
	max_health = 70
	movement_speed = 7.0
	detection_range = 18.0
	attack_range = 12.0
	turn_speed = 8.0
	
	# Set behaviors
	movement_behavior_type = MovementBehavior.Type.FLANKING
	attack_behavior_type = AttackBehavior.Type.BURST
	
	# Appearance
	enemy_color = Color.PURPLE
	size_scale = 0.9
	
	# Call parent ready
	super()
