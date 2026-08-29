extends Node

class_name MauMauNetSync

## Puts the manager's two payload surfaces on the wire. On the server it
## listens to the manager's public signals and [signal MauMauGameManager.private_hand_changed]
## and forwards them; on a client it receives them, mirrors the table onto
## the manager and re-emits the same signals so every view stays unchanged.
## The RPC node path is the same on every peer (MainScene/MaumauEngine/NetSync).

## Every event [method _rpc_event] carries, with the number of arguments it needs.
const EVENT_ARITY := {
	"card_played": 2,
	"cards_drawn": 2,
	"turn_changed": 1,
	"wish_requested": 1,
	"suit_wished": 1,
	"effect_triggered": 1,
	"seat_placed": 2,
	"base_card_played": 1,
	"round_over": 1,
}

@export var manager: MauMauGameManager

## Server side: the room this table serves; null on a client.
var room: NetRoom


## Every table message arrives here from the Net relay (phase 4b). On the server
## `peer` is the sender; on a client it is Net.SERVER_PEER. Intents go on to
## [method MauMauGameManager.submit_from_peer]; the rest to the _apply_* helpers.
func receive(peer: int, method: String, args: Array) -> void:
	pass

## Client side: the seat whose turn_started was mirrored and whose turn_ended is still owed.
var _acting_seat: MauMauPlayer


func _ready() -> void:
	# A child is ready before its parent, so the server hooks the manager's signals
	# here, before a deal that may happen inside the manager's own _ready. The client
	# handshake waits for that _ready instead: applying state needs seated participants.
	if Net.is_server():
		_forward_manager_signals()
	elif Net.is_client():
		manager.ready.connect(func() -> void:
			_rpc_client_ready.rpc_id(Net.SERVER_PEER))


#################SERVER########################


func _forward_manager_signals() -> void:
	manager.table_changed.connect(func(table: MauMauTable) -> void:
		_rpc_table.rpc(table.to_dict()))
	manager.private_hand_changed.connect(_send_hand)
	manager.card_played.connect(func(seat: int, card: Card) -> void:
		_send_event("card_played", [seat, card.id]))
	manager.cards_drawn.connect(func(seat: int, count: int) -> void:
		_send_event("cards_drawn", [seat, count]))
	manager.turn_changed.connect(func(seat: int) -> void:
		_send_event("turn_changed", [seat]))
	manager.wish_requested.connect(func(seat: int) -> void:
		_send_event("wish_requested", [seat]))
	manager.suit_wished.connect(func(suit: Card.Suit) -> void:
		_send_event("suit_wished", [suit]))
	manager.effect_triggered.connect(func(effect: String) -> void:
		_send_event("effect_triggered", [effect]))
	manager.seat_placed.connect(func(seat: int, placement: int) -> void:
		_send_event("seat_placed", [seat, placement]))
	manager.base_card_played.connect(func(card: Card) -> void:
		_send_event("base_card_played", [card.id]))
	manager.round_over.connect(func(final: MauMauTable) -> void:
		_send_event("round_over", [final.to_dict()]))


func _send_event(event: String, args: Array) -> void:
	_rpc_event.rpc(event, args)


func _send_hand(seat: int, card_ids: PackedInt32Array) -> void:
	var peer := Net.peer_for_seat(seat)
	# 0 is an NPC seat; the server already holds its own seat's cards.
	if peer == 0 or peer == Net.SERVER_PEER:
		return
	_rpc_hand.rpc_id(peer, card_ids)


## Server: the full public table plus the private hand of the seat this peer plays.
func send_full_state(peer: int) -> void:
	if manager.turn_order.is_empty() or manager.discard_pile.is_empty():
		return
	_rpc_event.rpc_id(peer, "base_card_played", [manager.discard_pile.back().id])
	_rpc_table.rpc_id(peer, manager.snapshot().to_dict())
	var seat := Net.seat_for_peer(peer)
	if seat >= 0 and seat < manager.turn_order.size():
		_rpc_hand.rpc_id(peer, manager.turn_order[seat].hand_ids())


#################WIRE########################
# Any peer may call an @rpc method, so every receiver checks its own role first.


@rpc("any_peer", "call_remote", "reliable")
func _rpc_client_ready() -> void:
	if not Net.is_server():
		return
	var peer := multiplayer.get_remote_sender_id()
	send_full_state(peer)
	manager.peer_ready(peer)


