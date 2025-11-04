extends Area3D

# === DEBUG SETTINGS ===
const DEBUG_DROPPED_GUN: bool = false

# === GUN PICKUP SYSTEM ===
# This script handles the gun pickup behavior and visual feedback

@export_group("Gun Configuration")
## Which gun type this pickup provides (affects SFX and properties)
@export_enum("Pistol", "Rifle", "Shotgun", "Sniper", "RocketLauncher") var gun_type: int = 0
## Current ammo count in this pickup (0 to gun capacity, -1 for full ammo)
@export var current_ammo: int = -1

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
var gun_scene_instance: Node3D
var highlight_material: StandardMaterial3D
var original_materials: Array[Material] = []
var gun_data_resource: Resource

signal gun_picked_up

func _ready():
	print("gunpickup: _ready() called")
	
	# Store base position for bobbing animation
	base_position = global_position
	base_position.y = 1.0  # Set initial height to 1.0
	print("gunpickup: Base position set to: ", base_position)
	
	# Load gun data resource based on gun type
	_load_gun_data()
	
	# Instantiate the gun scene
	_instantiate_gun_scene()
	
	# Set up highlighting system
	_setup_highlighting()
	
	# Set up collision for pickup detection
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	print("gunpickup: Signals connected - body_entered and body_exited")
	
	# Debug collision setup
	_debug_collision_setup()

func _load_gun_data():
	"""Load the gun data resource based on gun type."""
	var gun_data_paths = [
		"res://assets/guns/pistol_data.tres",
		"res://assets/guns/rifle_data.tres", 
		"res://assets/guns/shotgun_data.tres",
		"res://assets/guns/sniper_data.tres",
		"res://assets/guns/rocket_launcher_data.tres"
	]
	
	if gun_type >= 0 and gun_type < gun_data_paths.size():
		gun_data_resource = load(gun_data_paths[gun_type])
		if gun_data_resource:
			print("GunPickup: Loaded gun data for type ", gun_type, ": ", gun_data_resource.gun_name)
		else:
			print("ERROR: Could not load gun data for type ", gun_type)
	else:
		print("ERROR: Invalid gun type: ", gun_type)

func _instantiate_gun_scene():
	"""Instantiate the gun scene based on gun data."""
	if not gun_data_resource or not gun_data_resource.gun_scene:
		print("ERROR: No gun scene found in gun data")
		return
	
	# Instantiate the gun scene
	gun_scene_instance = gun_data_resource.gun_scene.instantiate()
	add_child(gun_scene_instance)
	
	print("GunPickup: Instantiated gun scene: ", gun_scene_instance.name)

func _setup_highlighting():
	"""Set up the highlighting system for the gun scene."""
	if not gun_scene_instance:
		print("WARNING: No gun scene instance to set up highlighting")
		return
	
	# Find all MeshInstance3D nodes in the gun scene
	var mesh_instances = _find_mesh_instances_recursive(gun_scene_instance)
	
	if mesh_instances.is_empty():
		print("WARNING: No MeshInstance3D nodes found in gun scene")
		return
	
	# Store original materials and create highlight materials
	highlight_material = StandardMaterial3D.new()
	highlight_material.emission_enabled = true
	highlight_material.emission = highlight_color
	highlight_material.emission_energy = 0.0  # Start with no highlight
	
	# Store original materials for each mesh instance
	for mesh_instance in mesh_instances:
		if mesh_instance.material_override:
			original_materials.append(mesh_instance.material_override)
		else:
			original_materials.append(null)
	
	print("GunPickup: Set up highlighting for ", mesh_instances.size(), " mesh instances")

func _find_mesh_instances_recursive(node: Node) -> Array[MeshInstance3D]:
	"""Recursively find all MeshInstance3D nodes in the scene."""
	var mesh_instances: Array[MeshInstance3D] = []
	
	if node is MeshInstance3D:
		mesh_instances.append(node as MeshInstance3D)
	
	for child in node.get_children():
		mesh_instances.append_array(_find_mesh_instances_recursive(child))
	
	return mesh_instances

