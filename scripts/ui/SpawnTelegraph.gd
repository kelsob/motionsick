extends Node3D
class_name SpawnTelegraph

# === SPAWN TELEGRAPH EFFECT ===
# Visual warning that grows before enemy spawns

# === CONFIGURATION ===
@export var telegraph_duration: float = 3.0  # How long before spawn
@export var max_scale: float = 2.0  # Maximum size of effect
@export var telegraph_color: Color = Color.RED  # Color of warning effect

# === STATE ===
var time_elapsed: float = 0.0
var time_manager: Node = null
var is_active: bool = false

# === COMPONENTS ===
@onready var mesh_instance: MeshInstance3D
@onready var material: StandardMaterial3D

# === SIGNALS ===
signal telegraph_completed()

func _ready():
	# Connect to time manager
	time_manager = get_node_or_null("/root/TimeManager")
	
	# Create visual effect - simple sphere that grows
	mesh_instance = MeshInstance3D.new()
	add_child(mesh_instance)
	
	# Create mesh
	var sphere_mesh = SphereMesh.new()
	sphere_mesh.radius = 0.5
	sphere_mesh.height = 1.0
	mesh_instance.mesh = sphere_mesh
	
	# Create glowing material
	material = StandardMaterial3D.new()
	material.albedo_color = telegraph_color
	material.emission_enabled = true
	material.emission = telegraph_color
	material.emission_energy = 2.0
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.no_depth_test = true  # Always visible
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh_instance.material_override = material
	
	# Start invisible
	scale = Vector3.ZERO
	material.albedo_color.a = 0.0

func start_telegraph():
	"""Begin the spawn telegraph effect."""
	is_active = true
	time_elapsed = 0.0
	scale = Vector3.ZERO

func _process(delta: float):
	if not is_active:
		return
	
	# Use time-adjusted delta to respect time scale
	var time_delta = delta
	if time_manager:
		var time_scale = time_manager.get_time_scale()
		time_delta = delta * time_scale
	
	time_elapsed += time_delta
	
	# Calculate progress (0.0 to 1.0)
	var progress = time_elapsed / telegraph_duration
	progress = clamp(progress, 0.0, 1.0)
	
	# Update scale - grows from 0 to max_scale
	var current_scale = progress * max_scale
	scale = Vector3.ONE * current_scale
	
	# Update alpha - fades in then pulses
	var alpha = sin(progress * PI)  # Smooth fade in/out curve
	if progress > 0.7:  # Pulse faster near the end
		alpha *= (0.5 + 0.5 * sin(time_elapsed * 10.0))
	
	material.albedo_color.a = alpha * 0.7  # Max 70% opacity
	
	# Check if telegraph is complete
	if progress >= 1.0:
		_complete_telegraph()

func _complete_telegraph():
	"""Called when telegraph duration is finished."""
	is_active = false
	telegraph_completed.emit()
	queue_free()

func set_telegraph_color(color: Color):
	"""Change the color of the telegraph effect."""
	telegraph_color = color
	if material:
		material.albedo_color = color
		material.emission = color

func set_telegraph_duration(duration: float):
	"""Change how long the telegraph lasts."""
	telegraph_duration = max(0.1, duration)

func cancel_telegraph():
	"""Cancel the telegraph effect early."""
	is_active = false
	queue_free()
