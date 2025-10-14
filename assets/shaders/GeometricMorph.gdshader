shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

// === GEOMETRIC HORROR MORPHING SHADER ===
// Creates impossible geometric transformations via vertex displacement
// Inspired by Ramiel from Evangelion - clean, mathematical, crystalline horror

// === MORPH PARAMETERS ===
// These drive the geometric transformations
uniform float morph_intensity : hint_range(0.0, 1.0) = 0.5;
uniform float face_expansion : hint_range(-1.0, 1.0) = 0.0;
uniform float twist_amount : hint_range(-3.14159, 3.14159) = 0.0;
uniform float pulse_scale : hint_range(0.5, 2.0) = 1.0;

// === ROTATION AXES ===
uniform vec3 rotation_axis = vec3(0.0, 1.0, 0.0);
uniform float rotation_angle : hint_range(0.0, 6.28318) = 0.0;

// === NOISE-BASED DEFORMATION ===
uniform float noise_scale : hint_range(0.0, 10.0) = 2.0;
uniform float noise_strength : hint_range(0.0, 1.0) = 0.3;
uniform vec3 noise_offset = vec3(0.0, 0.0, 0.0);

// === MATERIAL PROPERTIES ===
uniform vec4 base_color : source_color = vec4(0.1, 0.1, 0.15, 1.0);
uniform vec4 edge_color : source_color = vec4(0.3, 0.6, 1.0, 1.0);
uniform float metallic : hint_range(0.0, 1.0) = 0.9;
uniform float roughness : hint_range(0.0, 1.0) = 0.2;
uniform float edge_glow_intensity : hint_range(0.0, 10.0) = 2.0;
uniform float fresnel_power : hint_range(0.1, 10.0) = 3.0;

// === HELPER FUNCTIONS ===

// Simple 3D noise function
float noise3d(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	
	float n = i.x + i.y * 57.0 + 113.0 * i.z;
	return mix(
		mix(
			mix(fract(sin(n) * 43758.5453), fract(sin(n + 1.0) * 43758.5453), f.x),
			mix(fract(sin(n + 57.0) * 43758.5453), fract(sin(n + 58.0) * 43758.5453), f.x),
			f.y
		),
		mix(
			mix(fract(sin(n + 113.0) * 43758.5453), fract(sin(n + 114.0) * 43758.5453), f.x),
			mix(fract(sin(n + 170.0) * 43758.5453), fract(sin(n + 171.0) * 43758.5453), f.x),
			f.y
		),
		f.z
	);
}

// Quaternion rotation
vec3 rotate_vertex(vec3 pos, vec3 axis, float angle) {
	axis = normalize(axis);
	float s = sin(angle);
	float c = cos(angle);
	float oc = 1.0 - c;
	
	// GLSL mat3 is constructed column-by-column
	mat3 rot = mat3(
		vec3(oc * axis.x * axis.x + c,           oc * axis.x * axis.y + axis.z * s,  oc * axis.z * axis.x - axis.y * s),
		vec3(oc * axis.x * axis.y - axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z + axis.x * s),
		vec3(oc * axis.z * axis.x + axis.y * s,  oc * axis.y * axis.z - axis.x * s,  oc * axis.z * axis.z + c)
	);
	
	return rot * pos;
}

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 local_pos = VERTEX;
	
	// === 1. NOISE-BASED DEFORMATION ===
	// Adds organic-but-structured variation
	float n = noise3d((world_pos + noise_offset) * noise_scale);
	vec3 noise_displacement = NORMAL * (n - 0.5) * noise_strength * morph_intensity;
	
	// === 2. FACE EXPANSION ===
	// Vertices move along normals (faces bulge or collapse)
	vec3 expansion_displacement = NORMAL * face_expansion * morph_intensity;
	
	// === 3. TWIST DEFORMATION ===
	// Twist geometry along local Y axis based on height
	float twist_factor = local_pos.y * twist_amount;
	vec3 twisted_pos = rotate_vertex(local_pos, vec3(0.0, 1.0, 0.0), twist_factor);
	vec3 twist_displacement = (twisted_pos - local_pos) * morph_intensity;
	
	// === 4. PULSE SCALE ===
	// Uniform scale pulsing
	vec3 scaled_pos = local_pos * pulse_scale;
	vec3 scale_displacement = (scaled_pos - local_pos);
	
	// === 5. AXIS ROTATION ===
	// Rotate entire geometry on arbitrary axis
	vec3 rotated_pos = rotate_vertex(local_pos, rotation_axis, rotation_angle);
	
	// === COMBINE ALL TRANSFORMATIONS ===
	VERTEX = rotated_pos 
		+ noise_displacement 
		+ expansion_displacement 
		+ twist_displacement 
		+ scale_displacement;
	
	// Recalculate normal for lighting
	// (Approximation - good enough for our purposes)
	NORMAL = normalize(NORMAL + noise_displacement * 0.1);
}

void fragment() {
	// === BASE COLOR ===
	vec3 base = base_color.rgb;
	
	// === FRESNEL EDGE GLOW ===
	// Edges glow based on viewing angle
	float fresnel = pow(1.0 - dot(NORMAL, VIEW), fresnel_power);
	vec3 edge_glow = edge_color.rgb * fresnel * edge_glow_intensity;
	
	// === COMBINE ===
	ALBEDO = base;
	EMISSION = edge_glow;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = 0.5;
}

