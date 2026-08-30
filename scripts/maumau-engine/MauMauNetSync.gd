extends Node

class_name MauMauNetSync

## Puts the manager's two payload surfaces on the wire. On the server it
## listens to the manager's public signals and [signal MauMauGameManager.private_hand_changed]
## and sends them through the [code]Net[/code] relay; on a client it receives them,
## mirrors the table onto the manager and re-emits the same signals so every view
## stays unchanged. Nothing here is an [code]@rpc[/code]: two rooms on one server
## would share a node path, so [method Net.to_room] / [method Net.to_peer] /
## [method Net.to_server] address messages by room and peer instead. The one
## message that is not the manager's, "look", is passed to [HeadSync].

## Every event the "event" message carries, with the number of arguments it needs.
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
	"accusation_resolved": 4,
	"cheat_charged": 3,
	"cheat_refused": 3,
}

@export var manager: MauMauGameManager
## The other half of this table's wire ([HeadSync]). "look" is not table state,
## so it is handed straight over rather than mirrored onto the manager. Typed
## [Node] because HeadSync reaches the manager, which reaches this: naming the
## class here would close a parse cycle.
@export var head_sync: Node

## Server side: the room this table serves; null on a client. Read through the
## manager because a host fills it in its own _ready, after this child's.
var room: NetRoom:
	get: return manager.room if manager != null else null

## Client side: the seat whose turn_started was mirrored and whose turn_ended is still owed.
var _acting_seat: MauMauPlayer


func _ready() -> void:
	# A child is ready before its parent, so the server hooks the manager's signals
	# here, before a deal that may happen inside the manager's own _ready. The client
	# handshake waits for that _ready instead: applying state needs seated participants.
	if Net.is_server():
		_forward_manager_signals()
	elif Net.is_client():
		Net.attach_sync(self)
		manager.ready.connect(func() -> void:
			Net.to_server("client_ready", []))


#################WIRE########################
# Every table message arrives here from the relay. A peer may send anything, so
# each message is checked against this peer's role and its payload before use.


## On the server `peer` is the sender; on a client it is Net.SERVER_PEER.
func receive(peer: int, method: String, args: Array) -> void:
	if method == "look":
		# HeadSync checks this peer's role itself, so both directions land there.
		if head_sync != null:
			head_sync.receive(peer, args)
		return
	if Net.is_server():
		_receive_as_server(peer, method, args)
	elif Net.is_client():
		_receive_as_client(method, args)


func _receive_as_server(peer: int, method: String, args: Array) -> void:
	match method:
		"client_ready":
			send_full_state(peer)
			manager.peer_ready(peer)
		"submit_move", "submit_draw", "submit_wish", "submit_accuse", \
		"submit_drink", "submit_waiter":
			manager.submit_from_peer(peer, method, args)
		_:
			push_warning("NetSync (server) ignoring '%s' from peer %d" % [method, peer])


func _receive_as_client(method: String, args: Array) -> void:
	match method:
		"table":
			if args.size() < 1 or not (args[0] is Dictionary):
				_drop_malformed(method, args)
				return
			_apply_table(MauMauTable.from_dict(args[0]))
		"hand":
			var ids: Variant = _as_ids(args[0]) if args.size() >= 1 else null
			if ids == null:
				_drop_malformed(method, args)
				return
			_apply_hand(ids)
		"juice":
			if args.size() < 2 or typeof(args[0]) != TYPE_INT or typeof(args[1]) != TYPE_INT:
				_drop_malformed(method, args)
				return
			_apply_juice(args[0], args[1])
		"event":
			if args.size() < 2 or not (args[0] is String) or not (args[1] is Array):
				_drop_malformed(method, args)
				return
			_apply_event(args[0], args[1])
		_:
			push_warning("NetSync (client) ignoring '%s'" % method)


## The card ids of a "hand" message, null when the payload is not a list of ints.
func _as_ids(value: Variant) -> Variant:
	if value is PackedInt32Array:
		return value
	if not (value is Array):
		return null
	for item in value:
		if typeof(item) != TYPE_INT:
			return null
	return PackedInt32Array(value)


func _drop_malformed(method: String, args: Array) -> void:
	push_warning("NetSync received a malformed '%s': %s" % [method, args])


#################SERVER########################