@rpc("authority", "call_remote", "reliable")
func _rpc_table(data: Dictionary) -> void:
	if not Net.is_client():
		return
	_apply_table(MauMauTable.from_dict(data))


@rpc("authority", "call_remote", "reliable")
func _rpc_hand(card_ids: PackedInt32Array) -> void:
	if not Net.is_client():
		return
	_apply_hand(card_ids)


## Reliable RPCs keep their order, and the manager emits an event before its
## snapshot, so a client sees event-then-table exactly like a local view does.
@rpc("authority", "call_remote", "reliable")
func _rpc_event(event: String, args: Array) -> void:
	if not Net.is_client():
		return
	_apply_event(event, args)


#################CLIENT########################


func _apply_table(table: MauMauTable) -> void:
	manager.current_player_index = table.turn
	var on_turn := _seat(table.turn)
	if on_turn != null:
		manager.current_player_node = on_turn
	manager.wished_suit = table.wished_suit
	manager.current_draw_penalty = table.draw_penalty
	manager.awaiting_wish = table.awaiting_wish
	manager.has_drawn_this_turn = table.has_drawn
	manager.is_game_over = table.round_over

	var pile: Array[Card] = []
	var top := manager.deck.card(table.top_card)
	if top != null:
		pile.append(top)
	manager.discard_pile = pile

	var my_seat := Net.my_seat()
	var seats := mini(mini(table.hand_counts.size(), table.placements.size()), manager.turn_order.size())
	for i in seats:
		manager.turn_order[i].placement = table.placements[i]
		# Only this peer's own cards arrive; every other hand is just a count.
		if i != my_seat:
			manager.turn_order[i].set_hand_count(table.hand_counts[i])

	manager.table_changed.emit(table)


func _apply_hand(card_ids: PackedInt32Array) -> void:
	var seat := _seat(Net.my_seat())
	if seat == null:
		push_warning("NetSync received a hand but this peer plays no seat")
		return
	seat.set_hand_ids(card_ids)


func _apply_event(event: String, args: Array) -> void:
	if not EVENT_ARITY.has(event):
		push_warning("NetSync received unknown event '%s'" % event)
		return
	if args.size() < EVENT_ARITY[event]:
		push_warning("NetSync received '%s' with too few arguments: %s" % [event, args])
		return

	match event:
		"card_played":
			var card := manager.deck.card(args[1])
			if card == null:
				push_error("NetSync received unknown card id %s" % args[1])
				return
			manager.card_played.emit(args[0], card)
			_play_move_sfx()
		"cards_drawn":
			manager.cards_drawn.emit(args[0], args[1])
			_play_move_sfx()
		"turn_changed":
			_start_turn(args[0])
		"wish_requested":
			manager.wish_requested.emit(args[0])
			var seat := _seat(args[0])
			if seat != null:
				seat.wish_requested.emit()
		"suit_wished":
			manager.suit_wished.emit(args[0] as Card.Suit)
		"effect_triggered":
			manager.effect_triggered.emit(args[0])
		"seat_placed":
			manager.seat_placed.emit(args[0], args[1])
		"base_card_played":
			var card := manager.deck.card(args[0])
			if card == null:
				push_error("NetSync received unknown base card id %s" % args[0])
				return
			manager.base_card_played.emit(card)
		"round_over":
			_end_acting_turn()
			manager.round_over.emit(MauMauTable.from_dict(args[0]))


# Mirrors MauMauGameManager.start_turn: the seat on turn is set before the
# signals go out, because a view may read it back off the manager.
func _start_turn(seat_index: int) -> void:
	manager.current_player_index = seat_index
	var seat := _seat(seat_index)
	if seat != null:
		manager.current_player_node = seat
	_end_acting_turn()
	manager.turn_changed.emit(seat_index)
	if seat != null:
		_acting_seat = seat
		seat.turn_started.emit()


func _end_acting_turn() -> void:
	if _acting_seat != null:
		_acting_seat.turn_ended.emit()
		_acting_seat = null


# The server's own AudioManager.play_sfx never reaches a client.
func _play_move_sfx() -> void:
	if manager.move_card_sfx_list.is_empty():
		return
	AudioManager.play_sfx(manager.move_card_sfx_list.pick_random())


func _seat(seat_index: int) -> MauMauPlayer:
	if seat_index < 0 or seat_index >= manager.turn_order.size():
		return null
	return manager.turn_order[seat_index]
