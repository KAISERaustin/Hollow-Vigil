shader_type canvas_item;
// Display the generated bubble sprite with the same pixel-sized frame as the UI.
uniform vec4 source_region = vec4(0.0, 0.0, 1.0, 1.0);
uniform float extent = 32.0;
uniform float outline = 3.0;

void fragment() {
	vec2 point = UV * extent - vec2(extent * 0.5);
	vec2 q = abs(point) - vec2(extent * 0.5 - 4.0);
	float edge = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - 4.0;
	vec4 artwork = texture(TEXTURE, source_region.xy + UV * source_region.zw);
	float coverage = 1.0 - smoothstep(-0.5, 0.5, edge);
	float interior = 1.0 - smoothstep(-outline - 0.5, -outline + 0.5, edge);
	COLOR = vec4(artwork.rgb * interior, coverage);
}
