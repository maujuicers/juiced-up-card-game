extends Control
class_name AccusationBanner

## The verdict on a cheat accusation, from the local seat's point of view.

@export var label: Label
@export var hold: Timer

var _manager: MauMauGameManager
var _seat: MauMauPlayer


func _ready() -> void:
	visible = false
	if hold != null:
		hold.timeout.connect(_on_hold_timeout)


func bind(manager: MauMauGameManager, seat: MauMauPlayer) -> void:
	if manager == null or manager == _manager:
		return
	_manager = manager
	_seat = seat
	_manager.accusation_resolved.connect(_on_accusation_resolved)


func _on_accusation_resolved(accuser: int, accused: int, _method: int, guilty: bool) -> void:
	var penalty: int = _manager.cards_drawn_on_cheat
	var mine := _seat.turn_position if _seat != null else -1
	var text := ""
	if accuser == mine:
		text = ("You caught %s cheating — they draw %d" % [_seat_name(accused), penalty]) if guilty \
			else ("False alarm — you draw %d" % penalty)
	elif accused == mine:
		text = ("%s caught you cheating — you draw %d" % [_seat_name(accuser), penalty]) if guilty \
			else ("%s accused you and was wrong — they draw %d" % [_seat_name(accuser), penalty])
	else:
		text = "%s accused %s: %s" % [_seat_name(accuser), _seat_name(accused), "caught" if guilty else "wrong"]

	if label != null:
		label.text = text
	visible = true
	if hold != null:
		hold.start()


func _on_hold_timeout() -> void:
	visible = false


func _seat_name(seat: int) -> String:
	return "Seat %d" % (seat + 1)
