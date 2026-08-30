extends Node3D
class_name SeatMarker

## One chair at the table: a fixed transform plus the cat that sits in it.
## Participants are snapped here rather than spawned, so binding a peer to a
## seat (phase 4) is an index, not an instantiation.

## The cat's head: hidden for the first-person occupant (the camera sits inside
## it) and the node a remote player's look drives.
@export var head: Node3D
@export var body: Node3D
## What the crosshair has to hit to accuse this seat; disabled for the
## first-person occupant, whose own camera sits inside it.
@export var aim_area: Area3D

@export_group("Highlight")
@export var outline_shader: Shader
@export var outline_color := Color(0.85, 0.1, 0.1, 0.8)
@export_range(0.0, 0.05, 0.001, "suffix:m") var outline_width: float = 0.007

var occupant: Node3D

## The head's authored orientation, which [method look] rotates away from rather
## than overwrites — the model's own facing is baked into it.
var _head_rest := Basis.IDENTITY

var _outline_shells: Array[MeshInstance3D] = []
var _highlighted := false
## The layer the aim area was authored on, restored when the seat is vacated.
var _aim_layer: int = 0


func _ready() -> void:
	if head != null:
		_head_rest = head.transform.basis
	if aim_area != null:
		_aim_layer = aim_area.collision_layer


func occupy(participant: Node3D, first_person: bool) -> void:
	occupant = participant
	participant.global_transform = global_transform
	if head != null:
		head.visible = not first_person
	if aim_area != null:
		aim_area.collision_layer = 0 if first_person else _aim_layer


func vacate() -> void:
	occupant = null
	set_highlighted(false)
	if head != null:
		head.visible = true
		head.transform.basis = _head_rest
	if aim_area != null:
		aim_area.collision_layer = _aim_layer


## Point the cat's head where the seat's player is looking. Both angles are in
## the marker's own frame, which is also the occupant's — a participant is
## snapped onto this transform — so they are the occupant's head yaw and camera
## pitch unchanged.
func look(yaw: float, pitch: float) -> void:
	if head == null:
		return
	head.transform.basis = Basis.from_euler(Vector3(pitch, yaw, 0.0)) * _head_rest


## A thin red rim around this seat's cat — the aim feedback for an accusation.
func set_highlighted(on: bool) -> void:
	if on == _highlighted:
		return
	_highlighted = on
	if on and _outline_shells.is_empty():
		_build_outline_shells()
	for shell in _outline_shells:
		shell.visible = on


func _build_outline_shells() -> void:
	if outline_shader == null:
		return

	var material := ShaderMaterial.new()
	material.shader = outline_shader
	material.set_shader_parameter("outline_color", outline_color)
	material.set_shader_parameter("outline_width", outline_width)

	var sources: Array[MeshInstance3D] = []
	for part in [head, body]:
		if part != null:
			_collect_meshes(part, sources)

	for source in sources:
		var shell := MeshInstance3D.new()
		shell.mesh = source.mesh
		shell.transform = source.transform
		shell.material_override = material
		shell.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		shell.visible = false
		# A sibling, not a child: the skinned parts' skeleton path is relative to
		# the mesh node, so only the same parent keeps it resolving.
		source.get_parent().add_child(shell)
		shell.skeleton = source.skeleton
		shell.skin = source.skin
		_outline_shells.append(shell)


func _collect_meshes(node: Node, out: Array[MeshInstance3D]) -> void:
	var mesh_node := node as MeshInstance3D
	if mesh_node != null and mesh_node.mesh != null:
		out.append(mesh_node)
	for child in node.get_children():
		_collect_meshes(child, out)
