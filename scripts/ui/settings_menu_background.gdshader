shader_type canvas_item;

uniform float scrolling_speed = 0.1;

void vertex() {
	UV.x += TIME * scrolling_speed;
	UV.y -= TIME * scrolling_speed;
}
