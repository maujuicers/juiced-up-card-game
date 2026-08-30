extends Node
class_name Accuser

## Aim the crosshair at another seat's cat and press `accuse` to call it a
## cheater. The mouse is captured, so the screen centre is the pointer.

## -1 when nothing is aimed.
signal aimed_seat_changed(seat: int)

## Far enough for the seat across the table (2.28 m apart) and no further.
const PICK_RAY_LENGTH := 4.0
## Layer 21, the seat aim areas' own: a card in front of a cat cannot steal the
## aim, and the cat cannot steal a card's.
const AIM_LAYER := 1 << 20

@export var maumau_player: MauMauPlayer
@export var player_camera: Camera3D
@export var banner: AccusationBanner

var _manager: MauMauGameManager
var _aimed_seat := -1


func _physics_process(_delta: float) -> void:
	if _manager == null:
		# The seat learns its manager when it is seated, which is after _ready.
		_manager = maumau_player.manager as MauMauGameManager if maumau_player != null else null
		if _manager == null:
			return
		if banner != null:
			banner.bind(_manager, maumau_player)
	_set_aimed(_seat_at_crosshair())


func _unhandled_input(event: InputEvent) -> void:
	if _aimed_seat < 0 or maumau_player == null or _manager == null:
		return
	if not event.is_action_pressed("accuse"):
		return
	if _aimed_seat >= _manager.turn_order.size():
		return
	get_viewport().set_input_as_handled()
	maumau_player.try_accuse(_manager.turn_order[_aimed_seat])


func _set_aimed(seat: int) -> void:
	if seat == _aimed_seat:
		return
	_highlight(_aimed_seat, false)
	_aimed_seat = seat
	_highlight(_aimed_seat, true)
	aimed_seat_changed.emit(_aimed_seat)


func _highlight(seat: int, on: bool) -> void:
	if seat < 0 or seat >= _manager.seat_markers.size():
		return
	var marker: SeatMarker = _manager.seat_markers[seat]
	if marker != null:
		marker.set_highlighted(on)


func _seat_at_crosshair() -> int:
	if player_camera == null or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return -1

	var screen_centre := player_camera.get_viewport().get_visible_rect().size / 2.0
	var from := player_camera.project_ray_origin(screen_centre)
	var to := from + player_camera.project_ray_normal(screen_centre) * PICK_RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = AIM_LAYER

	var hit := player_camera.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return -1

	var node := hit.get("collider") as Node
	while node != null and not (node is SeatMarker):
		node = node.get_parent()
	if node == null:
		return -1

	var seat := _manager.seat_markers.find(node as SeatMarker)
	if seat == -1 or _manager.seat_markers[seat].occupant == _manager.player:
		return -1
	return seat