func _debug_collision_setup():
	"""Debug the collision setup for this GunPickup."""
	print("gunpickup: === COLLISION DEBUG ===")
	print("gunpickup: GunPickup node type: ", get_class())
	print("gunpickup: GunPickup global position: ", global_position)
	print("gunpickup: GunPickup collision layer: ", collision_layer)
	print("gunpickup: GunPickup collision mask: ", collision_mask)
	print("gunpickup: GunPickup monitoring: ", monitoring)
	print("gunpickup: GunPickup monitorable: ", monitorable)
	
	# Check for CollisionShape3D
	var collision_shape = get_node_or_null("CollisionShape3D")
	if collision_shape:
		print("gunpickup: CollisionShape3D found: ", collision_shape.name)
		if collision_shape.shape:
			print("gunpickup: CollisionShape3D has shape: ", collision_shape.shape.get_class())
		else:
			print("gunpickup: ERROR - CollisionShape3D has no shape!")
	else:
		print("gunpickup: ERROR - No CollisionShape3D found!")
	
	print("gunpickup: === END COLLISION DEBUG ===")

func _process(delta: float):
	if not is_available:
		return
		
	time_elapsed += delta
	
	# Animate bobbing
	var bob_offset = sin(time_elapsed * bob_speed) * bob_height
	position.y = base_position.y + bob_offset
	
	# Animate rotation
	rotation.y += deg_to_rad(rotate_speed) * delta
	
	# Update highlight based on player proximity
	_update_highlight()

func _update_highlight():
	"""Update the highlight effect based on player proximity."""
	if not gun_scene_instance or not highlight_material:
		return
	
	# Find all MeshInstance3D nodes in the gun scene
	var mesh_instances = _find_mesh_instances_recursive(gun_scene_instance)
	
	if mesh_instances.is_empty():
		return
	
	# Simple on/off highlighting instead of gradual fade
	if player_in_range:
		# Enable highlight on all mesh instances
		for i in range(mesh_instances.size()):
			var mesh_instance = mesh_instances[i]
			highlight_material.emission_enabled = true
			highlight_material.emission = highlight_color
			highlight_material.emission_energy = highlight_intensity
			mesh_instance.material_override = highlight_material
	else:
		# Disable highlight - restore original materials
		for i in range(mesh_instances.size()):
			var mesh_instance = mesh_instances[i]
			if i < original_materials.size():
				mesh_instance.material_override = original_materials[i]
			else:
				mesh_instance.material_override = null

func _on_body_entered(body: Node3D):
	"""Called when something enters the pickup area - just set range flag."""
	print("gunpickup: body_entered called with body: ", body.name, " (is_player: ", body.is_in_group("player"), ")")
	if body.is_in_group("player") and is_available:
		player_in_range = true
		print("gunpickup: Player entered pickup range!")

func _on_body_exited(body: Node3D):
	"""Called when something exits the pickup area."""
	print("gunpickup: body_exited called with body: ", body.name, " (is_player: ", body.is_in_group("player"), ")")
	if body.is_in_group("player"):
		player_in_range = false
		print("gunpickup: Player exited pickup range!")

func _instant_pickup(player: Node3D):
	"""Instantly pick up the gun when player touches collision."""
	if not is_available:
		return
	
	# Get the player's gun
	var gun = player.get_node_or_null("Camera3D/Gun")
	if not gun:
		return
	
	# Check if player already has a gun equipped
	if gun.has_method("is_equipped") and gun.is_equipped():
		# Player has a gun - perform gun swap
		_perform_gun_swap(player, gun)
	else:
		# Player has no gun - normal pickup
		_perform_normal_pickup(gun)
	
	# Mark as unavailable and free this pickup
	is_available = false
	gun_picked_up.emit()
	queue_free()
	
func _perform_normal_pickup(gun: Node3D):
	"""Perform normal gun pickup when player has no gun."""
	# Tell the player's gun to equip
	if gun.has_method("equip_gun"):
		gun.equip_gun()
	
	# Set the gun type if the gun supports it
	if gun.has_method("set_gun_type"):
		gun.set_gun_type(gun_type)
	
	# Set ammo from the pickup's current_ammo property
	if gun.has_method("set_ammo"):
		var ammo_to_set = current_ammo
		print("PICKUP DEBUG: current_ammo = ", current_ammo)
		if current_ammo == -1:
			# -1 means full ammo, get the gun's max capacity AFTER gun type is set
			if gun.has_method("get_max_ammo"):
				ammo_to_set = gun.get_max_ammo()
				print("PICKUP DEBUG: Got max ammo: ", ammo_to_set)
			else:
				ammo_to_set = 0  # Fallback
		print("PICKUP DEBUG: Setting ammo to: ", ammo_to_set)
		gun.set_ammo(ammo_to_set)
		print("PICKUP DEBUG: After set_ammo - current: ", gun.get_current_ammo(), " max: ", gun.get_max_ammo())
 
	# Play gun pickup SFX
	AudioManager.play_gun_pickup(_get_gun_type_name())

