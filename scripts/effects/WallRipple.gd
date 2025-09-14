extends Node3D

# === WALL RIPPLE EFFECT ===
# Creates expanding rings on wall/ground impacts

@export_group("Animation Settings")
@export var ring1_max_scale: float = 1.0
@export var ring1_duration: float = 0.4
@export var ring1_start_alpha: float = 0.3
@export var ring1_start_y_scale: float = 0.1
@export var ring1_max_y_scale: float = 1.0

@export var ring2_max_scale: float = 0.8
@export var ring2_duration: float = 0.6
@export var ring2_start_alpha: float = 0.6
@export var ring2_delay: float = 0.1  # Delay before ring2 starts
@export var ring2_start_y_scale: float = 0.1
@export var ring2_max_y_scale: float = 0.8

@export var ring3_max_scale: float = 0.6
@export var ring3_duration: float = 0.8
@export var ring3_start_alpha: float = 1.0
@export var ring3_delay: float = 0.2  # Delay before ring3 starts
@export var ring3_start_y_scale: float = 0.1
@export var ring3_max_y_scale: float = 0.6

@export var base_ring_scale: float = 0.1  # Starting scale for all rings

@export_group("Animation Phases")
## Progress ratio for explosion expand phase
@export var explosion_expand_phase_ratio: float = 0.33
## Progress ratio for explosion fade phase
@export var explosion_fade_phase_ratio: float = 0.34
## Progress ratio for explosion scale down phase
@export var explosion_scale_down_phase_ratio: float = 0.33
## Progress ratio for impact scale up phase
@export var impact_scale_up_phase_ratio: float = 0.21
## Progress ratio for impact scale down phase
@export var impact_scale_down_phase_ratio: float = 0.79

@export_group("Effect Properties")
## Default explosion duration
@export var default_explosion_duration: float = 0.6
## Default impact duration
@export var default_impact_duration: float = 0.7
## Impact emission energy
@export var impact_emission_energy: float = 8.0
## Explosion emission energy
@export var explosion_emission_energy: float = 5.0
## Impact scale multiplier (scales from 1.0 to this value)
@export var impact_max_scale_multiplier: float = 2.0
## Explosion sphere radius multiplier
@export var explosion_radius_multiplier: float = 0.3
## Explosion sphere height multiplier
@export var explosion_height_multiplier: float = 0.6

@export_group("Debug Settings")
## Enable debug output for ripple animation events
@export var debug_animation: bool = false
## Enable debug output for setup and positioning
@export var debug_setup: bool = false

# Ring references (assigned from scene)
@onready var ring1: MeshInstance3D = $Ring1
@onready var ring2: MeshInstance3D = $Ring2
@onready var ring3: MeshInstance3D = $Ring3

## === RUNTIME STATE ===
# Animation data
var animation_data: Array[Dictionary] = []
var time_manager: Node

func _ready():
	# Connect to time manager
	time_manager = get_node_or_null("/root/TimeManager")
	
	# Initialize ring materials and scales
	_setup_rings()
	
	# Start the ripple animation
	_start_ripple_animation()

func _setup_rings():
	"""Initialize ring scales and materials."""
	var rings = [
		{"node": ring1, "start_alpha": ring1_start_alpha, "start_y_scale": ring1_start_y_scale},
		{"node": ring2, "start_alpha": ring2_start_alpha, "start_y_scale": ring2_start_y_scale},
		{"node": ring3, "start_alpha": ring3_start_alpha, "start_y_scale": ring3_start_y_scale}
	]
	
	for ring_data in rings:
		var ring = ring_data.node
		var start_alpha = ring_data.start_alpha
		var start_y_scale = ring_data.start_y_scale
		
		if not ring:
			continue
			
		# Set initial scale (X, Y, and Z axes with independent Y scaling)
		ring.scale = Vector3(base_ring_scale, start_y_scale, base_ring_scale)
		
		# Set up material with initial alpha
		if ring.material_override and ring.material_override is StandardMaterial3D:
			var material = ring.material_override as StandardMaterial3D
			material.albedo_color.a = start_alpha
		elif ring.get_surface_override_material(0) and ring.get_surface_override_material(0) is StandardMaterial3D:
			var material = ring.get_surface_override_material(0) as StandardMaterial3D
			material.albedo_color.a = start_alpha

