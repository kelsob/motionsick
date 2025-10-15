shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

// === CONNECTED MORPHING SHADER ===
// Maintains face connectivity while applying transformations
// Focused on keeping box meshes connected

// === TRANSFORMATION PARAMETERS ===
uniform float morph_intensity : hint_range(0.0, 1.0) = 0.5;

// === ROTATION ===
uniform vec3 rotation_axis = vec3(0.0, 1.0, 0.0);
uniform float rotation_speed : hint_range(0.0, 5.0) = 1.0;

// === SCALE ===
uniform float scale_pulse_strength : hint_range(0.0, 1.0) = 0.3;
uniform float scale_pulse_speed : hint_range(0.0, 3.0) = 1.0;
uniform float vertex_phase_offset : hint_range(0.0, 6.28) = 1.0; // How much phase offset between vertices

// === TRANSLATION ===
uniform float translation_strength : hint_range(0.0, 2.0) = 0.5;
uniform float translation_speed : hint_range(0.0, 3.0) = 1.0;

// === TIME-BASED ANIMATION ===
uniform float time_scale : hint_range(0.1, 3.0) = 1.0;

// === MATERIAL PROPERTIES ===
uniform vec4 base_color : source_color = vec4(0.1, 0.1, 0.15, 1.0);
uniform vec4 edge_color : source_color = vec4(0.3, 0.6, 1.0, 1.0);
uniform float metallic : hint_range(0.0, 1.0) = 0.9;
uniform float roughness : hint_range(0.0, 1.0) = 0.2;
uniform float edge_glow_intensity : hint_range(0.0, 10.0) = 2.0;
uniform float fresnel_power : hint_range(0.1, 10.0) = 3.0;


// === HELPER FUNCTIONS ===

// Quaternion rotation
vec3 rotate_vertex(vec3 pos, vec3 axis, float angle) {
	axis = normalize(axis);
	float s = sin(angle);
	float c = cos(angle);
	float oc = 1.0 - c;
	
	mat3 rot = mat3(
		vec3(oc * axis.x * axis.x + c,           oc * axis.x * axis.y + axis.z * s,  oc * axis.z * axis.x - axis.y * s),
		vec3(oc * axis.x * axis.y - axis.z * s,  oc * axis.y * axis.y + c,           oc * axis.y * axis.z + axis.x * s),
		vec3(oc * axis.z * axis.x + axis.y * s,  oc * axis.y * axis.z - axis.x * s,  oc * axis.z * axis.z + c)
	);
	
	return rot * pos;
}

void vertex() {
	vec3 local_pos = VERTEX;
	
	// Get time-based animation
	float time = TIME * time_scale;
	
	// === UNIFORM ROTATION ===
	// Rotate entire mesh around specified axis
	float rotation_angle = time * rotation_speed * morph_intensity;
	vec3 rotated_pos = rotate_vertex(local_pos, rotation_axis, rotation_angle);
	
	// === PHASE-OFFSET SCALE PULSE ===
	// Each vertex gets a different phase offset for the wave
	// Use vertex position to create a unique phase for each vertex
	float vertex_phase = (local_pos.x + local_pos.y + local_pos.z) * vertex_phase_offset;
	float scale_factor = 1.0 + sin(time * scale_pulse_speed + vertex_phase) * scale_pulse_strength * morph_intensity;
	vec3 scaled_pos = rotated_pos * scale_factor;
	
	// === UNIFORM TRANSLATION ===
	// Translate entire mesh (maintains connectivity)
	vec3 translation = vec3(
		sin(time * translation_speed) * translation_strength * morph_intensity,
		cos(time * translation_speed * 1.2) * translation_strength * morph_intensity,
		sin(time * translation_speed * 0.8) * translation_strength * morph_intensity
	);
	
	// Apply translation
	vec3 final_pos = scaled_pos + translation;
	
	// Update vertex position
	VERTEX = final_pos;
	
	// Recalculate normal for lighting
	NORMAL = normalize(NORMAL);
}

void fragment() {
	// === BASE COLOR ===
	vec3 base = base_color.rgb;
	
	// === FRESNEL EDGE GLOW ===
	float fresnel = pow(1.0 - dot(NORMAL, VIEW), fresnel_power);
	vec3 edge_glow = edge_color.rgb * fresnel * edge_glow_intensity;
	
	// === COMBINE ===
	ALBEDO = base;
	EMISSION = edge_glow;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	SPECULAR = 0.5;
}
