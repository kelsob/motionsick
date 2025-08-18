extends BaseEnemy
class_name Artillery

# === ARTILLERY ENEMY ===
# Heavy enemy that circles the player and fires explosive projectiles
# Role: Tests area denial, dodging, and sustained combat

func _ready():
	# Configure as heavy artillery
	max_health = 120
	movement_speed = 4.0
	detection_range = 22.0
	attack_range = 18.0
	turn_speed = 2.0
	
	# Set behaviors
	movement_behavior_type = MovementBehavior.Type.CIRCLING
	attack_behavior_type = AttackBehavior.Type.EXPLOSIVE
	
	# Appearance
	enemy_color = Color.DARK_GREEN
	size_scale = 1.3
	
	# Piercing resistance
	piercability = 2.0  # High piercability - hard to pierce through
	
	# Call parent ready
	super()
