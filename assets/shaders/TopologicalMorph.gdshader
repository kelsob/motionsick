shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

// === TOPOLOGICAL MORPHING SHADER ===
// Simulates mesh evolution by growing/shrinking faces and edges
// Uses vertex colors to define which vertices belong to which "evolution stage"

// === VERTEX SELECTION ===
uniform float morph_intensity : hint_range(0.0, 1.0) = 0.5;
uniform int vertex_selection_mode : hint_range(0, 3) = 0; // 0=every other, 1=grid, 2=spiral, 3=random
uniform float selection_density : hint_range(0.1, 2.0) = 1.0;

// === FACE GROWTH ===
uniform float face_growth_strength : hint_range(0.0, 2.0) = 1.0;
uniform float face_growth_period : hint_range(0.1, 10.0) = 1.0;

// === VERTEX COLLAPSE ===
uniform float vertex_collapse_strength : hint_range(0.0, 1.0) = 0.3;
uniform float vertex_collapse_period : hint_range(0.1, 10.0) = 1.0;

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

// Check if vertex should be selected for morphing
bool is_vertex_selected(vec3 local_pos) {
	if (vertex_selection_mode == 0) {
		// Every other vertex (checkerboard pattern)
		float sum = local_pos.x + local_pos.y + local_pos.z;
		return mod(floor(sum * selection_density), 2.0) < 1.0;
	} else if (vertex_selection_mode == 1) {
		// Grid pattern
		float x_grid = mod(floor(local_pos.x * selection_density), 2.0);
		float y_grid = mod(floor(local_pos.y * selection_density), 2.0);
		return (x_grid + y_grid) < 1.0;
	} else if (vertex_selection_mode == 2) {
		// Spiral pattern
		float angle = atan(local_pos.y, local_pos.x);
		float radius = length(local_pos.xy);
		return mod(floor(angle * selection_density + radius * 2.0), 2.0) < 1.0;
	} else {
		// Random-ish pattern
		float hash = sin(local_pos.x * 12.9898 + local_pos.y * 78.233 + local_pos.z * 37.719);
		return hash > (0.5 - selection_density * 0.2);
	}
}

// Calculate morphing displacement
vec3 calculate_morphing(vec3 local_pos, float time) {
	// ALL vertices morph, but in different ways based on selection
	vec3 displacement = vec3(0.0);
	
	// Get selection strength (0.0 to 1.0)
	float selection_strength = 0.0;
	if (vertex_selection_mode == 0) {
		// Every other vertex (checkerboard pattern)
		float sum = local_pos.x + local_pos.y + local_pos.z;
		selection_strength = mod(floor(sum * selection_density), 2.0) < 1.0 ? 1.0 : 0.3;
	} else if (vertex_selection_mode == 1) {
		// Grid pattern
		float x_grid = mod(floor(local_pos.x * selection_density), 2.0);
		float y_grid = mod(floor(local_pos.y * selection_density), 2.0);
		selection_strength = (x_grid + y_grid) < 1.0 ? 1.0 : 0.3;
	} else if (vertex_selection_mode == 2) {
		// Spiral pattern
		float angle = atan(local_pos.y, local_pos.x);
		float radius = length(local_pos.xy);
		selection_strength = mod(floor(angle * selection_density + radius * 2.0), 2.0) < 1.0 ? 1.0 : 0.3;
	} else {
		// Random-ish pattern
		float hash = sin(local_pos.x * 12.9898 + local_pos.y * 78.233 + local_pos.z * 37.719);
		selection_strength = hash > (0.5 - selection_density * 0.2) ? 1.0 : 0.3;
	}
	
	// 1. Face growth: move outward from center
	float growth_factor = sin(time * face_growth_period) * face_growth_strength * selection_strength;
	vec3 growth_direction = normalize(local_pos);
	displacement += growth_direction * growth_factor;
	
	// 2. Vertex collapse: move toward center (opposite phase for different groups)
	float collapse_factor = sin(time * vertex_collapse_period + 3.14) * vertex_collapse_strength * (2.0 - selection_strength);
	vec3 collapse_direction = normalize(vec3(0.0, 0.0, 0.0) - local_pos);
	displacement += collapse_direction * collapse_factor;
	
	return displacement * morph_intensity;
}


void vertex() {
	vec3 local_pos = VERTEX;
	
	// Get time-based animation
	float time = TIME * time_scale;
	
	// Calculate morphing displacement
	vec3 final_displacement = calculate_morphing(local_pos, time);
	
	// Apply displacement
	VERTEX = local_pos + final_displacement;
	
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
