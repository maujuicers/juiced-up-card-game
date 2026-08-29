extends Node3D
class_name SeatMarker

## One chair at the table: a fixed transform plus the cat that sits in it.
## Participants are snapped here rather than spawned, so binding a peer to a
## seat (phase 4) is an index, not an instantiation.

## The cat's head: hidden for the first-person occupant (the camera sits inside
## it) and the node a remote player's look will drive later.
@export var head: Node3D
@export var body: Node3D

var occupant: Node3D


func occupy(participant: Node3D, first_person: bool) -> void:
	occupant = participant
	participant.global_transform = global_transform
	if head != null:
		head.visible = not first_person


func vacate() -> void:
	occupant = null
	if head != null:
		head.visible = true
