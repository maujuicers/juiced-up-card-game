// Soft green "glow" border for a playing card, drawn on a quad a little larger than the card.
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never, shadows_disabled, fog_disabled;

uniform vec4 outline_color : source_color = vec4(0.3, 1.0, 0.4, 1.0);
// Size of this quad and of the card it frames
uniform vec2 quad_size = vec2(0.110125, 0.145325);
uniform vec2 card_size = vec2(0.070125, 0.105325);
// Solid part of the border, measured outwards from the card edge.
uniform float outline_width : hint_range(0.0, 0.05) = 0.004;
// How far the soft falloff reaches past the solid part.
uniform float glow_range : hint_range(0.0, 0.05) = 0.013;
uniform float glow_strength : hint_range(0.0, 1.0) = 0.9;
uniform float corner_radius : hint_range(0.0, 0.02) = 0.003;
// The border fades out this far inside the card, so the face stays readable.
uniform float inner_fade : hint_range(0.0001, 0.02) = 0.0012;

void fragment() {
	// Position inside the quad, in metres, relative to the card's centre.
	vec2 p = (UV - vec2(0.5)) * quad_size;
	// Signed distance to the card's rounded rectangle.
	vec2 h = max(card_size * 0.5 - vec2(corner_radius), vec2(0.0));
	vec2 q = abs(p) - h;
	float d = length(max(q, vec2(0.0))) + min(max(q.x, q.y), 0.0) - corner_radius;

	float outside = max(d, 0.0);
	// Solid band hugging the card, then a quadratic falloff around it.
	float core = 1.0 - smoothstep(outline_width * 0.6, outline_width, outside);
	float falloff = clamp(1.0 - max(outside - outline_width, 0.0) / max(glow_range, 0.0001), 0.0, 1.0);
	float glow = pow(falloff, 1.6) * glow_strength;

	// Transparent over the card itself
	float inside = smoothstep(-inner_fade, 0.0, d);

	ALBEDO = outline_color.rgb;
	ALPHA = clamp(core + glow, 0.0, 1.0) * inside * outline_color.a;
}
