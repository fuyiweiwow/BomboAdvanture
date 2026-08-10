shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;

uniform vec3 deep_color : source_color = vec3(0.035, 0.29, 0.36);
uniform vec3 shallow_color : source_color = vec3(0.10, 0.58, 0.64);
uniform vec3 highlight_color : source_color = vec3(0.38, 0.84, 0.84);

void fragment() {
	float wave_a = sin((UV.x * 43.0 + UV.y * 31.0) + TIME * 0.75);
	float wave_b = sin((UV.x * -27.0 + UV.y * 51.0) - TIME * 0.52);
	float ripples = wave_a * wave_b * 0.5 + 0.5;
	float edge = smoothstep(0.52, 0.15, length(UV - vec2(0.5)));
	ALBEDO = mix(shallow_color, deep_color, edge * 0.72);
	EMISSION = highlight_color * smoothstep(0.86, 1.0, ripples) * 0.16;
	METALLIC = 0.12;
	ROUGHNESS = mix(0.18, 0.32, ripples);
	ALPHA = 0.94;
}
