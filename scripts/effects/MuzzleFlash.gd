extends Node3D
class_name MuzzleFlash

## === MUZZLE FLASH EFFECT ===
## Handles animated muzzle flash with lighting, particles, and distortion
## Auto-plays on instantiation and cleans up when complete

## === CONFIGURATION ===
@export_group("Animation Timing")
## Total duration of the muzzle flash effect
@export var total_duration: float = 0.15
## Duration of the growth phase (percentage of total)
@export var grow_phase_ratio: float = 0.3
## Duration of the hold phase (percentage of total)
@export var hold_phase_ratio: float = 0.2

@export_group("Light Animation")
## Peak light intensity
@export var max_light_energy: float = 5.0
## Light color at peak
@export var light_color: Color = Color.ORANGE
## Light attenuation curve
@export var light_attenuation: float = 2.0

@export_group("Distortion Animation")
## Maximum scale for distortion sphere
@export var max_distortion_scale: float = 1.5
## Minimum scale for distortion sphere
@export var min_distortion_scale: float = 0.3

@export_group("Time System")
## Whether this effect should respect time scale (true = affected by slow-mo)
@export var respect_time_scale: bool = true

@export_group("Debug")
@export var debug_output: bool = false

## === COMPONENTS ===
## NOTE: For better time-scale control, consider using CPUParticles3D instead of GPUParticles3D
## GPUParticles3D speed_scale affects emission but already-emitted particles maintain velocity
@onready var light: OmniLight3D = $OmniLight3D if has_node("OmniLight3D") else null
@onready var particles: GPUParticles3D = $GPUParticles3D if has_node("GPUParticles3D") else null
@onready var cpu_particles: CPUParticles3D = $CPUParticles3D if has_node("CPUParticles3D") else null
@onready var distortion_mesh: MeshInstance3D = $DistortionMesh if has_node("DistortionMesh") else null

## === STATE ===
var elapsed_time: float = 0.0
var time_manager: Node = null
var is_complete: bool = false

func _ready():
	print("MuzzleFlash: _ready() called")
	print("  Position: ", global_position)
	print("  Rotation: ", global_rotation)
	
	# Get TimeManager reference
	time_manager = get_node_or_null("/root/TimeManager")
	if time_manager:
		print("  TimeManager found")
	else:
		print("  WARNING: TimeManager not found")
	
	# Initialize components
	print("  Initializing components...")
	_initialize_light()
	_initialize_particles()
	_initialize_distortion()
	
	# Start the effect
	_start_effect()
	print("  MuzzleFlash effect started!")

func _process(delta: float):
	if is_complete:
		return
	
	# Get time-adjusted delta
	var adjusted_delta = delta
	if respect_time_scale and time_manager:
		adjusted_delta = time_manager.get_effective_delta(delta, 0.0)
		
		# CRITICAL: Update particle speed scale every frame to match current time scale
		var current_time_scale = time_manager.get_time_scale() if time_manager.has_method("get_time_scale") else 1.0
		if particles:
			particles.speed_scale = current_time_scale
		if cpu_particles:
			cpu_particles.speed_scale = current_time_scale
	
	# Update animation
	elapsed_time += adjusted_delta
	var progress = elapsed_time / total_duration
	
	if progress >= 1.0:
		_complete_effect()
		return
	
	# Update all animation components
	_update_light_animation(progress)
	_update_distortion_animation(progress)

func _initialize_light():
	"""Setup initial light properties."""
	if not light:
		print("MuzzleFlash: WARNING - No OmniLight3D found in scene!")
		print("  Make sure you have an OmniLight3D node as a child")
		return
	
	print("  Light found: ", light.name)
	light.light_energy = 0.0
	light.light_color = light_color
	light.omni_attenuation = light_attenuation
	print("  Light initialized (energy=0, color=", light_color, ")")

