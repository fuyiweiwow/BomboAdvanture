shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

uniform vec4 road_color : source_color = vec4(0.46, 0.39, 0.27, 1.0);
uniform vec4 stone_color : source_color = vec4(0.68, 0.58, 0.39, 1.0);
uniform vec4 edge_color : source_color = vec4(0.30, 0.28, 0.23, 1.0);
uniform vec4 marking_color : source_color = vec4(0.84, 0.71, 0.36, 1.0);
uniform float paved = 0.0;
uniform float shoulder = 0.0;

float hash21(vec2 point) {
	point = fract(point * vec2(123.34, 456.21));
	point += dot(point, point + 45.32);
	return fract(point.x * point.y);
}

float value_noise(vec2 point) {
	vec2 cell = floor(point);
	vec2 local = fract(point);
	local = local * local * (3.0 - 2.0 * local);
	return mix(
		mix(hash21(cell), hash21(cell + vec2(1.0, 0.0)), local.x),
		mix(hash21(cell + vec2(0.0, 1.0)), hash21(cell + vec2(1.0, 1.0)), local.x),
		local.y
	);
}

void fragment() {
	float edge_mask = smoothstep(0.0, 0.15, UV.x) * smoothstep(0.0, 0.15, 1.0 - UV.x);
	float broad_noise = value_noise(vec2(UV.y * 0.72, UV.x * 5.0));
	float fine_noise = value_noise(vec2(UV.y * 5.4, UV.x * 23.0));
	float stone = smoothstep(0.76, 0.91, fine_noise + broad_noise * 0.18);
	float wheel_ruts = smoothstep(0.09, 0.0, abs(UV.x - 0.31)) + smoothstep(0.09, 0.0, abs(UV.x - 0.69));
	vec3 color = mix(road_color.rgb, stone_color.rgb, stone * (0.22 + paved * 0.12));
	color *= 0.91 + broad_noise * 0.16;
	color = mix(color, edge_color.rgb, (1.0 - edge_mask) * 0.82);
	color = mix(color, color * 0.72, wheel_ruts * (1.0 - paved) * 0.18);
	float center_mark = smoothstep(0.025, 0.009, abs(UV.x - 0.5));
	float dash = step(0.52, fract(UV.y * 0.44));
	color = mix(color, marking_color.rgb, center_mark * dash * paved * 0.78);
	color = mix(color, edge_color.rgb, shoulder * 0.28);
	ALBEDO = color;
	ROUGHNESS = mix(0.96, 0.78, paved);
	SPECULAR = 0.12 + paved * 0.12;
}
