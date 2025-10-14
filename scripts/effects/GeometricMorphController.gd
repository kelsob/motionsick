extends MeshInstance3D

# === GEOMETRIC MORPH CONTROLLER ===
# Controls shader parameters to create procedural geometric morphing
# Standalone system for testing "geometric horror" visuals

## === CONFIGURATION ===
@export_group("Morph Animation")
@export var enable_morphing: bool = true
@export var morph_speed: float = 1.0  # Overall animation speed multiplier

@export_group("Face Expansion Animation")
@export var enable_face_expansion: bool = true
@export var expansion_min: float = -0.5
@export var expansion_max: float = 0.5
@export var expansion_frequency: float = 0.3  # Hz

@export_group("Twist Animation")
@export var enable_twist: bool = true
@export var twist_min: float = -1.0
@export var twist_max: float = 1.0
@export var twist_frequency: float = 0.2

@export_group("Pulse Animation")
@export var enable_pulse: bool = true
@export var pulse_min: float = 0.8
@export var pulse_max: float = 1.2
@export var pulse_frequency: float = 0.5

@export_group("Rotation Animation")
@export var enable_rotation: bool = true
@export var rotation_speed: float = 0.5  # Radians per second
@export var change_rotation_axis: bool = true
@export var axis_change_interval: float = 3.0  # Seconds between axis changes

@export_group("Noise Animation")
@export var enable_noise_animation: bool = true
@export var noise_scroll_speed: Vector3 = Vector3(0.1, 0.05, 0.08)

@export_group("Morph Intensity")
@export var enable_intensity_pulse: bool = true
@export var intensity_min: float = 0.3
@export var intensity_max: float = 0.8
@export var intensity_frequency: float = 0.15

@export_group("Debug")
@export var debug_output: bool = false

## === RUNTIME STATE ===
var shader_material: ShaderMaterial = null
var time_accumulator: float = 0.0
var axis_change_timer: float = 0.0
var current_target_axis: Vector3 = Vector3.UP
var current_axis: Vector3 = Vector3.UP

func _ready():
	# Get the shader material
	if get_surface_override_material_count() > 0:
		shader_material = get_surface_override_material(0)
	else:
		shader_material = get_active_material(0)
	
	if not shader_material or not shader_material is ShaderMaterial:
		push_error("GeometricMorphController: No ShaderMaterial found on mesh!")
		set_process(false)
		return
	
	if debug_output:
		print("GeometricMorphController: Initialized on ", name)
	
	# Initialize random axis
	_generate_new_rotation_axis()

func _process(delta: float):
	if not enable_morphing or not shader_material:
		return
	
	time_accumulator += delta * morph_speed
	
	# === MORPH INTENSITY ===
	if enable_intensity_pulse:
		var intensity = lerp(intensity_min, intensity_max, 
			(sin(time_accumulator * intensity_frequency * TAU) + 1.0) * 0.5)
		shader_material.set_shader_parameter("morph_intensity", intensity)
	
	# === FACE EXPANSION ===
	if enable_face_expansion:
		var expansion = lerp(expansion_min, expansion_max,
			(sin(time_accumulator * expansion_frequency * TAU) + 1.0) * 0.5)
		shader_material.set_shader_parameter("face_expansion", expansion)
	
	# === TWIST ===
	if enable_twist:
		var twist = lerp(twist_min, twist_max,
			(sin(time_accumulator * twist_frequency * TAU + 1.5) + 1.0) * 0.5)
		shader_material.set_shader_parameter("twist_amount", twist)
	
	# === PULSE ===
	if enable_pulse:
		var pulse = lerp(pulse_min, pulse_max,
			(sin(time_accumulator * pulse_frequency * TAU + 3.0) + 1.0) * 0.5)
		shader_material.set_shader_parameter("pulse_scale", pulse)
	
	# === ROTATION ===
	if enable_rotation:
		var rotation_angle = fmod(time_accumulator * rotation_speed, TAU)
		shader_material.set_shader_parameter("rotation_angle", rotation_angle)
		
		# Change rotation axis periodically
		if change_rotation_axis:
			axis_change_timer += delta
			if axis_change_timer >= axis_change_interval:
				axis_change_timer = 0.0
				_generate_new_rotation_axis()
			
			# Smoothly interpolate to new axis
			current_axis = current_axis.lerp(current_target_axis, delta * 0.5)
			shader_material.set_shader_parameter("rotation_axis", current_axis.normalized())
	
	# === NOISE ANIMATION ===
	if enable_noise_animation:
		var noise_offset = noise_scroll_speed * time_accumulator
		shader_material.set_shader_parameter("noise_offset", noise_offset)

func _generate_new_rotation_axis():
	"""Generate a new random rotation axis."""
	# Create interesting axes (not just cardinal directions)
	var rand_choice = randi() % 6
	match rand_choice:
		0: current_target_axis = Vector3(1, 0, 0)
		1: current_target_axis = Vector3(0, 1, 0)
		2: current_target_axis = Vector3(0, 0, 1)
		3: current_target_axis = Vector3(1, 1, 0).normalized()
		4: current_target_axis = Vector3(1, 0, 1).normalized()
		5: current_target_axis = Vector3(0, 1, 1).normalized()
	
	if debug_output:
		print("GeometricMorphController: New rotation axis: ", current_target_axis)

# === PUBLIC API ===

func set_morph_speed(speed: float):
	"""Change overall animation speed."""
	morph_speed = speed

func trigger_morph_burst():
	"""Temporarily increase morph intensity."""
	var tween = create_tween()
	tween.tween_method(_set_intensity, intensity_max, intensity_min, 1.0)

func _set_intensity(value: float):
	if shader_material:
		shader_material.set_shader_parameter("morph_intensity", value)

func randomize_state():
	"""Randomize all animation phases."""
	time_accumulator = randf() * 100.0
	_generate_new_rotation_axis()
	current_axis = current_target_axis
