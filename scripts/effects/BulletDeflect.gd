extends Node3D

# === BULLET DEFLECTION EFFECT ===
# Creates a brief particle burst when player deflects a bullet

@export_group("Effect Settings")
@export var effect_duration: float = 1.0  # How long the effect lasts
@export var auto_cleanup: bool = true     # Automatically remove after duration

# Component references
@onready var particles: GPUParticles3D = $GPUParticles3D

# Time system integration
var time_manager: Node
var life_timer: float = 0.0

func _ready():
	# Connect to time manager for proper time scaling
	time_manager = get_node_or_null("/root/TimeManager")
	
	# Configure particles for deflection effect
	_setup_particles()
	
	# Start the effect
	_trigger_effect()
	
	print("Bullet deflection effect started")

func _setup_particles():
	"""Configure the particle system for deflection effect."""
	if not particles:
		print("WARNING: No GPUParticles3D found in BulletDeflect scene")
		return
	
	# Basic particle settings for a quick spark effect
	particles.emitting = false  # We'll trigger this manually
	
	# Configure emission for burst effect
	var material = particles.process_material
	if material and material is ParticleProcessMaterial:
		var particle_mat = material as ParticleProcessMaterial
		
		# Set up basic spark properties
		particle_mat.direction = Vector3(0, 1, 0)
		particle_mat.initial_velocity_min = 5.0
		particle_mat.initial_velocity_max = 15.0
		particle_mat.angular_velocity_min = -180.0
		particle_mat.angular_velocity_max = 180.0
		
		# Gravity and damping for realistic sparks
		particle_mat.gravity = Vector3(0, -9.8, 0)
		particle_mat.damping_min = 1.0
		particle_mat.damping_max = 3.0
		
		# Scale particles down over time
		particle_mat.scale_min = 0.1
		particle_mat.scale_max = 0.3
		
		print("Particle material configured")

func _trigger_effect():
	"""Start the deflection particle effect."""
	if particles:
		particles.restart()
		particles.emitting = true
		print("Deflection particles triggered")

func _process(delta: float):
	"""Update effect lifetime with time scaling."""
	if not auto_cleanup:
		return
	
	# Use time-adjusted delta to respect time dilation
	var effective_delta = delta
	if time_manager:
		effective_delta = time_manager.get_effective_delta(delta, 0.0)
	
	life_timer += effective_delta
	
	# Remove effect after duration
	if life_timer >= effect_duration:
		queue_free()

func cleanup_effect():
	"""Manually clean up the effect."""
	if particles:
		particles.emitting = false
	queue_free()
