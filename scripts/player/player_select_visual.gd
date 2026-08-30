extends Node3D
class_name PlayerSelectVisual

@export var arrow_mesh: MeshInstance3D
@export var pick_area: Area3D

@export var default_color := Color(1.0, 1.0, 1.0)
@export var looked_at_color := Color(1.0, 0.0, 0.0)

var _player: MauMauPlayer
var _manager: Node
var _material: StandardMaterial3D
