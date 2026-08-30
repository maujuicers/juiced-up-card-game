extends Control
class_name KeyHints

## The controls cheat sheet on the right edge. A row is dimmed while its action
## would be refused, so the panel doubles as "may I act right now?".

const DIM_ALPHA := 0.4
const FADE_TIME := 0.12

@export var maumau_player: MauMauPlayer
@export var accuser: Accuser
@export var hand: Hand

@export_group("Rows")
@export var play_row: Control
@export var draw_row: Control
@export var accuse_row: Control
@export var pick_row: Control
@export var slip_row: Control

var _fades: Dictionary = {}
## A slip needs both: a card lifted out of the hand and a cat to press it on.
var _picked: bool = false
var _aiming_seat: bool = false


func _ready() -> void:
	_set_row_active(play_row, false)
	_set_row_active(draw_row, false)
	_set_row_active(accuse_row, false)
	_set_row_active(pick_row, false)
	_set_row_active(slip_row, false)

	if maumau_player != null:
		maumau_player.turn_started.connect(_on_turn_started)
		maumau_player.turn_ended.connect(_on_turn_ended)
	if accuser != null:
		accuser.aimed_seat_changed.connect(_on_aimed_seat_changed)
	if hand != null:
		hand.picked_card_changed.connect(_on_picked_card_changed)


func _on_turn_started() -> void:
	_set_row_active(play_row, true)
	_set_row_active(draw_row, true)


func _on_turn_ended() -> void:
	_set_row_active(play_row, false)
	_set_row_active(draw_row, false)


func _on_aimed_seat_changed(seat: int) -> void:
	_aiming_seat = seat >= 0
	_set_row_active(accuse_row, _aiming_seat)
	_set_row_active(slip_row, _picked and _aiming_seat)


func _on_picked_card_changed(card: Card) -> void:
	_picked = card != null
	_set_row_active(pick_row, _picked)
	_set_row_active(slip_row, _picked and _aiming_seat)


func _set_row_active(row: Control, active: bool) -> void:
	if row == null:
		return
	var target := 1.0 if active else DIM_ALPHA
	var running: Tween = _fades.get(row)
	if running != null and running.is_valid():
		running.kill()
	if not is_inside_tree():
		row.modulate.a = target
		return
	var fade := create_tween()
	fade.tween_property(row, "modulate:a", target, FADE_TIME)
	_fades[row] = fade