func _perform_gun_swap(player: Node3D, gun: Node3D):
	"""Perform gun swap - drop current gun and pick up new one."""
	# Get current gun info before swapping
	var current_gun_type = 0
	var current_ammo = 0
	if gun.has_method("get_current_gun_type"):
		current_gun_type = gun.get_current_gun_type()
	if gun.has_method("get_current_ammo"):
		current_ammo = gun.get_current_ammo()
	
	# Drop the current gun
	if gun.has_method("drop_gun"):
		gun.drop_gun()
	
	# Equip the new gun
	if gun.has_method("equip_gun"):
		gun.equip_gun()
	
	# Set the new gun type
	if gun.has_method("set_gun_type"):
		gun.set_gun_type(gun_type)
	
	# Set ammo from the pickup's current_ammo property
	if gun.has_method("set_ammo"):
		var ammo_to_set = self.current_ammo  # Use pickup's ammo, not old gun's ammo
		print("SWAP DEBUG: pickup current_ammo = ", self.current_ammo)
		if self.current_ammo == -1:
			# -1 means full ammo, get the gun's max capacity AFTER gun type is set
			if gun.has_method("get_max_ammo"):
				ammo_to_set = gun.get_max_ammo()
			else:
				ammo_to_set = 0  # Fallback
		gun.set_ammo(ammo_to_set)
		print("SWAP DEBUG: Set gun ammo to: ", ammo_to_set, " (pickup had: ", self.current_ammo, ")")

	# Create a new gun pickup for the dropped gun
	_create_dropped_gun_pickup(player, current_gun_type, current_ammo)
	
	# Play gun pickup SFX
	AudioManager.play_gun_pickup(_get_gun_type_name())
	
func _create_dropped_gun_pickup(player: Node3D, dropped_gun_type: int, dropped_ammo: int):
	"""Create a new gun pickup for the dropped gun with throw animation."""
	# Start the throw animation
	_start_gun_throw_animation(player, dropped_gun_type, dropped_ammo)

func _start_gun_throw_animation(player: Node3D, dropped_gun_type: int, dropped_ammo: int):
	"""Start the gun throw animation."""
	# Get the player's gun node
	var gun_node = player.get_node_or_null("Camera3D/Gun")
	if not gun_node:
		return
	
	# Create a copy of the actual gun mesh
	var throw_mesh = _copy_gun_mesh(gun_node)
	if not throw_mesh:
		return
	
	get_tree().current_scene.add_child(throw_mesh)
	
	# Position at the exact gun location
	throw_mesh.global_position = gun_node.global_position
	throw_mesh.global_rotation = gun_node.global_rotation
	
	# Calculate throw trajectory based on player's current rotation
	var player_forward = -player.global_transform.basis.z
	var throw_distance = 3.0  # How far to throw
	var throw_height = 1.0    # Arc height
	var landing_position = player.global_position + player_forward * throw_distance
	
	# Start the throw animation
	_animate_gun_throw(throw_mesh, landing_position, throw_height, dropped_gun_type, dropped_ammo)

func _copy_gun_mesh(gun_node: Node3D) -> Node3D:
	"""Copy the actual gun mesh from the player's gun."""
	var throw_mesh = Node3D.new()
	throw_mesh.name = "ThrownGun"
	
	# Find all MeshInstance3D children in the gun
	_copy_mesh_instances_recursive(gun_node, throw_mesh)
	
	return throw_mesh

func _copy_mesh_instances_recursive(source_node: Node, target_node: Node3D):
	"""Recursively copy all MeshInstance3D nodes from source to target."""
	for child in source_node.get_children():
		if child is MeshInstance3D:
			var mesh_instance = child as MeshInstance3D
			var new_mesh_instance = MeshInstance3D.new()
			
			# Copy mesh
			new_mesh_instance.mesh = mesh_instance.mesh
			
			# Copy transform
			new_mesh_instance.transform = mesh_instance.transform
			
			# Copy materials
			for i in range(mesh_instance.get_surface_override_material_count()):
				var material = mesh_instance.get_surface_override_material(i)
				if material:
					new_mesh_instance.set_surface_override_material(i, material)
			
			# Copy other properties
			new_mesh_instance.visible = mesh_instance.visible
			new_mesh_instance.cast_shadow = mesh_instance.cast_shadow
			
			target_node.add_child(new_mesh_instance)
		
		# Recursively copy children
		if child.get_child_count() > 0:
			_copy_mesh_instances_recursive(child, target_node)