func _initialize_particles():
	"""Setup and trigger particle emission (supports both GPU and CPU particles)."""
	var has_particles = false
	
	# Initialize GPU particles if present
	if particles:
		print("  GPU Particles found: ", particles.name)
		has_particles = true
		
		# Set particle time scale if respecting time dilation
		if respect_time_scale and time_manager:
			particles.speed_scale = time_manager.get_time_scale()
			print("  GPU Particles using time scale: ", particles.speed_scale)
		else:
			particles.speed_scale = 1.0
			print("  GPU Particles using normal speed")
		
		# Emit particles immediately
		particles.emitting = true
		particles.one_shot = true
		print("  GPU Particles triggered (emitting=true)")
	
	# Initialize CPU particles if present
	if cpu_particles:
		print("  CPU Particles found: ", cpu_particles.name)
		has_particles = true
		
		# Set particle time scale if respecting time dilation
		if respect_time_scale and time_manager:
			cpu_particles.speed_scale = time_manager.get_time_scale()
			print("  CPU Particles using time scale: ", cpu_particles.speed_scale)
		else:
			cpu_particles.speed_scale = 1.0
			print("  CPU Particles using normal speed")
		
		# Emit particles immediately
		cpu_particles.emitting = true
		cpu_particles.one_shot = true
		print("  CPU Particles triggered (emitting=true)")
	
	if not has_particles:
		print("MuzzleFlash: WARNING - No GPUParticles3D or CPUParticles3D found in scene!")
		print("  Add a GPUParticles3D or CPUParticles3D node as a child for particle effects")

func _initialize_distortion():
	"""Setup initial distortion mesh properties."""
	if not distortion_mesh:
		print("MuzzleFlash: WARNING - No DistortionMesh found in scene!")
		print("  Make sure you have a MeshInstance3D node named 'DistortionMesh' as a child")
		return
	
	print("  Distortion mesh found: ", distortion_mesh.name)
	distortion_mesh.scale = Vector3.ONE * min_distortion_scale
	print("  Distortion initialized (scale=", min_distortion_scale, ")")

func _start_effect():
	"""Begin the muzzle flash effect."""
	elapsed_time = 0.0
	is_complete = false

func _update_light_animation(progress: float):
	"""Animate light intensity over time."""
	if not light:
		return
	
	var energy: float
	
	# Three-phase animation: grow -> hold -> fade
	if progress < grow_phase_ratio:
		# Growing phase: 0 -> max
		var grow_progress = progress / grow_phase_ratio
		energy = grow_progress * max_light_energy
	elif progress < grow_phase_ratio + hold_phase_ratio:
		# Hold phase: max
		energy = max_light_energy
	else:
		# Fade phase: max -> 0
		var fade_start = grow_phase_ratio + hold_phase_ratio
		var fade_progress = (progress - fade_start) / (1.0 - fade_start)
		energy = max_light_energy * (1.0 - fade_progress)
	
	light.light_energy = energy

func _update_distortion_animation(progress: float):
	"""Animate distortion mesh scale over time."""
	if not distortion_mesh:
		return
	
	var scale_value: float
	
	# Three-phase animation matching light
	if progress < grow_phase_ratio:
		# Growing phase
		var grow_progress = progress / grow_phase_ratio
		scale_value = min_distortion_scale + (max_distortion_scale - min_distortion_scale) * grow_progress
	elif progress < grow_phase_ratio + hold_phase_ratio:
		# Hold phase
		scale_value = max_distortion_scale
	else:
		# Shrink phase
		var fade_start = grow_phase_ratio + hold_phase_ratio
		var fade_progress = (progress - fade_start) / (1.0 - fade_start)
		scale_value = max_distortion_scale - (max_distortion_scale - min_distortion_scale) * fade_progress
	
	distortion_mesh.scale = Vector3.ONE * scale_value

func _complete_effect():
	"""Clean up and remove the effect."""
	is_complete = true
	
	print("MuzzleFlash: Effect complete after ", elapsed_time, " seconds, cleaning up")
	
	# Queue for deletion
	queue_free()

## === PUBLIC API ===

func set_time_scale_respect(enabled: bool):
	"""Enable or disable time scale respect at runtime."""
	respect_time_scale = enabled
	
	# Update particle speed scale immediately
	var current_time_scale = 1.0
	if respect_time_scale and time_manager:
		current_time_scale = time_manager.get_time_scale()
	
	if particles:
		particles.speed_scale = current_time_scale
	if cpu_particles:
		cpu_particles.speed_scale = current_time_scale

func set_color(color: Color):
	"""Change the flash color at runtime."""
	light_color = color
	if light:
		light.light_color = color
