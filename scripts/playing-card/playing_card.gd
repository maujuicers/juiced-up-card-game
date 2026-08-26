@tool
extends Node3D
class_name PlayingCardVisual

## One card in the world: a [Sprite3D] for the face, an [Area3D] the mouse (and
## [Hand]'s click ray) can pick, and a quad behind the sprite that draws a soft
## glowing outline while the card is highlighted.

@export var card_sprite: Sprite3D
## Picking shape. Only used for mouse hover and clicks; it collides with nothing.
@export var pick_area: Area3D
## Quad carrying the outline shader, hidden unless the card is highlighted.
@export var outline_mesh: MeshInstance3D

@export_group("Outline")
## Colour of the glow drawn around the card.
@export var outline_color := Color(0.3, 1.0, 0.4):
	set(value):
		outline_color = value
		_push_outline_params()
## Width of the solid part of the border, in metres.
@export_range(0.0, 0.05, 0.0005) var outline_width := 0.0035:
	set(value):
		outline_width = value
		_push_outline_params()
## How far the soft falloff reaches past the solid part, in metres.
@export_range(0.0, 0.05, 0.0005) var glow_range := 0.013:
	set(value):
		glow_range = value
		_push_outline_params()
## Light up on mouse-over. Turn off for cards the user must not pick.
@export var hover_highlight := true

var card_data: Card
var face_up := true
var back_texture: Texture2D

## Set from outside via [method set_highlighted], e.g. for playable cards.
var _forced_highlight := false
var _hovered := false


func _ready() -> void:
	_push_outline_params()
	_refresh_outline()
	if Engine.is_editor_hint():
		return
	if pick_area != null:
		pick_area.mouse_entered.connect(_on_mouse_entered)
		pick_area.mouse_exited.connect(_on_mouse_exited)


## Shows [param data] face up, or the [param back] when [param up] is false.
## [param data] may be null for a face-down card whose identity is unknown.
func setup(data: Card, up: bool = true, back: Texture2D = null) -> void:
	card_data = data
	face_up = up
	back_texture = back
	_update_graphics()


## Turns the outline on or off from code, independent of the mouse.
func set_highlighted(on: bool) -> void:
	_forced_highlight = on
	_refresh_outline()


## True while the outline is showing, for whatever reason.
func is_highlighted() -> bool:
	return _forced_highlight or (_hovered and hover_highlight)


func _on_mouse_entered() -> void:
	_hovered = true
	_refresh_outline()


func _on_mouse_exited() -> void:
	_hovered = false
	_refresh_outline()


func _refresh_outline() -> void:
	if outline_mesh != null:
		outline_mesh.visible = is_highlighted()


## Copies the exported look onto this card's own copy of the shader material.
## The material is local to the scene, so every card can differ.
func _push_outline_params() -> void:
	if outline_mesh == null:
		return
	var material := outline_mesh.get_surface_override_material(0) as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("outline_color", outline_color)
	material.set_shader_parameter("outline_width", outline_width)
	material.set_shader_parameter("glow_range", glow_range)


func _update_graphics() -> void:
	if card_sprite == null:
		return
	if face_up and card_data != null and card_data.texture != null:
		card_sprite.texture = card_data.texture
	else:
		card_sprite.texture = back_texture