func _animate_gun_throw(throw_mesh: Node3D, landing_position: Vector3, throw_height: float, gun_type: int, ammo: int):
	"""Drop the gun with gravity using Node3D."""
	
	# Remove the temporary mesh
	throw_mesh.queue_free()
	
	# Create a Node3D for the dropped gun
	var dropped_gun = _create_dropped_gun_rigidbody(gun_type)
	
	# Set initial velocity and metadata BEFORE adding to scene
	var player = get_tree().get_first_node_in_group("player")
	var player_forward = -player.global_transform.basis.z
	var player_up = player.global_transform.basis.y
	
	# Calculate initial velocity based on look direction + upward kick
	var forward_speed = 2.0
	var upward_kick = 1.5
	var initial_velocity = (player_forward * forward_speed) + (player_up * upward_kick)

	
	# Store the initial velocity and gun data in metadata BEFORE _ready() is called
	dropped_gun.set_meta("initial_velocity", initial_velocity)
	dropped_gun.set_meta("gun_type", gun_type)
	dropped_gun.set_meta("ammo", ammo)
	
	# Add to scene tree AFTER setting metadata
	get_tree().current_scene.add_child(dropped_gun)

	
	# EXPLICITLY enable process - force it to work!
	dropped_gun.set_process(true)

	# Position it at the gun location and apply rotation
	var gun_node = get_tree().get_first_node_in_group("player").get_node_or_null("Camera3D/Gun")
	var camera_node = get_tree().get_first_node_in_group("player").get_node_or_null("Camera3D")
	if gun_node and camera_node:
		dropped_gun.global_position = gun_node.global_position
		dropped_gun.global_rotation = camera_node.global_rotation  # Use camera rotation, not gun rotation
		print("ROTATION DEBUG: Set dropped gun rotation to: ", camera_node.global_rotation)
		print("ROTATION DEBUG: Dropped gun rotation is now: ", dropped_gun.global_rotation)
	
	# Set up a timer to create the pickup after it lands
	_setup_gun_pickup_timer(dropped_gun, gun_type, ammo)

func _create_dropped_gun_rigidbody(gun_type: int) -> RigidBody3D:
	"""Create a RigidBody3D for the dropped gun using the proper gun scene."""
	
	# Load the gun data resource to get the gun scene
	var gun_data_paths = [
		"res://assets/guns/pistol_data.tres",
		"res://assets/guns/rifle_data.tres", 
		"res://assets/guns/shotgun_data.tres",
		"res://assets/guns/sniper_data.tres",
		"res://assets/guns/rocket_launcher_data.tres"
	]
	
	var gun_data_resource = null
	if gun_type >= 0 and gun_type < gun_data_paths.size():
		gun_data_resource = load(gun_data_paths[gun_type])
	
	if not gun_data_resource or not gun_data_resource.gun_scene:
		print("gunpickup: ERROR - No gun scene found for gun type: ", gun_type)
		# Fallback: create a simple box
		var rigidbody = RigidBody3D.new()
		rigidbody.name = "DroppedGun"
		var mesh_instance = MeshInstance3D.new()
		mesh_instance.name = "GunMesh"
		var box_mesh = BoxMesh.new()
		box_mesh.size = Vector3(0.25, 0.25, 0.5)
		mesh_instance.mesh = box_mesh
		rigidbody.add_child(mesh_instance)
		
		# Add collision shape
		var collision_shape = CollisionShape3D.new()
		var box_shape = BoxShape3D.new()
		box_shape.size = Vector3(0.25, 0.25, 0.5)
		collision_shape.shape = box_shape
		rigidbody.add_child(collision_shape)
		
		rigidbody.set_script(preload("res://scripts/player/DroppedGun.gd"))
		return rigidbody
	
	# Instantiate the gun scene
	var gun_scene_instance = gun_data_resource.gun_scene.instantiate()
	print("gunpickup: Dropped gun scene instantiated: ", gun_scene_instance.name)
	
	# Convert the gun scene to a RigidBody3D
	var rigidbody = RigidBody3D.new()
	rigidbody.name = "DroppedGun"
	
	# Move all children from gun scene to rigidbody
	for child in gun_scene_instance.get_children():
		gun_scene_instance.remove_child(child)
		rigidbody.add_child(child)
	
	# Remove the gun scene instance (it's now empty)
	gun_scene_instance.queue_free()
	
	# Set up collision layers - gun should collide with environment
	rigidbody.collision_layer = 1  # Layer 1
	rigidbody.collision_mask = 4   # Collide with layer 3 (environment)
	
	# Attach the proper script file
	rigidbody.set_script(preload("res://scripts/player/DroppedGun.gd"))
	
	print("gunpickup: Dropped gun RigidBody3D created with gun scene content")
	return rigidbody

