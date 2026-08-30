extends Node3D
class_name SeatMarker

## One chair at the table: a fixed transform plus the cat that sits in it.
## Participants are snapped here rather than spawned, so binding a peer to a
## seat (phase 4) is an index, not an instantiation.

## The cat's head: hidden for the first-person occupant (the camera sits inside
## it) and the node a remote player's look drives.
@export var head: Node3D
@export var body: Node3D

var occupant: Node3D

## The head's authored orientation, which [method look] rotates away from rather
## than overwrites — the model's own facing is baked into it.
var _head_rest := Basis.IDENTITY


func _ready() -> void:
	if head != null:
		_head_rest = head.transform.basis


func occupy(participant: Node3D, first_person: bool) -> void:
	occupant = participant
	participant.global_transform = global_transform
	if head != null:
		head.visible = not first_person


func vacate() -> void:
	occupant = null
	if head != null:
		head.visible = true
		head.transform.basis = _head_rest


## Point the cat's head where the seat's player is looking. Both angles are in
## the marker's own frame, which is also the occupant's — a participant is
## snapped onto this transform — so they are the occupant's head yaw and camera
## pitch unchanged.
func look(yaw: float, pitch: float) -> void:
	if head == null:
		return
	head.transform.basis = Basis.from_euler(Vector3(pitch, yaw, 0.0)) * _head_rest
