extends RigidBody3D

@export var speed: float = 40.0
@export var lifetime: float = 2.0

var life_timer: float = 0.0

func _ready():
	# Optional: set initial velocity if not set externally
	pass

func _physics_process(delta):
	life_timer += delta
	if life_timer > lifetime:
		queue_free()

func fire(direction: Vector3):
	linear_velocity = direction.normalized() * speed
