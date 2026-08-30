// Inverted hull: the cat's own meshes redrawn front-culled and pushed out along
// their normals, so only the sliver that pokes outside the model survives.
shader_type spatial;
render_mode unshaded, cull_front, depth_draw_opaque, blend_mix, shadows_disabled, fog_disabled;

uniform vec4 outline_color : source_color = vec4(0.85, 0.1, 0.1, 0.8);
uniform float outline_width : hint_range(0.0, 0.05) = 0.012;

void vertex() {
	VERTEX += normalize(NORMAL) * outline_width;
}

void fragment() {
	ALBEDO = outline_color.rgb;
	ALPHA = outline_color.a;
}
