shader_type canvas_item;
render_mode unshaded;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform float strength : hint_range(0.0, 2.0) = 0.0;

void fragment() {
	vec2 uv = SCREEN_UV;

	vec2 offset = vec2(strength * 0.003, 0.0);

	float r = texture(SCREEN_TEXTURE, uv + offset).r;
	float g = texture(SCREEN_TEXTURE, uv).g;
	float b = texture(SCREEN_TEXTURE, uv - offset).b;

	COLOR = vec4(r, g, b, 1.0);
}
