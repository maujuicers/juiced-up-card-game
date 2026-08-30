shader_type canvas_item;

uniform sampler2D SCREEN_TEXTURE: hint_screen_texture, filter_linear_mipmap;
uniform float blur_amount: hint_range(0.0, 1.5) = 0.2;
uniform float wobble_strength: hint_range(0.0, 0.025) = 0.005;
uniform float wobble_speed: hint_range(0.0, 2.0) = 0.2;
uniform float chromatic_aberration: hint_range(0.0, 0.008) = 0.001;

void fragment() {
	// Wobble the UVs with layered sine waves so it doesn't feel too regular
	vec2 uv = SCREEN_UV;
	float t = TIME * wobble_speed;
	uv.x += sin(uv.y * 10.0 + t) * wobble_strength;
	uv.y += cos(uv.x * 10.0 + t * 0.8) * wobble_strength;

	// Chromatic aberration: sample R/G/B at slightly different offsets
	vec2 dir = normalize(uv - vec2(0.5)) * chromatic_aberration;
	float r = textureLod(SCREEN_TEXTURE, uv + dir, blur_amount).r;
	float g = textureLod(SCREEN_TEXTURE, uv, blur_amount).g;
	float b = textureLod(SCREEN_TEXTURE, uv - dir, blur_amount).b;
	vec3 result = vec3(r, g, b);

	COLOR.rgb = result;
}