shader_type canvas_item;
render_mode unshaded;

// ImageGen supplied a pale neutral presentation matte. Key only that range;
// the approved bone, stone, mint and violet character fills are darker or tinted.
void fragment() {
	vec4 sample_color = texture(TEXTURE, UV);
	float matte = min(sample_color.r, min(sample_color.g, sample_color.b));
	float opacity = 1.0 - smoothstep(0.89, 0.94, matte);
	COLOR = vec4(sample_color.rgb, sample_color.a * opacity);
}
