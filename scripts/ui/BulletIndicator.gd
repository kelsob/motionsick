extends Control
class_name BulletIndicator

# === BULLET INDICATOR SYSTEM ===
# Individual bullet indicator - you assign the bullet texture in the inspector

@onready var bullet = $Bullet

func _ready():
	# Initialize bullet as empty (not visible)
	set_bullet_visible(false)

func set_bullet_visible(visible: bool):
	"""Set whether the bullet is visible or not."""
	bullet.visible = visible
