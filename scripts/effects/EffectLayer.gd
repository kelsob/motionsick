extends Node
class_name EffectLayer

# === INDIVIDUAL EFFECT LAYER ===
# Manages a single shader effect with its own CanvasLayer and ColorRect
# Supports different blend modes and independent control

signal layer_enabled_changed(enabled: bool)
signal intensity_changed(intensity: float)

# Layer identification
@export var layer_name: String = "EffectLayer"
@export var layer_order: int = 0  # Lower numbers render first (behind higher numbers)

# Effect control
@export var enabled: bool = true
@export var intensity: float = 0.0
@export var blend_mode: BlendMode = BlendMode.NORMAL

# Smoothing settings
@export var smooth_transitions: bool = true
@export var transition_speed: float = 5.0

# Shader settings
@export var shader_resource: Shader
@export var canvas_layer_value: int = 64

# Runtime components
var canvas_layer: CanvasLayer
var color_rect: ColorRect
var shader_material: ShaderMaterial

# Internal state
var current_intensity: float = 0.0
var target_intensity: float = 0.0

enum BlendMode {
	NORMAL,          # Standard alpha blending
	ADD,             # Additive blending (glow effects)
	MULTIPLY,        # Multiply blending (darkening)
	SCREEN,          # Screen blending (brightening)
	OVERLAY,         # Overlay blending (contrast)
	SOFT_LIGHT,      # Soft light blending
	HARD_LIGHT,      # Hard light blending
	COLOR_DODGE,     # Color dodge blending
	COLOR_BURN       # Color burn blending
}

func _ready():
	_create_layer_components()
	_setup_shader()

func _process(delta: float):
	if not enabled or not shader_material:
		return
	
	# Smooth intensity transitions
	if smooth_transitions:
		current_intensity = lerp(current_intensity, target_intensity, transition_speed * delta)
	else:
		current_intensity = target_intensity
	
	# Update shader intensity
	shader_material.set_shader_parameter("time_intensity", current_intensity)

func _create_layer_components():
	"""Create the CanvasLayer and ColorRect for this effect layer."""
	
	# Create CanvasLayer
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = canvas_layer_value + layer_order  # Offset by layer order
	canvas_layer.name = layer_name + "_CanvasLayer"
	add_child(canvas_layer)
	
	# Create ColorRect
	color_rect = ColorRect.new()
	color_rect.name = "EffectRect"
	color_rect.anchors_preset = Control.PRESET_FULL_RECT
	color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	color_rect.color = Color.TRANSPARENT  # Start transparent
	
	# Set blend mode
	_set_blend_mode()
	
	canvas_layer.add_child(color_rect)

func _setup_shader():
	"""Setup the shader material for this layer."""
	if not shader_resource:
		push_error("EffectLayer '" + layer_name + "': No shader resource assigned!")
		return
	
	# Create shader material
	shader_material = ShaderMaterial.new()
	shader_material.shader = shader_resource
	
	# Apply to ColorRect
	color_rect.material = shader_material
	
	# Set initial intensity
	shader_material.set_shader_parameter("time_intensity", current_intensity)

func _set_blend_mode():
	"""Apply the blend mode to the ColorRect."""
	if not color_rect:
		return
	
	match blend_mode:
		BlendMode.NORMAL:
			# Default blending - no special setup needed
			pass
		BlendMode.ADD:
			# Additive blending for glow effects
			color_rect.modulate = Color.WHITE
		BlendMode.MULTIPLY:
			# Multiply blending for darkening
			color_rect.modulate = Color.WHITE
		BlendMode.SCREEN:
			# Screen blending for brightening
			color_rect.modulate = Color.WHITE
		_:
			# For other blend modes, you might need custom shader code
			pass

# === PUBLIC API ===

func set_enabled(new_enabled: bool):
	"""Enable or disable this effect layer."""
	if enabled == new_enabled:
		return
	
	enabled = new_enabled
	if canvas_layer:
		canvas_layer.visible = enabled
	layer_enabled_changed.emit(enabled)

func set_intensity(new_intensity: float):
	"""Set the target intensity for this effect layer."""
	target_intensity = clamp(new_intensity, 0.0, 1.0)
	intensity_changed.emit(target_intensity)

func set_instant_intensity(new_intensity: float):
	"""Set intensity immediately without smoothing."""
	current_intensity = clamp(new_intensity, 0.0, 1.0)
	target_intensity = current_intensity
	if shader_material:
		shader_material.set_shader_parameter("time_intensity", current_intensity)
	intensity_changed.emit(current_intensity)

func set_blend_mode(new_blend_mode: BlendMode):
	"""Change the blend mode for this layer."""
	blend_mode = new_blend_mode
	if color_rect:
		_set_blend_mode()

func set_shader(new_shader: Shader):
	"""Hot-swap the shader for this layer."""
	shader_resource = new_shader
	if shader_material:
		shader_material.shader = new_shader

func set_layer_order(new_order: int):
	"""Change the rendering order of this layer."""
	layer_order = new_order
	if canvas_layer:
		canvas_layer.layer = canvas_layer_value + layer_order

func get_current_intensity() -> float:
	"""Get the current intensity value."""
	return current_intensity

func is_enabled() -> bool:
	"""Check if this layer is enabled."""
	return enabled

# === SHADER PARAMETER HELPERS ===

func set_shader_param(param_name: String, value):
	"""Set a shader parameter by name."""
	if shader_material:
		shader_material.set_shader_parameter(param_name, value)

func get_shader_param(param_name: String):
	"""Get a shader parameter by name."""
	if shader_material:
		return shader_material.get_shader_parameter(param_name)
	return null
