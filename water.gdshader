shader_type spatial;
render_mode blend_mix, cull_back;

// user settings
uniform float speed : hint_range(-4.0, 4.0) = 0.0;

// colors / textures
uniform sampler2D noise1;
uniform sampler2D noise2;
uniform sampler2D normalmap; // import as Normal Map in the texture import settings
uniform sampler2D DEPTH_TEXTURE : hint_depth_texture, filter_linear_mipmap;
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;
uniform vec4 color = vec4(0.0, 0.4, 0.6, 1.0);
uniform vec4 edge_color = vec4(1.0, 1.0, 1.0, 1.0);

// foam / edge
uniform float edge_scale : hint_range(0.0, 1.0) = 0.25;
uniform float z_near : hint_range(0.01, 10.0) = 0.1;
uniform float z_far : hint_range(1.0, 1000.0) = 100.0;

// waves
uniform vec2 wave_strength = vec2(0.5, 0.25);
uniform vec2 wave_frequency = vec2(12.0, 12.0);
uniform vec2 time_factor = vec2(1.0, 2.0);

float linearize_depth(float d) {
	float z = 2.0 * d - 1.0;
	return (z_near * z_far) / (z_far + z * (z_near - z_far));
}

float waves(vec2 pos, float t) {
	return (wave_strength.y * sin(pos.y * wave_frequency.y + t * time_factor.y))
	     + (wave_strength.x * sin(pos.x * wave_frequency.x + t * time_factor.x));
}

void vertex() {
	float t = TIME * speed;
	VERTEX.y += waves(VERTEX.xz, t);
}

void fragment() {
	float t = TIME * speed;
	vec2 uv = UV;
	
	vec3 n1 = texture(noise1, uv + vec2(t * 0.05, t * 0.05)).rgb;
	vec3 n2 = texture(noise2, uv - vec2(t * 0.02, t * 0.02)).rgb;
	
	vec2 uv_movement = uv * 4.0 + vec2(TIME * speed * 4.0, TIME * speed * 4.0);
	
	float sum = (n1.r + n2.r) - 1.0;
	
	float scene_depth_raw = texture(DEPTH_TEXTURE, SCREEN_UV).r;
	float scene_z = linearize_depth(scene_depth_raw);
	
	float frag_raw = FRAGCOORD.z;
	float frag_z = linearize_depth(frag_raw);
	
	float diff = scene_z - frag_z;
	
	vec2 displacement = vec2(sum * 0.05, sum * 0.05);
	diff += displacement.x * 50.0;
	
	vec4 col = mix(edge_color, color, step(edge_scale, diff));
	
	vec4 screen_sample = texture(SCREEN_TEXTURE, SCREEN_UV + displacement);
	
	float fin = 0.0;
	if (sum > 0.0 && sum < 0.4) fin = 0.1;
	if (sum > 0.4 && sum < 0.8) fin = 0.0;
	if (sum > 0.8) fin = 1.0;
	
	ALBEDO = vec3(fin) + mix(screen_sample.rgb, col.rgb, color.a);
	
	vec3 nm = texture(normalmap, uv_movement).rgb;
	nm = nm * 2.0 - 1.0;
	// assign to the built-in NORMAL output (replace the removed NORMALMAP)
	NORMAL = normalize(nm);
	
	ROUGHNESS = 0.1;
	METALLIC = 0.0;
	SPECULAR = 0.5;
	ALPHA = 1.0;
}