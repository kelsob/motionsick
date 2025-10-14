extends Node

# === TIME VISUAL MANAGER ===
# Manages visual effects tied to the time scale
# Updates shader parameters based on TimeManager's time scale
# Modular: Swap shaders without changing this code
# Auto-loads and manages visual effect layer at runtime (like GameplayUIManager)

# Debug
const DEBUG_UPDATES = false
const DEBUG_LOADING = false

# Shader parameter name (standardized across all time-scale shaders)
const SHADER_PARAM_NAME = "time_intensity"

# Scene path
@export var visual_effect_scene: String = "res://scenes/effects/TimeVisualEffect.tscn"

# Runtime instances
var visual_effect_layer: CanvasLayer = null
var color_rect: ColorRect = null
var shader_material: ShaderMaterial = null

# Smoothing
@export_group("Transition Settings")
@export var smooth_transitions: bool = true
@export var transition_speed: float = 5.0  # How fast the visual transitions

var current_intensity: float = 0.0
var target_intensity: float = 0.0
var is_active: bool = false

func _ready():
	if DEBUG_UPDATES:
		print("TimeVisualManager: Initialized (autoload)")

func activate_for_gameplay():
	"""Load and activate visual effects for gameplay. Called by LevelManager."""
	if is_active:
		if DEBUG_LOADING:
			print("TimeVisualManager: Already active, skipping activation")
		return
	
	if DEBUG_LOADING:
		print("TimeVisualManager: Activating for gameplay")
	
	# Load the visual effect scene
	_load_visual_effect()
	
	# Connect to TimeManager
	if TimeManager:
		# Disconnect first to prevent duplicate connections
		if TimeManager.time_scale_changed.is_connected(_on_time_scale_changed):
			TimeManager.time_scale_changed.disconnect(_on_time_scale_changed)
		
		TimeManager.time_scale_changed.connect(_on_time_scale_changed)
		# Set initial value
		_on_time_scale_changed(TimeManager.custom_time_scale)
		if DEBUG_UPDATES:
			print("TimeVisualManager: Connected to TimeManager")
	else:
		push_error("TimeVisualManager: TimeManager autoload not found!")
	
	is_active = true

func deactivate():
	"""Deactivate and clean up visual effects. Called when returning to menus."""
	if not is_active:
		return
	
	if DEBUG_LOADING:
		print("TimeVisualManager: Deactivating")
	
	# Disconnect from TimeManager
	if TimeManager and TimeManager.time_scale_changed.is_connected(_on_time_scale_changed):
		TimeManager.time_scale_changed.disconnect(_on_time_scale_changed)
	
	# Clean up visual effect instance
	if visual_effect_layer:
		visual_effect_layer.queue_free()
		visual_effect_layer = null
		color_rect = null
		shader_material = null
	
	# Reset state
	current_intensity = 0.0
	target_intensity = 0.0
	is_active = false

func _load_visual_effect():
	"""Load and instance the visual effect scene."""
	var effect_scene = load(visual_effect_scene)
	if effect_scene:
		visual_effect_layer = effect_scene.instantiate()
		get_tree().root.add_child(visual_effect_layer)
		
		# Setup the visual layer
		_setup_visual_layer()
		
		if DEBUG_LOADING:
			print("TimeVisualManager: Visual effect loaded and added to scene tree")
	else:
		push_error("TimeVisualManager: Failed to load visual effect scene: ", visual_effect_scene)

func _setup_visual_layer():
	# Find the ColorRect child
	for child in visual_effect_layer.get_children():
		if child is ColorRect:
			color_rect = child
			break
	
	if not color_rect:
		push_error("TimeVisualManager: No ColorRect found in visual_effect_layer!")
		return
	
	# Get the shader material
	if color_rect.material and color_rect.material is ShaderMaterial:
		shader_material = color_rect.material
		if DEBUG_UPDATES:
			print("TimeVisualManager: Shader material found and ready")
	else:
		push_error("TimeVisualManager: ColorRect does not have a ShaderMaterial assigned!")

func _process(delta: float):
	if not shader_material:
		return
	
	# Smooth transition
	if smooth_transitions:
		current_intensity = lerp(current_intensity, target_intensity, transition_speed * delta)
	else:
		current_intensity = target_intensity
	
	# Update shader parameter
	shader_material.set_shader_parameter(SHADER_PARAM_NAME, current_intensity)

func _on_time_scale_changed(new_time_scale: float):
	# Map time scale to intensity
	# Assume normal speed is 1.0, and slow motion is < 1.0
	# Intensity should be HIGH when time is SLOW (inverted relationship)
	
	# When time_scale = 1.0 (normal) -> intensity = 0.0 (no effect)
	# When time_scale = 0.0 (stopped) -> intensity = 1.0 (full effect)
	target_intensity = 1.0 - new_time_scale
	
	if DEBUG_UPDATES:
		print("TimeVisualManager: Time scale changed to ", new_time_scale, " | Target intensity: ", target_intensity)

# === PUBLIC API ===

# Hot-swap shader by resource path (for experimentation)
func set_shader_by_path(shader_path: String):
	if not shader_material:
		push_error("TimeVisualManager: Cannot set shader, no shader material found")
		return
	
	var new_shader = load(shader_path)
	if new_shader:
		shader_material.shader = new_shader
		print("TimeVisualManager: Shader swapped to: ", shader_path)
	else:
		push_error("TimeVisualManager: Failed to load shader: ", shader_path)

# Hot-swap shader (for experimentation with preloaded shaders)
func set_shader(new_shader: Shader):
	if not shader_material:
		push_error("TimeVisualManager: Cannot set shader, no shader material found")
		return
	
	shader_material.shader = new_shader
	print("TimeVisualManager: Shader swapped successfully")

# Direct intensity override (for special effects/cutscenes)
func set_intensity_override(intensity: float):
	target_intensity = clamp(intensity, 0.0, 1.0)
	if DEBUG_UPDATES:
		print("TimeVisualManager: Intensity override set to ", target_intensity)

# Reset to time-scale driven mode
func clear_intensity_override():
	if TimeManager:
		_on_time_scale_changed(TimeManager.custom_time_scale)
