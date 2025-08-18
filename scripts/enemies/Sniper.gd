extends BaseEnemy
class_name Sniper

# === SNIPER ENEMY ===
# Long-range enemy that maintains distance and charges powerful shots
# Role: Tests positioning, cover usage, and patience

func _ready():
	# Configure as long-range marksman
	max_health = 60
	movement_speed = 3.0
	detection_range = 25.0
	attack_range = 20.0
	turn_speed = 3.0
	
	# Set behaviors
	movement_behavior_type = MovementBehavior.Type.KEEP_DISTANCE
	attack_behavior_type = AttackBehavior.Type.CHARGED
	
	# Appearance
	enemy_color = Color.BLUE
	size_scale = 0.8
	
	# Piercing resistance
	piercability = 0.5  # Low piercability - easy to pierce through
	
	# Call parent ready
	super()