func _start_ripple_animation():
	"""Start the ripple animation for all rings with delays."""
	animation_data = [
		{
			"ring": ring1,
			"elapsed": 0.0,
			"duration": ring1_duration,
			"max_scale": ring1_max_scale,
			"start_alpha": ring1_start_alpha,
			"start_y_scale": ring1_start_y_scale,
			"max_y_scale": ring1_max_y_scale,
			"delay": 0.0,  # Ring1 starts immediately
			"started": false
		},
		{
			"ring": ring2,
			"elapsed": 0.0,
			"duration": ring2_duration,
			"max_scale": ring2_max_scale,
			"start_alpha": ring2_start_alpha,
			"start_y_scale": ring2_start_y_scale,
			"max_y_scale": ring2_max_y_scale,
			"delay": ring2_delay,
			"started": false
		},
		{
			"ring": ring3,
			"elapsed": 0.0,
			"duration": ring3_duration,
			"max_scale": ring3_max_scale,
			"start_alpha": ring3_start_alpha,
			"start_y_scale": ring3_start_y_scale,
			"max_y_scale": ring3_max_y_scale,
			"delay": ring3_delay,
			"started": false
		}
	]
	
	# Start ring1 immediately (it has no delay)
	_start_ring_animation(animation_data[0])
	
	if debug_animation:
		print("Wall ripple animation started")

func _start_ring_animation(ring_data: Dictionary):
	"""Start animation for a specific ring."""
	var ring = ring_data.ring
	if ring:
		ring.visible = true
		if debug_animation:
			print("Started ring animation: ", ring.name)

func _process(delta: float):
	"""Update ripple animation."""
	if animation_data.is_empty():
		return
	
	# Get time-adjusted delta for consistent animation during time dilation
	var effective_delta = delta
	if time_manager:
		effective_delta = time_manager.get_effective_delta(delta, 0.0)
	
	var rings_to_remove: Array[int] = []
	
	for i in range(animation_data.size()):
		var ring_data = animation_data[i]
		
		# Check if ring should start (delay has passed)
		if not ring_data.started:
			ring_data.elapsed += effective_delta
			if ring_data.elapsed >= ring_data.delay:
				_start_ring_animation(ring_data)
				ring_data.started = true
				ring_data.elapsed = 0.0  # Reset elapsed for actual animation
		else:
			# Ring is running, update its animation
			if _update_ring_animation(ring_data, effective_delta):
				rings_to_remove.append(i)
	
	# Remove completed rings (in reverse order)
	for i in range(rings_to_remove.size() - 1, -1, -1):
		animation_data.remove_at(rings_to_remove[i])
	
	# If all rings are done, remove the effect
	if animation_data.is_empty():
		queue_free()

func _update_ring_animation(ring_data: Dictionary, delta: float) -> bool:
	"""Update a single ring animation. Returns true if animation is complete."""
	var ring = ring_data.get("ring")
	var elapsed = ring_data.get("elapsed", 0.0)
	var duration = ring_data.get("duration", 1.0)
	var max_scale = ring_data.get("max_scale", 1.0)
	var start_alpha = ring_data.get("start_alpha", 1.0)
	var start_y_scale = ring_data.get("start_y_scale", 0.1)
	var max_y_scale = ring_data.get("max_y_scale", 1.0)
	
	if not ring or not is_instance_valid(ring):
		return true  # Remove invalid rings
	
	# Update elapsed time
	elapsed += delta
	ring_data["elapsed"] = elapsed
	
	# Calculate progress
	var progress = elapsed / duration
	
	if progress >= 1.0:
		# Animation complete - hide ring
		ring.visible = false
		return true
	
	# Update scale (ease out for natural expansion)
	var scale_progress = 1.0 - pow(1.0 - progress, 2.0)  # Ease out curve
	var current_scale = base_ring_scale + (max_scale - base_ring_scale) * scale_progress
	var current_y_scale = start_y_scale + (max_y_scale - start_y_scale) * scale_progress
	ring.scale = Vector3(current_scale, current_y_scale, current_scale)
	
	# Keep alpha solid - no fade animation
	# Alpha remains at the start_alpha value set during initialization
	
	return false

func setup_ripple(impact_position: Vector3, surface_normal: Vector3):
	"""Setup the ripple at the impact position with correct orientation."""
	# Position at impact point
	global_position = impact_position
	
	# Orient along surface normal
	if surface_normal.length() > 0.01:
		# Create a basis where Y points along the surface normal
		var up = surface_normal.normalized()
		
		# Choose an arbitrary right vector that's perpendicular to up
		var right = Vector3.RIGHT
		if abs(up.dot(right)) > 0.9:
			right = Vector3.FORWARD
		
		# Make right perpendicular to up
		right = (right - up * up.dot(right)).normalized()
		var forward = right.cross(up).normalized()
		
		# Create the basis and apply it
		global_transform.basis = Basis(right, up, forward)
	
	if debug_setup:
		print("Wall ripple setup at: ", impact_position, " normal: ", surface_normal)
