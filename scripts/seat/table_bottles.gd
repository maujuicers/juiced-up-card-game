extends Node3D
class_name TableBottles

## The bottles standing on the players' table, one per seat. It listens only to
## the manager's public [signal MauMauGameManager.seat_bottle] and
## [signal MauMauGameManager.seat_drinking], so the local seat and a remote one
## take exactly the same path — how full a bottle is stays private.

@export var manager: MauMauGameManager
@export var bottle_scene: PackedScene
## Where a bottle stands in the seat marker's own frame: on the table top, to the
## seat's right of its fan and clear of the card in the middle.
@export var bottle_offset := Vector3(0.4, 0.4737, -0.52)

## Seat -> its bottle node.
var _bottles: Dictionary = {}
## Seat -> whether it is drinking, so a bottle delivered mid-sip arrives hidden.
var _drinking: Dictionary = {}


func _ready() -> void:
	if manager == null:
		return
	manager.seat_bottle.connect(_on_seat_bottle)
	manager.seat_drinking.connect(_on_seat_drinking)
	# Offline the manager deals inside its own _ready, which is over before this one.
	_catch_up.call_deferred()


func _catch_up() -> void:
	for seat in manager.turn_order.size():
		var seated: MauMauPlayer = manager.turn_order[seat]
		if seated.is_drinking:
			_on_seat_drinking(seat, true)
		if seated.bottle_content() > 0:
			_on_seat_bottle(seat, true)


func _on_seat_bottle(seat: int, present: bool) -> void:
	if not present:
		_remove(seat)
		return
	if _bottles.has(seat) or bottle_scene == null:
		return
	var marker := manager.marker_for_seat(seat)
	if marker == null:
		return
	var bottle := bottle_scene.instantiate() as Node3D
	if bottle == null:
		push_error("%s cannot place a bottle: %s is not a Node3D" % [self, bottle_scene])
		return
	add_child(bottle)
	# Only the placement comes from the marker; the markers are yaw-only, but a
	# bottle stands upright whatever the chair does.
	bottle.global_position = marker.to_global(bottle_offset)
	bottle.visible = not _drinking.get(seat, false)
	_bottles[seat] = bottle


func _on_seat_drinking(seat: int, drinking: bool) -> void:
	_drinking[seat] = drinking
	var bottle: Node3D = _bottles.get(seat)
	if bottle != null:
		bottle.visible = not drinking


func _remove(seat: int) -> void:
	var bottle: Node3D = _bottles.get(seat)
	if bottle != null:
		bottle.queue_free()
	_bottles.erase(seat)
