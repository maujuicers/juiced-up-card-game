@tool
extends Control

## Small centred dot used as the player's pointer while the mouse is captured.
class_name Crosshair

## Diameter of the dot, in pixels.
@export_range(1.0, 32.0, 0.5, "or_greater", "suffix:px") var crosshair_size: float = 5.0:
	set(value):
		crosshair_size = value
		queue_redraw()

## Overall transparency: 1 is fully opaque, 0 hides the crosshair.
@export_range(0.0, 1.0, 0.01) var opacity: float = 1.0:
	set(value):
		opacity = value
		queue_redraw()

## Colour of the dot. Its own alpha is multiplied by `opacity`.
@export var color: Color = Color(1.0, 1.0, 1.0, 0.9):
	set(value):
		color = value
		queue_redraw()

## Colour of the thin ring drawn behind the dot for contrast.
@export var outline_color: Color = Color(0.0, 0.0, 0.0, 0.6):
	set(value):
		outline_color = value
		queue_redraw()

## Width the outline ring adds around the dot, in pixels.
@export_range(0.0, 4.0, 0.5, "or_greater", "suffix:px") var outline_thickness: float = 1.0:
	set(value):
		outline_thickness = value
		queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	if opacity <= 0.0:
		return
	var centre := size * 0.5
	var radius: float = maxf(crosshair_size * 0.5, 0.5)
	var ring := Color(outline_color, outline_color.a * opacity)
	if outline_thickness > 0.0 and ring.a > 0.0:
		draw_circle(centre, radius + outline_thickness, ring, true, -1.0, true)
	draw_circle(centre, radius, Color(color, color.a * opacity), true, -1.0, true)
