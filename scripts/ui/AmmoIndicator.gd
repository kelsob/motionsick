extends HBoxContainer
class_name AmmoIndicator

# === AMMO INDICATOR SYSTEM ===
# Visual representation of player's ammo using individual bullet indicators

# === CONFIGURATION ===
@export var bullet_indicator_scene: PackedScene = preload("res://scenes/UI/BulletIndicator.tscn")
@export var bullet_spacing: float = 24  # Space between bullet indicators
@export var container_margin: float = 10.0  # Margin from edges

# === COMPONENTS ===
@onready var bullet_container: HBoxContainer

# === STATE ===
var bullet_indicators: Array[Control] = []
var gun_reference: Node3D = null
var max_ammo_count: int = 0
var current_ammo_count: int = 0

func _ready():
	# Create horizontal container for bullet indicators
	bullet_container = HBoxContainer.new()
	bullet_container.add_theme_constant_override("separation", bullet_spacing)
	add_child(bullet_container)
	
	# Position container at bottom-right of screen
	bullet_container.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	bullet_container.position = Vector2(-container_margin, -container_margin)
	bullet_container.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	bullet_container.grow_vertical = Control.GROW_DIRECTION_BEGIN
	
	# Find and connect to gun
	_connect_to_gun()

func _connect_to_gun():
	"""Find the player's gun and connect to its ammo system."""
	# Find player first
	var player = get_tree().get_first_node_in_group("player")
	if not player:
		print("AmmoIndicator: Could not find player!")
		return
	
	# Find gun (should be child of camera which is child of player)
	var camera = player.get_node("Camera3D")
	if not camera:
		print("AmmoIndicator: Could not find player camera!")
		return
	
	var gun = camera.get_node("Gun")
	if not gun:
		print("AmmoIndicator: Could not find player gun!")
		return
	
	gun_reference = gun
	
	# Connect to ammo changed signal
	if gun.has_signal("ammo_changed"):
		gun.ammo_changed.connect(_on_ammo_changed)
		print("AmmoIndicator: Connected to gun ammo system")
		
		# Initialize with current ammo values
		var initial_current = gun.get_current_ammo() if gun.has_method("get_current_ammo") else 0
		var initial_max = gun.get_max_ammo() if gun.has_method("get_max_ammo") else 6
		_on_ammo_changed(initial_current, initial_max)
	else:
		print("AmmoIndicator: Gun does not have ammo_changed signal!")

func _on_ammo_changed(current_ammo: int, max_ammo: int):
	"""Called when the gun's ammo count changes."""
	print("AmmoIndicator: Ammo changed to ", current_ammo, "/", max_ammo)
	
	current_ammo_count = current_ammo
	
	# If max ammo changed, rebuild all indicators
	if max_ammo != max_ammo_count:
		max_ammo_count = max_ammo
		_rebuild_bullet_indicators()
	
	# Update visibility of existing indicators
	_update_bullet_visibility()

func _rebuild_bullet_indicators():
	"""Rebuild all bullet indicators when max ammo changes."""
	print("AmmoIndicator: Rebuilding indicators for max ammo: ", max_ammo_count)
	
	# Clear existing indicators
	_clear_bullet_indicators()
	
	# Create new indicators
	for i in range(max_ammo_count):
		var bullet_indicator = bullet_indicator_scene.instantiate()
		bullet_container.add_child(bullet_indicator)
		bullet_indicators.append(bullet_indicator)
		
		print("AmmoIndicator: Created bullet indicator ", i + 1, "/", max_ammo_count)

func _clear_bullet_indicators():
	"""Remove all existing bullet indicators."""
	for indicator in bullet_indicators:
		if is_instance_valid(indicator):
			indicator.queue_free()
	
	bullet_indicators.clear()
	
	# Clear any remaining children from container
	for child in bullet_container.get_children():
		child.queue_free()

func _update_bullet_visibility():
	"""Update the visibility of bullet indicators based on current ammo."""
	for i in range(bullet_indicators.size()):
		var bullet_indicator = bullet_indicators[i]
		if not is_instance_valid(bullet_indicator):
			continue
		
		# Show bullet if we have ammo for this slot (filling left to right)
		var should_show_bullet = (i < current_ammo_count)
		
		# Call the bullet indicator's method to show/hide the bullet
		if bullet_indicator.has_method("set_bullet_visible"):
			bullet_indicator.set_bullet_visible(should_show_bullet)
		else:
			print("AmmoIndicator: BulletIndicator missing set_bullet_visible method!")

# === DEBUG ===
func print_status():
	"""Debug function to print ammo indicator status."""
	print("\n=== AMMO INDICATOR STATUS ===")
	print("Max ammo: ", max_ammo_count)
	print("Current ammo: ", current_ammo_count)
	print("Bullet indicators: ", bullet_indicators.size())
	print("Gun reference: ", gun_reference.name if gun_reference else "None")
	print("============================\n")
