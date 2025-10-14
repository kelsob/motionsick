shader_type canvas_item;

// === BASIC TIME SCALE VISUAL EFFECT ===
// Interpolates between normal visuals (0.0) and time-dilated visuals (1.0)
// Effect: Desaturation + cool cyan tint

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

uniform float time_intensity : hint_range(0.0, 1.0) = 0.0;
uniform vec3 dilation_tint : source_color = vec3(0.4, 0.7, 1.0); // Cool cyan/blue tint
uniform float desaturation_strength : hint_range(0.0, 1.0) = 0.6; // How much to desaturate at full dilation

void fragment() {
	// Sample the screen texture
	vec4 screen_color = texture(screen_texture, SCREEN_UV);
	
	// Calculate luminance (grayscale)
	float luminance = dot(screen_color.rgb, vec3(0.299, 0.587, 0.114));
	vec3 grayscale = vec3(luminance);
	
	// Desaturate based on time intensity
	vec3 desaturated = mix(screen_color.rgb, grayscale, time_intensity * desaturation_strength);
	
	// Apply tint based on time intensity
	vec3 tinted = mix(desaturated, desaturated * dilation_tint, time_intensity * 0.5);
	
	// Output final color
	COLOR = vec4(tinted, screen_color.a);
}

