extends Node3D
class_name GunfireTelegraph

# === GUNFIRE TELEGRAPH EFFECT ===
# Warning ring that shrinks and thickens before enemy gunfire

# === CONFIGURATION ===
@export var telegraph_duration: float = 3.0  # How long before gunfire (increased for testing)
@export var start_outer_radius: float = 4.0  # Initial outer ring distance (HUGE for testing)
@export var start_inner_radius: float = 3.9  # Initial inner ring distance (thin)
@export var end_outer_radius: float = 0.5  # Final outer ring distance (bigger)
@export var end_inner_radius: float = 0.2  # Final inner ring distance (thick)
@export var telegraph_color: Color = Color.ORANGE  # Warning color

# === STATE ===
var time_elapsed: float = 0.0
var time_manager: Node = null
var is_active: bool = false

# === FOLLOW TARGET === (Not needed - telegraph is child of enemy)
# var follow_target: Node3D = null
# var follow_offset: Vector3 = Vector3.ZERO

# === COMPONENTS ===
@onready var ring_mesh: MeshInstance3D = $RingMesh
var torus_mesh: TorusMesh
var material: StandardMaterial3D

# === SIGNALS ===
signal telegraph_completed()

func _ready():
	# Connect to time manager
	time_manager = get_node_or_null("/root/TimeManager")
	
	# Get references to mesh and material
	if ring_mesh and ring_mesh.mesh:
		torus_mesh = ring_mesh.mesh as TorusMesh
		material = ring_mesh.material_override as StandardMaterial3D
		
		if not material:
			material = ring_mesh.get_surface_override_material(0) as StandardMaterial3D
	
	# Set initial state - invisible and large/thin
	if torus_mesh:
		torus_mesh.outer_radius = start_outer_radius
		torus_mesh.inner_radius = start_inner_radius
	
	if material:
		material.albedo_color = telegraph_color
		material.albedo_color.a = 0.0  # Start invisible
		material.emission = telegraph_color

func start_telegraph():
	"""Begin the gunfire telegraph effect."""
	is_active = true
	time_elapsed = 0.0
	print("Starting gunfire telegraph - active: ", is_active)
	
	# Reset to starting state
	if torus_mesh:
		torus_mesh.outer_radius = start_outer_radius
		torus_mesh.inner_radius = start_inner_radius
		print("Torus configured: outer=", start_outer_radius, " inner=", start_inner_radius)
	else:
		print("ERROR: No torus mesh found!")
	
	if material:
		material.albedo_color.a = 0.0
		print("Material alpha set to 0, color: ", material.albedo_color)
	else:
		print("ERROR: No material found!")

func _process(delta: float):
	if not is_active:
		return
	
	# No need to follow target - telegraph is child of enemy so inherits position/rotation
	
	# Use time-adjusted delta to respect time scale
	var time_delta = delta
	if time_manager:
		var time_scale = time_manager.get_time_scale()
		time_delta = delta * time_scale
	
	time_elapsed += time_delta
	
	# Calculate progress (0.0 to 1.0)
	var progress = time_elapsed / telegraph_duration
	progress = clamp(progress, 0.0, 1.0)
	
	# Debug first few frames
	if progress < 0.1:
		print("Telegraph progress: ", progress, " time_elapsed: ", time_elapsed)
	
	# Ease-in curve for dramatic effect
	var eased_progress = progress * progress
	
	# Update ring size (shrinks and thickens)
	var current_outer_radius = lerp(start_outer_radius, end_outer_radius, eased_progress)
	var current_inner_radius = lerp(start_inner_radius, end_inner_radius, eased_progress)
	
	if torus_mesh:
		torus_mesh.outer_radius = current_outer_radius
		torus_mesh.inner_radius = current_inner_radius
	
	# Update visibility (fades in quickly, then pulses)
	var alpha = 0.0
	if progress < 0.3:
		# Fade in quickly
		alpha = progress / 0.3
	else:
		# Pulse rapidly as it gets close
		var pulse_speed = 15.0 + (progress * 20.0)  # Speed up pulse
		alpha = 0.7 + 0.3 * sin(time_elapsed * pulse_speed)
	
	if material:
		var old_alpha = material.albedo_color.a
		material.albedo_color.a = alpha * 0.8  # Max 80% opacity
		# Debug alpha changes
		if abs(material.albedo_color.a - old_alpha) > 0.1:
			print("Alpha updated: ", material.albedo_color.a, " progress: ", progress)
	
	# Check if telegraph is complete
	if progress >= 1.0:
		print("Telegraph completing!")
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

func set_follow_target(target: Node3D, offset: Vector3 = Vector3.UP * 0.5):
	"""DEPRECATED: No longer needed since telegraph is child of enemy."""
	print("Telegraph follow target call ignored - using parent-child relationship instead")

func set_ring_size(start_outer: float, start_inner: float, end_outer: float, end_inner: float):
	"""Configure the ring's starting and ending radii."""
	start_outer_radius = start_outer
	start_inner_radius = start_inner
	end_outer_radius = end_outer
	end_inner_radius = end_inner

func cancel_telegraph():
	"""Cancel the telegraph effect early."""
	is_active = false
	queue_free()
