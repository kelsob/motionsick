extends Area3D

# === GUN PICKUP SYSTEM ===
# This script handles the gun pickup behavior and visual feedback

@export_group("Gun Configuration")
## Which gun type this pickup provides (affects SFX and properties)
@export_enum("Pistol", "Rifle", "Shotgun", "Sniper", "RocketLauncher") var gun_type: int = 0

@export_group("Visual Feedback")
@export var bob_height: float = 0.2     # How high/low the gun bobs
@export var bob_speed: float = 2.0      # How fast the gun bobs
@export var rotate_speed: float = 45.0  # Degrees per second rotation
@export var highlight_color: Color = Color.YELLOW
@export var highlight_intensity: float = 2.0

# Internal state
var base_position: Vector3
var time_elapsed: float = 0.0
var is_available: bool = true
var player_in_range: bool = false

# References
var gun_mesh: MeshInstance3D
var highlight_material: StandardMaterial3D
var original_material: Material

signal gun_picked_up

func _ready():
	# Store base position for bobbing animation
	base_position = position
	
	# Find the gun mesh (should be a child of this pickup)
	gun_mesh = find_child("*", false, false) as MeshInstance3D
	if not gun_mesh:
		print("WARNING: GunPickup needs a MeshInstance3D child for the gun model")
	else:
		# Store original material
		original_material = gun_mesh.material_override
		
		# Create highlight material
		highlight_material = StandardMaterial3D.new()
		if original_material and original_material is StandardMaterial3D:
			# Copy properties from original
			var orig_mat = original_material as StandardMaterial3D
			highlight_material.albedo_color = orig_mat.albedo_color
			highlight_material.metallic = orig_mat.metallic
			highlight_material.roughness = orig_mat.roughness
		else:
			# Default properties
			highlight_material.albedo_color = Color.WHITE
		
		# Add emission for highlight effect
		highlight_material.emission_enabled = true
		highlight_material.emission = highlight_color
		highlight_material.emission_energy = 0.0  # Start with no highlight
	
	# Set up collision for pickup detection
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	
	print("Gun pickup ready at position: ", global_position)

func _process(delta: float):
	if not is_available:
		return
		
	time_elapsed += delta
	
	# Animate bobbing
	var bob_offset = sin(time_elapsed * bob_speed) * bob_height
	position = base_position + Vector3(0, bob_offset, 0)
	
	# Animate rotation
	rotation.y += deg_to_rad(rotate_speed) * delta
	
	# Update highlight based on player proximity
	_update_highlight()

func _update_highlight():
	"""Update the highlight effect based on player proximity."""
	if not gun_mesh or not highlight_material:
		return
	
	# Simple on/off highlighting instead of gradual fade
	if player_in_range:
		# Enable highlight
		highlight_material.emission_enabled = true
		highlight_material.emission = highlight_color
		# Only set emission_energy if emission is enabled
		if highlight_material.emission_enabled:
			highlight_material.emission_energy = highlight_intensity
		gun_mesh.material_override = highlight_material
	else:
		# Disable highlight
		highlight_material.emission_enabled = false
		gun_mesh.material_override = original_material

func _on_body_entered(body: Node3D):
	"""Called when something enters the pickup area - just set range flag."""
	if body.is_in_group("player") and is_available:
		player_in_range = true
		print("Player entered gun pickup range")

func _on_body_exited(body: Node3D):
	"""Called when something exits the pickup area."""
	if body.is_in_group("player"):
		player_in_range = false
		print("Player left gun pickup range")

func _instant_pickup(player: Node3D):
	"""Instantly pick up the gun when player touches collision."""
	if not is_available:
		return
	
	# Check if player already has a gun
	var gun = player.get_node_or_null("Camera3D/Gun")
	if gun and gun.has_method("is_equipped") and gun.is_equipped():
		print("Player already has a gun equipped")
		return
	
	# Perform pickup
	print("Gun picked up instantly!")
	is_available = false
	
	# Emit signal
	gun_picked_up.emit()
	
	# Tell the player's gun to equip
	if gun and gun.has_method("equip_gun"):
		gun.equip_gun()
	
	# Set the gun type if the gun supports it
	if gun and gun.has_method("set_gun_type"):
		gun.set_gun_type(gun_type)
	
	# Play gun pickup SFX
	AudioManager.play_gun_pickup(_get_gun_type_name())
	
	# Free the pickup scene immediately
	queue_free()

func try_pickup(player: Node3D) -> bool:
	"""Try to pick up the gun if conditions are met."""
	if not is_available:
		return false
	
	# Only allow pickup if player is in range (overlapping with Area3D)
	if not player_in_range:
		return false
	
	# Check if player already has a gun
	var gun = player.get_node_or_null("Camera3D/Gun")
	if gun and gun.has_method("is_equipped") and gun.is_equipped():
		print("Player already has a gun equipped")
		return false
	
	# Perform pickup
	print("Gun picked up!")
	is_available = false
	
	# Emit signal
	gun_picked_up.emit()
	
	# Tell the player's gun to equip
	if gun and gun.has_method("equip_gun"):
		gun.equip_gun()
	
	# Set the gun type if the gun supports it
	if gun and gun.has_method("set_gun_type"):
		gun.set_gun_type(gun_type)
	
	# Play gun pickup SFX
	AudioManager.play_gun_pickup(_get_gun_type_name())
	
	# Free the pickup scene immediately
	queue_free()
	return true

func reset_pickup():
	"""Reset the pickup to be available again (for respawning)."""
	is_available = true
	player_in_range = false
	visible = true
	set_physics_process(true)
	set_process(true)
	time_elapsed = 0.0
	
	# Reset position and rotation
	position = base_position
	rotation = Vector3.ZERO
	
	print("Gun pickup reset and available again")

func _get_gun_type_name() -> String:
	"""Get the string name for the current gun type."""
	match gun_type:
		0: return "pistol"
		1: return "rifle"
		2: return "shotgun"
		3: return "sniper"
		4: return "rocket_launcher"
		_: return "pistol"
