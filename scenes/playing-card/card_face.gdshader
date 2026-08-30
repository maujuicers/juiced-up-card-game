// A card face with rounded corners: the atlas art is a square white rectangle,
// so the corners are cut here with the same rounded-rect distance the outline uses.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_always, shadows_disabled, fog_disabled;

uniform sampler2D face : source_color, filter_linear_mipmap_anisotropic;
// The part of `face` to show, in UV units: xy offset, zw size (an atlas region).
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);
// The atlas stores faces mirrored.
uniform bool mirror = true;
uniform vec2 card_size = vec2(0.071225, 0.106425);
uniform float corner_radius : hint_range(0.0, 0.02) = 0.0035;
uniform float edge_softness : hint_range(0.0, 0.002) = 0.0002;

void fragment() {
	vec2 uv = UV;
	if (mirror) {
		uv.x = 1.0 - uv.x;
	}
	vec4 tex = texture(face, region.xy + uv * region.zw);

	vec2 p = (UV - vec2(0.5)) * card_size;
	vec2 h = max(card_size * 0.5 - vec2(corner_radius), vec2(0.0));
	vec2 q = abs(p) - h;
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner_radius;

	ALBEDO = tex.rgb;
	ALPHA = tex.a * (1.0 - smoothstep(-edge_softness, edge_softness, d));
}
