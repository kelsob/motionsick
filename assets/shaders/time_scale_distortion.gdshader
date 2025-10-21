shader_type canvas_item;

// === DISTORTION TIME EFFECT ===
// Screen distortion effect for layering
// Creates wave-like distortions that intensify with time dilation

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;

uniform float time_intensity : hint_range(0.0, 1.0) = 0.0;

// Distortion settings
uniform float distortion_strength : hint_range(0.0, 0.1) = 0.02;
uniform float wave_frequency : hint_range(1.0, 20.0) = 8.0;
uniform float wave_speed : hint_range(0.0, 5.0) = 1.0;

// Time for animation
uniform float time : hint_range(0.0, 100.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = vec2(0.5, 0.5);
	vec2 offset = uv - center;
	float dist = length(offset);
	
	// Create wave distortion
	float distortion = distortion_strength * time_intensity;
	
	// Multiple wave layers for complex distortion
	float wave1 = sin(dist * wave_frequency + time * wave_speed) * distortion;
	float wave2 = sin(dist * wave_frequency * 1.5 + time * wave_speed * 0.7) * distortion * 0.5;
	float wave3 = sin(dist * wave_frequency * 2.0 + time * wave_speed * 1.3) * distortion * 0.25;
	
	float total_wave = wave1 + wave2 + wave3;
	
	// Apply distortion to UV coordinates
	vec2 distorted_uv = uv + vec2(total_wave, total_wave * 0.7);
	
	// Sample the screen texture with distortion
	vec4 screen_color = texture(screen_texture, distorted_uv);
	
	// Output the distorted result
	COLOR = screen_color;
}
