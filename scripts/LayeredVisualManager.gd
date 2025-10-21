extends Node

# === LAYERED VISUAL MANAGER ===
# Simple manager that updates time_intensity for multiple shader layers
# Loads a visual effects scene and updates hardcoded node paths

# Debug
const DEBUG_UPDATES = false

# Scene path
@export var visual_effect_scene: String = "res://scenes/effects/TimeVisualEffect.tscn"

# Shader layers to update
var shader_layers: Array[ShaderMaterial] = []

# Runtime instance
var visual_effect_node: Node = null

func _ready():
	if DEBUG_UPDATES:
		print("LayeredVisualManager: Initialized")

func activate_for_gameplay():
	"""Load visual effects scene and setup shader layers."""
	if DEBUG_UPDATES:
		print("LayeredVisualManager: Activating")
	
	# Load the visual effects scene
	_load_visual_effects()
	
	# Connect to TimeManager (disconnect first to avoid duplicate connections)
	if TimeManager:
		if TimeManager.time_scale_changed.is_connected(_on_time_scale_changed):
			TimeManager.time_scale_changed.disconnect(_on_time_scale_changed)
		TimeManager.time_scale_changed.connect(_on_time_scale_changed)
		# Set initial value
		_on_time_scale_changed(TimeManager.custom_time_scale)
		if DEBUG_UPDATES:
			print("LayeredVisualManager: Connected to TimeManager")

func deactivate():
	"""Disconnect from TimeManager and cleanup."""
	if TimeManager and TimeManager.time_scale_changed.is_connected(_on_time_scale_changed):
		TimeManager.time_scale_changed.disconnect(_on_time_scale_changed)
	
	# Clean up visual effects
	if visual_effect_node:
		visual_effect_node.queue_free()
		visual_effect_node = null
	
	# Clear shader layers
	shader_layers.clear()
	
	if DEBUG_UPDATES:
		print("LayeredVisualManager: Deactivated")

func _load_visual_effects():
	"""Load the visual effects scene and setup shader references."""
	var effect_scene = load(visual_effect_scene)
	if effect_scene:
		visual_effect_node = effect_scene.instantiate()
		get_tree().root.add_child(visual_effect_node)
		
		# Setup hardcoded node paths
		_setup_shader_layers()
		
		if DEBUG_UPDATES:
			print("LayeredVisualManager: Visual effects loaded")
	else:
		push_error("LayeredVisualManager: Failed to load visual effect scene: ", visual_effect_scene)

func _setup_shader_layers():
	"""Setup references to shader materials by iterating over children."""
	# Clear existing layers
	shader_layers.clear()
	
	# Iterate over all children of the visual effect node
	for child in visual_effect_node.get_children():
		if child is CanvasLayer:
			# Get the ColorRect child from this CanvasLayer
			for colorrect in child.get_children():
				if colorrect is ColorRect and colorrect.material is ShaderMaterial:
					var shader_mat = colorrect.material as ShaderMaterial
					if shader_mat.shader:
						shader_layers.append(shader_mat)
						if DEBUG_UPDATES:
							print("LayeredVisualManager: Added shader layer from: ", colorrect.get_path())
	
	if DEBUG_UPDATES:
		print("LayeredVisualManager: Found ", shader_layers.size(), " shader layers")

func _on_time_scale_changed(new_time_scale: float):
	"""Update all shader layers with new time intensity."""
	var intensity = 1.0 - new_time_scale
	
	# Update all shader layers
	for shader_mat in shader_layers:
		shader_mat.set_shader_parameter("time_intensity", intensity)
	
	if DEBUG_UPDATES:
		print("LayeredVisualManager: Updated ", shader_layers.size(), " layers with intensity: ", intensity)