func _forward_manager_signals() -> void:
	manager.table_changed.connect(func(table: MauMauTable) -> void:
		_broadcast("table", [table.to_dict()]))
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
	manager.accusation_resolved.connect(func(accuser: int, accused: int, method: int, guilty: bool) -> void:
		_send_event("accusation_resolved", [accuser, accused, method, guilty]))
	manager.private_juice_changed.connect(func(seat: int, current: int, bottle: int) -> void:
		_send_private(seat, "juice", [current, bottle]))
	manager.private_cheat_charged.connect(func(seat: int, method: int, cost: int) -> void:
		_send_private(seat, "event", ["cheat_charged", [seat, method, cost]]))
	manager.private_cheat_refused.connect(func(seat: int, method: int, cost: int) -> void:
		_send_private(seat, "event", ["cheat_refused", [seat, method, cost]]))


func _send_event(event: String, args: Array) -> void:
	_broadcast("event", [event, args])


func _broadcast(method: String, args: Array) -> void:
	var target := room
	if target == null:
		# A headless server must not die over a table nobody is in.
		push_warning("NetSync cannot send '%s': this table has no room" % method)
		return
	Net.to_room(target, method, args)


func _send_hand(seat: int, card_ids: PackedInt32Array) -> void:
	_send_private(seat, "hand", [card_ids])


## To the one peer that plays this seat. 0 is an NPC seat, and the server already
## holds everything about its own.
func _send_private(seat: int, method: String, args: Array) -> void:
	var target := room
	if target == null:
		push_warning("NetSync cannot send '%s': this table has no room" % method)
		return
	var peer := target.peer_for_seat(seat)
	if peer == 0 or peer == Net.SERVER_PEER:
		return
	Net.to_peer(peer, method, args)


## Server: the full public table plus the private hand of the seat this peer plays.
func send_full_state(peer: int) -> void:
	if manager.turn_order.is_empty() or manager.discard_pile.is_empty():
		return
	Net.to_peer(peer, "event", ["base_card_played", [manager.discard_pile.back().id]])
	Net.to_peer(peer, "table", [manager.snapshot().to_dict()])
	var target := room
	if target == null:
		push_warning("NetSync cannot send a hand: this table has no room")
		return
	var seat := target.seat_for_peer(peer)
	if seat >= 0 and seat < manager.turn_order.size():
		var seated: MauMauPlayer = manager.turn_order[seat]
		Net.to_peer(peer, "hand", [seated.hand_ids()])
		var juice: Juice = seated.juice
		if juice != null:
			Net.to_peer(peer, "juice", [juice.current_juice, seated.bottle_content()])


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

	var my_seat: int = Net.my_seat()
	var seats := mini(mini(table.hand_counts.size(), table.placements.size()), manager.turn_order.size())
	for i in seats:
		manager.turn_order[i].placement = table.placements[i]
		# Only this peer's own cards arrive; every other hand is just a count.
		if i != my_seat:
			manager.turn_order[i].set_hand_count(table.hand_counts[i])

	manager.table_changed.emit(table)


## The server owns every seat's meter, so both halves are applied, never checked.
## The bottle is mirrored for show only: a client never runs the sip loop.
func _apply_juice(current: int, bottle_content: int) -> void:
	var seat := _seat(Net.my_seat())
	if seat == null:
		return
	if seat.juice != null:
		seat.juice.set_juice(current)
	seat.set_bottle_content(bottle_content)


## The Juice of the seat this peer plays, null when it plays none.
func _own_juice() -> Juice:
	var seat := _seat(Net.my_seat())
	return seat.juice if seat != null else null


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
		"accusation_resolved":
			_apply_accusation(args[0], args[1], args[2], args[3])
		"cheat_charged":
			# Only the cheating seat's own peer is told, so it can show what it
			# can still be caught at; the juice itself arrives as "juice".
			var seat := _seat(args[0])
			if seat != null:
				seat.cheats.append(Cheat.init_cheat(args[1] as Cheat.Method))
			manager.private_cheat_charged.emit(args[0], args[1], args[2])
		"cheat_refused":
			var juice := _own_juice()
			if juice != null:
				juice.juice_insufficient.emit(args[2])
			manager.private_cheat_refused.emit(args[0], args[1], args[2])


func _apply_accusation(accuser: int, accused: int, method: int, guilty: bool) -> void:
	var pointing := _seat(accuser)
	if pointing != null:
		pointing.on_accusation_made()
	if guilty:
		var caught := _seat(accused)
		if caught != null:
			caught.take_cheat(method as Cheat.Method)
			caught.on_caught_cheating()
	manager.accusation_resolved.emit(accuser, accused, method, guilty)


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
