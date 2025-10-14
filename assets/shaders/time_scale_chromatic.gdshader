shader_type canvas_item;

// === CHROMATIC ABERRATION TIME EFFECT ===
// More intense visual: chromatic aberration, vignette, distortion
// Really sells the "reality is breaking" feeling of time dilation

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform float time_intensity : hint_range(0.0, 1.0) = 0.0;

// Chromatic aberration settings
uniform float aberration_strength : hint_range(0.0, 0.05) = 0.015;

// Vignette settings
uniform float vignette_strength : hint_range(0.0, 1.0) = 0.5;
uniform float vignette_radius : hint_range(0.0, 2.0) = 0.8;

// Color grading
uniform vec3 dilation_tint : source_color = vec3(0.3, 0.6, 1.0);
uniform float desaturation_strength : hint_range(0.0, 1.0) = 0.7;

// Radial distortion
uniform float distortion_strength : hint_range(0.0, 0.5) = 0.02;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = vec2(0.5, 0.5);
	vec2 offset = uv - center;
	float dist = length(offset);
	
	// === RADIAL DISTORTION ===
	// Subtle "lens warp" effect that intensifies with time dilation
	float distortion = distortion_strength * time_intensity;
	vec2 distorted_uv = center + offset * (1.0 + distortion * dist);
	
	// === CHROMATIC ABERRATION ===
	// Separate RGB channels in 3 different directions (120° apart)
	float aberration = aberration_strength * time_intensity;
	
	// Define direction for each channel (in radians)
	// Red: 0° (up), Green: 120° (down-right), Blue: 240° (down-left)
	float red_angle = 0.0;                    // 0°
	float green_angle = 2.094395;             // 120° in radians
	float blue_angle = 4.188790;              // 240° in radians
	
	// Calculate directional offsets for each channel
	vec2 r_direction = vec2(sin(red_angle), -cos(red_angle));
	vec2 g_direction = vec2(sin(green_angle), -cos(green_angle));
	vec2 b_direction = vec2(sin(blue_angle), -cos(blue_angle));
	
	// Apply aberration in each direction
	vec2 r_offset = distorted_uv + (r_direction * aberration);
	vec2 g_offset = distorted_uv + (g_direction * aberration);
	vec2 b_offset = distorted_uv + (b_direction * aberration);
	
	float r = texture(screen_texture, r_offset).r;
	float g = texture(screen_texture, g_offset).g;
	float b = texture(screen_texture, b_offset).b;
	
	vec3 aberrated_color = vec3(r, g, b);
	
	// === DESATURATION ===
	float luminance = dot(aberrated_color, vec3(0.299, 0.587, 0.114));
	vec3 grayscale = vec3(luminance);
	vec3 desaturated = mix(aberrated_color, grayscale, time_intensity * desaturation_strength);
	
	// === COLOR TINT ===
	vec3 tinted = mix(desaturated, desaturated * dilation_tint, time_intensity * 0.6);
	
	// === VIGNETTE ===
	// Darken edges when time dilates
	float vignette = smoothstep(vignette_radius, vignette_radius - 0.5, dist);
	vignette = mix(1.0, vignette, time_intensity * vignette_strength);
	
	// === FINAL COMPOSITE ===
	vec3 final_color = tinted * vignette;
	
	COLOR = vec4(final_color, 1.0);
}

