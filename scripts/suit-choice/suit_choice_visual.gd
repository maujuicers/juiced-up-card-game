@tool
extends Node3D
class_name SuitChoiceVisual

@export var suit_sprite: Sprite3D
@export var pick_area: Area3D
@export var outline_mesh: MeshInstance3D
@export var suit: Card.Suit

@export_group("Outline")
@export var outline_color := Color(0.3, 1.0, 0.4):
	set(value):
		outline_color = value
		_push_outline_params()
@export_range(0.0, 0.05, 0.0005) var outline_width := 0.0035:
	set(value):
		outline_width = value
		_push_outline_params()
@export_range(0.0, 0.05, 0.0005) var glow_range := 0.013:
	set(value):
		glow_range = value
		_push_outline_params()
@export var hover_highlight := true

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

func set_highlighted(on: bool) -> void:
	_forced_highlight = on
	_refresh_outline()


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


# The material is local to the scene, so every suit choice can differ.
func _push_outline_params() -> void:
	if outline_mesh == null:
		return
	var material := outline_mesh.get_surface_override_material(0) as ShaderMaterial
	if material == null:
		return
	material.set_shader_parameter("outline_color", outline_color)
	material.set_shader_parameter("outline_width", outline_width)
	material.set_shader_parameter("glow_range", glow_range)
