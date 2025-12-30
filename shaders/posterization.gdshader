#define FLT_MAX 3.402823466e+38

shader_type canvas_item;
render_mode unshaded;

/* ---------- Posterization ---------- */
uniform vec4[256] colors : source_color;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

/* ---------- Crosshatching ---------- */
uniform sampler2D hatch_tex : source_color, repeat_enable;
uniform float hatch_scale = 6.0;

/* Controls */
uniform float hatch_start = 0.85; // brightness where hatching begins
uniform float hatch_end   = 0.25; // brightness where hatching is strongest
uniform float ink_strength = 1.0; // overall ink intensity

vec3 rgb_to_lab(vec4 rgb){
	float R = rgb.r;
	float G = rgb.g;
	float B = rgb.b;

	float X = R * 0.412453 + G * 0.357580 + B * 0.180423;
	float Y = R * 0.212671 + G * 0.715160 + B * 0.072169;
	float Z = R * 0.019334 + G * 0.119193 + B * 0.950227;

	X /= 0.950456;
	Z /= 1.088754;

	float fx = X > 0.008856 ? pow(X, 1.0/3.0) : (7.787 * X + 16.0/116.0);
	float fy = Y > 0.008856 ? pow(Y, 1.0/3.0) : (7.787 * Y + 16.0/116.0);
	float fz = Z > 0.008856 ? pow(Z, 1.0/3.0) : (7.787 * Z + 16.0/116.0);

	float L = Y > 0.008856 ? (116.0 * pow(Y, 1.0/3.0) - 16.0) : (903.3 * Y);
	float a = 500.0 * (fx - fy);
	float b = 200.0 * (fy - fz);

	return vec3(L, a, b);
}

void fragment() {
	vec4 screen_col = texture(SCREEN_TEXTURE, SCREEN_UV);

	/* ---------- Posterize ---------- */
	vec4 poster_col = colors[0];
	float min_dist = FLT_MAX;

	for (int i = 0; i < colors.length(); i++) {
		float d = distance(
			rgb_to_lab(screen_col),
			rgb_to_lab(colors[i])
		);
		if (d < min_dist) {
			min_dist = d;
			poster_col = colors[i];
		}
	}

	/* ---------- Brightness ---------- */
	float brightness = dot(poster_col.rgb, vec3(0.299, 0.587, 0.114));

	/* ---------- Hatch Pattern ---------- */
	vec2 hatch_uv = SCREEN_UV * hatch_scale;
	float hatch = 1.0 - texture(hatch_tex, hatch_uv).r;

	/* ---------- Hatch Mask (earlier + stronger) ---------- */
	float hatch_mask = smoothstep(
		hatch_start,
		hatch_end,
		brightness
	) * ink_strength;

	/* ---------- Clamp ink to black ---------- */
	vec3 inked = mix(
		poster_col.rgb,
		vec3(0.0),          // pure black ink
		hatch * hatch_mask
	);

	COLOR = vec4(inked, 1.0);
}