func _setup_gun_pickup_timer(dropped_gun: RigidBody3D, gun_type: int, ammo: int):
	"""Set up a timer to create the pickup after the gun lands."""
	var timer = Timer.new()
	timer.wait_time = 2.0  # Wait 2 seconds for it to land
	timer.one_shot = true
	timer.timeout.connect(func():
		_create_gun_pickup_from_rigidbody(dropped_gun, gun_type, ammo)
		timer.queue_free()
	)
	get_tree().current_scene.add_child(timer)
	timer.start()

func _create_gun_pickup_from_rigidbody(dropped_gun: Node3D, gun_type: int, ammo: int):
	"""Create a gun pickup at the rigidbody's position and remove the rigidbody."""
	# Get the final position
	var final_position = dropped_gun.global_position
	
	# Remove the rigidbody
	dropped_gun.queue_free()
	
	# Create the gun pickup
	var gun_pickup_scene = preload("res://scenes/GunPickup.tscn")
	var new_pickup = gun_pickup_scene.instantiate()
	get_tree().current_scene.add_child(new_pickup)
	
	# Position at the landing location
	new_pickup.global_position = final_position
	
	# Configure the dropped gun pickup
	if new_pickup.has_method("set_gun_type"):
		new_pickup.set_gun_type(gun_type)
	
	# Store the ammo information
	if new_pickup.has_method("set_ammo_info"):
		new_pickup.set_ammo_info(ammo)
	

func try_pickup(player: Node3D) -> bool:
	"""Try to pick up the gun if conditions are met."""
	if not is_available:
		return false
	
	# Only allow pickup if player is in range (overlapping with Area3D)
	if not player_in_range:
		return false
	
	# Get the player's gun
	var gun = player.get_node_or_null("Camera3D/Gun")
	if not gun:
		return false
	
	# Check if player already has a gun equipped
	if gun.has_method("is_equipped") and gun.is_equipped():
		# Player has a gun - perform gun swap
		_perform_gun_swap(player, gun)
	else:
		# Player has no gun - normal pickup
		_perform_normal_pickup(gun)
	
	# Mark as unavailable and free this pickup
	is_available = false
	gun_picked_up.emit()
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
	

func set_gun_type(new_gun_type: int):
	"""Set the gun type for this pickup and reload the gun scene."""
	print("gunpickup: set_gun_type called with: ", new_gun_type)
	gun_type = new_gun_type
	
	# Remove the old gun scene if it exists
	if gun_scene_instance:
		gun_scene_instance.queue_free()
		gun_scene_instance = null
	
	# Clear the highlighting materials
	original_materials.clear()
	
	# Reload gun data and instantiate new gun scene
	_load_gun_data()
	_instantiate_gun_scene()
	_setup_highlighting()
	
	print("gunpickup: Gun scene reloaded for gun type: ", new_gun_type)

func set_ammo_info(ammo_count: int):
	"""Set the ammo information for this pickup (stored for when player picks it up)."""
	# Set the current_ammo property directly
	current_ammo = ammo_count
	print("DROPPED GUN DEBUG: Set pickup current_ammo to: ", ammo_count)

func _get_gun_type_name() -> String:
	"""Get the string name for the current gun type."""
	match gun_type:
		0: return "pistol"
		1: return "rifle"
		2: return "shotgun"
		3: return "sniper"
		4: return "rocket_launcher"
		_: return "pistol"
