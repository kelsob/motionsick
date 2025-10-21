shader_type canvas_item;

// === GLOW TIME EFFECT ===
// Additive glow effect for layering
// Designed to work with ADD blend mode for brightening effects

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform float time_intensity : hint_range(0.0, 1.0) = 0.0;

// Glow settings
uniform float glow_strength : hint_range(0.0, 2.0) = 0.5;
uniform vec3 glow_color : source_color = vec3(0.2, 0.5, 1.0); // Cool blue glow
uniform float glow_radius : hint_range(0.0, 0.1) = 0.02;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = vec2(0.5, 0.5);
	vec2 offset = uv - center;
	float dist = length(offset);
	
	// Create radial glow pattern
	float glow = 1.0 - smoothstep(0.0, glow_radius, dist);
	
	// Apply time intensity
	glow *= time_intensity * glow_strength;
	
	// Create glow color
	vec3 glow_color_final = glow_color * glow;
	
	// For additive blending, we want to output the glow contribution
	// The base layer will provide the screen content
	COLOR = vec4(glow_color_final, glow);
}
