shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture;
uniform sampler2D hatch_tex : source_color, repeat_enable;
uniform float hatch_scale = 4.0;
uniform float shadow_threshold = 0.5;

void fragment() {
	vec4 screen_col = texture(SCREEN_TEXTURE, SCREEN_UV);

float brightness = pow(
	dot(screen_col.rgb, vec3(0.299, 0.587, 0.114)),
	1.4

);


	vec2 hatch_uv = SCREEN_UV * hatch_scale;
	float hatch_val = texture(hatch_tex, hatch_uv).r;

	float mask = smoothstep(
		shadow_threshold + 0.05,
		shadow_threshold - 0.05,
		brightness
	);

	vec3 final_col = mix(
		screen_col.rgb,
		screen_col.rgb * hatch_val,
		mask
	);

	COLOR = vec4(final_col, 1.0);
}
