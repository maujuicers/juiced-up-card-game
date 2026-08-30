extends Node

class_name MauMauGameManager

# Public surface: what every seat may see; broadcasts these.
## Full public snapshot after every state change; the wire shape is [method MauMauTable.to_dict].
signal table_changed(table: MauMauTable)
signal card_played(seat: int, card: Card)
signal cards_drawn(seat: int, count: int)
signal turn_changed(seat: int)
## A Jack is on the pile and this seat owes a suit.
signal wish_requested(seat: int)
signal suit_wished(suit: Card.Suit)
signal effect_triggered(effect: String)
signal seat_placed(seat: int, placement: int)
## End of round: the final table, [member MauMauTable.finish_order] complete.
signal round_over(final: MauMauTable)
signal base_card_played(card: Card)
## An accusation was judged: `accused` (guilty) or `accuser` (false alarm) drew its penalty.
## `method` is a Cheat.Method.
signal accusation_resolved(accuser: int, accused: int, method: int, guilty: bool)
## A card changed hands behind the table. Which card it was stays between the two
## seats: only its private hand message says that.
signal card_slipped(giver: int, receiver: int)
## The waiter took this seat's order and set off; no bottle yet.
signal waiter_dispatched(seat: int)
## The waiter reached this seat and its bottle is on the table.
signal waiter_delivered(seat: int)

# Private surface: one seat's cards, for that seat only; send it with rpc_id.
signal private_hand_changed(seat: int, card_ids: PackedInt32Array)
## This seat's juice level and what is left in its bottle (-1 for none); the
## authority owns both, the seat's own peer mirrors them.
signal private_juice_changed(seat: int, current: int, bottle_content: int)
## A cheat this seat just paid for, so its own client can list what it can be caught at.
signal private_cheat_charged(seat: int, method: int, cost: int)
## A cheat this seat could not afford; its own client shakes the meter.
signal private_cheat_refused(seat: int, method: int, cost: int)

@export var npcs: Array[Npc]
@export var player: PlayerController
## Participant i sits at marker i; turn order is seat order.
@export var seat_markers: Array[SeatMarker]
@export var music: AudioStream
@export var move_card_sfx_list: Array[AudioStream]
## Falls back to [method CardDeck.load_default] when the scene leaves it unset.
@export var deck: CardDeck
## Carries both payload surfaces over the wire; inert offline.
@export var net_sync: MauMauNetSync
## Walks the ordered bottles over. Null in a scene without the bar, where an
## order is granted the moment it is made.
@export var waiter: Waiter
@export_range(0.0, 5.0, 0.05, "suffix:s") var npc_think_time: float = 1.0
@export_range(1, 5, 1, "suffix:c") var cards_drawn_on_cheat: int = 2

#Game state
@export_range(1, 8) var cards_per_player := 5
var draw_pile: Array[Card] = []
var discard_pile: Array[Card] = []
var turn_order: Array[MauMauPlayer] = []
var current_player_index: int
var current_player_node: MauMauPlayer
var wished_suit: Card.Suit = Card.Suit.NONE
var current_draw_penalty: int = 0
var current_effect: String = "none"
## After the regular draw a second draw request means "pass".
var has_drawn_this_turn: bool = false
## A Jack is on the pile and the seat on turn still owes its wish.
var awaiting_wish: bool = false
var is_game_over: bool = false
## Lets a delayed autoplay action notice its turn is already over.
var _turn_serial: int = 0
## The seat whose turn_started went out and whose turn_ended is still owed.
var _acting_seat: MauMauPlayer

var winners: Array[MauMauPlayer]
## Seat -> the last (juice, bottle) pair that went out, so a sip sends one message.
var _published_juice: Dictionary = {}


func _ready() -> void:
	if deck == null:
		deck = CardDeck.load_default()
	# A client's own waiter walks for show only; the bottle is the authority's to grant.
	if waiter != null and not Net.is_client():
		waiter.delivered.connect(_on_waiter_delivered)
	if Net.is_client():
		_client_ready()
		return
	if Net.is_server():
		# A dedicated server injects both before the table enters the tree; a host has neither.
		if room == null:
			room = Net.room_for_table(self)
		if seating.is_empty() and room != null:
			seating = room.seat_peers
		_start_when_peers_ready()
		return
	_start_round()


## Authority only (offline or server): deal, seat and open the first turn.
func _start_round() -> void:
	if _round_started:
		return
	_round_started = true
	start_game()
	log_gamestate()
	current_player_index = 0
	start_turn()
	# Nobody listens on a dedicated server, and it runs one table per room.
	if not Net.is_dedicated():
		AudioManager.play_music(music)


## A client seats the participants and then only mirrors what NetSync receives.
func _client_ready() -> void:
	init_player_positions()
	# The authority runs the drain for every seat and pushes the level; a client
	# that drained too would count down twice.
	var seat: MauMauPlayer = player.maumau_player if player != null else null
	if seat != null and seat.juice != null:
		seat.juice.drain_enabled = false
	AudioManager.play_music(music)

func start_game() -> void:
	reset_game()
	init_player_positions()
	build_draw_pile()
	draw_pile.shuffle()
	init_player_hands()

	#draw first card
	discard_pile.append(_draw_from_pile())
	call_deferred("emit_signal", "base_card_played", discard_pile.back()) # Call deferred because of init order

func start_turn() -> void:

	if is_game_over:
		return

	current_player_node = turn_order[current_player_index]

	if current_player_node.placement > -1:
		print("%s already won, next player's turn" % current_player_node)
		advance_turn()
		return

	_end_acting_turn()
	_acting_seat = current_player_node
	emit_signal("turn_changed", current_player_index)
	current_player_node.turn_started.emit()
	has_drawn_this_turn = false
	awaiting_wish = false
	_turn_serial += 1
	var serial := _turn_serial

	print("turn started for ", current_player_node)

	match current_effect:
		"draw_two":
			current_effect = "none"
			current_draw_penalty += 2
			# Without a seven to counter, the penalty is taken at once.
			if not MauMauRules.has_valid_move(
					current_player_node.hand, discard_pile.back(), wished_suit, current_draw_penalty):
				_draw_card(current_player_node)
		"skip_next":
			print("Player %d was skipped!" % current_player_index)
			current_effect = "none"
			advance_turn()
			return
		"wish_suit":
			current_effect = "none"

	_publish()
	# The penalty draw may already have ended this turn (and scheduled the next).
	if serial == _turn_serial and not is_game_over and current_player_node.autoplay:
		_schedule_autoplay()

func advance_turn() -> void:
	current_player_index = (current_player_index + 1) % turn_order.size()
	log_gamestate()
	start_turn()


#################SEAT INTENTS########################
# WARN The only ways a seat may act.

func submit_move(seat: MauMauPlayer, card_id: int) -> bool:
	if Net.is_client():
		if not _is_local_seat(seat) or not _is_on_turn(seat) or awaiting_wish:
			return false
		Net.to_server("submit_move", [card_id])
		return true
	if not _is_on_turn(seat) or awaiting_wish:
		return false
	var accepted := _play_card(card_id)
	if accepted:
		_publish()
	return accepted


func submit_draw(seat: MauMauPlayer) -> bool:
	if Net.is_client():
		if not _is_local_seat(seat) or not _is_on_turn(seat) or awaiting_wish:
			return false
		Net.to_server("submit_draw", [])
		return true
	if not _is_on_turn(seat) or awaiting_wish:
		return false
	var accepted := _draw_card(seat)
	if accepted:
		_publish()
	return accepted


## Accusing is the one intent a seat may raise off turn.
func submit_accuse(accuser: MauMauPlayer, accused: MauMauPlayer, method: Cheat.Method) -> bool:
	if not _may_accuse(accuser, accused, method):
		return false
	if Net.is_client():
		if not _is_local_seat(accuser):
			return false
		Net.to_server("submit_accuse", [accused.turn_position, method])
		return true

	accuser.on_accusation_made()
	var caught := accused.take_cheat(method)
	var guilty := caught != null
	if guilty:
		if method == Cheat.Method.ONE:
			_take_back_card(accused, caught.card)
		elif method == Cheat.Method.FIVE:
			_return_slipped_card(accused, caught.card)
		accused.on_caught_cheating()
		_deal_penalty(accused, cards_drawn_on_cheat)
	else:
		_deal_penalty(accuser, cards_drawn_on_cheat)
	print("Seat %d accused seat %d: %s" % [
		accuser.turn_position, accused.turn_position, "guilty" if guilty else "false alarm"])
	accusation_resolved.emit(accuser.turn_position, accused.turn_position, method, guilty)
	_publish()
	return true


func _may_accuse(accuser: MauMauPlayer, accused: MauMauPlayer, method: Cheat.Method) -> bool:
	if is_game_over or accuser == null or accused == null or accuser == accused:
		return false
	if not turn_order.has(accuser) or not turn_order.has(accused):
		return false
	return Cheat.Method.find_key(method) != null


## Slipping runs off turn too: a card pressed into another hand is a cheat, not a move.
func submit_slip(giver: MauMauPlayer, receiver: MauMauPlayer, card_id: int) -> bool:
	if not _may_slip(giver, receiver, card_id):
		return false
	if Net.is_client():
		if not _is_local_seat(giver):
			return false
		Net.to_server("submit_slip", [receiver.turn_position, card_id])
		return true

	var card := deck.card(card_id)
	var cost: int = Cheat.JUICE_COSTS.get(Cheat.Method.FIVE, 0)
	if not giver.trigger_cheat(Cheat.Method.FIVE, card):
		private_cheat_refused.emit(giver.turn_position, Cheat.Method.FIVE, cost)
		return false
	private_cheat_charged.emit(giver.turn_position, Cheat.Method.FIVE, cost)

	giver.remove_card(card_id)
	receiver.add_card(card)
	print("Seat %d slipped a card to seat %d" % [giver.turn_position, receiver.turn_position])
	card_slipped.emit(giver.turn_position, receiver.turn_position)
	_publish()
	return true


func _may_slip(giver: MauMauPlayer, receiver: MauMauPlayer, card_id: int) -> bool:
	if is_game_over or giver == null or receiver == null or giver == receiver:
		return false
	if not turn_order.has(giver) or not turn_order.has(receiver):
		return false
	# Handing over the last card would go out through the back door.
	if not giver.has_card(card_id) or giver.hand.size() <= 1:
		return false
	return receiver.placement == -1


## Drinking runs off turn: what a seat does with its bottle is nobody's turn.
func submit_drink(seat: MauMauPlayer, drinking: bool) -> bool:
	if not _may_refresh(seat):
		return false
	if Net.is_client():
		if not _is_local_seat(seat):
			return false
		Net.to_server("submit_drink", [drinking])
		return true
	return seat.begin_drinking() if drinking else seat.end_drinking()


func submit_waiter(seat: MauMauPlayer) -> bool:
	if not _may_refresh(seat):
		return false
	# Refused rather than queued: the seat asks again once the bottle is done.
	if seat.juice_bottle != null and not seat.juice_bottle.is_empty():
		return false
	if waiter != null and waiter.has_order(seat.turn_position):
		return false
	if Net.is_client():
		if not _is_local_seat(seat):
			return false
		Net.to_server("submit_waiter", [])
		return true
	if waiter == null:
		return seat.order_bottle()
	waiter.order(seat.turn_position, marker_for_seat(seat.turn_position))
	waiter_dispatched.emit(seat.turn_position)
	return true


## Authority only: the walk is over, so the bottle is on the table.
func _on_waiter_delivered(seat_index: int) -> void:
	if seat_index < 0 or seat_index >= turn_order.size():
		return
	turn_order[seat_index].order_bottle()
	waiter_delivered.emit(seat_index)


## The chair a seat sits at, null when the scene has no markers.
func marker_for_seat(index: int) -> SeatMarker:
	if index < 0 or index >= seat_markers.size():
		return null
	return seat_markers[index]


func _may_refresh(seat: MauMauPlayer) -> bool:
	return not is_game_over and seat != null and turn_order.has(seat)


func submit_wish(seat: MauMauPlayer, suit: Card.Suit) -> bool:
	if Net.is_client():
		if not _is_local_seat(seat) or not _is_on_turn(seat) or not awaiting_wish or suit == Card.Suit.NONE:
			return false
		Net.to_server("submit_wish", [suit])
		return true
	if not _is_on_turn(seat) or not awaiting_wish or suit == Card.Suit.NONE:
		return false
	_set_wished_suit(suit)
	_publish()
	return true


#################NETWORK GATE (server)########################
# The client half of submit_* forwards the bare intent here; the peer id the
# relay hands over is the whole identity check, so a peer can never act for a
# seat but its own.

const PEER_READY_TIMEOUT := 15.0

## Server side: the room this table serves (phase 4b). Null offline and on a client.
var room: NetRoom
## Server side: index = seat, value = peer id, 0 = NPC; the room's seating, injected
## before the deal. Replaces reading Net.seat_peers here.
var seating: PackedInt32Array = []


## Server: an intent relayed by Net for `peer` ("submit_move" [card_id],
## "submit_draw" [], "submit_wish" [suit], "submit_drink" [drinking],
## "submit_waiter" []). Replaces the @rpc _rpc_submit_* trio.
func submit_from_peer(peer: int, method: String, args: Array) -> void:
	if not Net.is_server():
		return
	var index := _seat_for_peer(peer)
	if index < 0 or index >= turn_order.size():
		push_warning("Ignoring %s from peer %d: it holds no seat at this table" % [method, peer])
		return
	var seat := turn_order[index]
	match method:
		"submit_move":
			if not _has_int_arg(method, peer, args):
				return
			submit_move(seat, args[0])
		"submit_draw":
			submit_draw(seat)
		"submit_drink":
			if args.size() != 1 or typeof(args[0]) != TYPE_BOOL:
				push_warning("Ignoring submit_drink from peer %d: bad arguments %s" % [peer, args])
				return
			submit_drink(seat, args[0])
		"submit_waiter":
			submit_waiter(seat)
		"submit_accuse":
			var accused := _accused_seat_arg(peer, args)
			if accused >= 0:
				submit_accuse(seat, turn_order[accused], args[1] as Cheat.Method)
		"submit_slip":
			var receiver := _slipped_seat_arg(peer, args)
			if receiver >= 0:
				submit_slip(seat, turn_order[receiver], args[1])
		"submit_wish":
			if not _has_int_arg(method, peer, args):
				return
			# A suit outside the enum would wish something no card can ever match.
			if Card.Suit.find_key(args[0]) == null:
				push_warning("Ignoring wish %s from peer %d: no such suit" % [args[0], peer])
				return
			submit_wish(seat, args[0] as Card.Suit)
		_:
			push_warning("Ignoring unknown intent '%s' from peer %d" % [method, peer])


## The seat an accusation names, -1 when the payload is not a seat and a method.
func _accused_seat_arg(peer: int, args: Array) -> int:
	if args.size() != 2 or typeof(args[0]) != TYPE_INT or typeof(args[1]) != TYPE_INT:
		push_warning("Ignoring submit_accuse from peer %d: bad arguments %s" % [peer, args])
		return -1
	if args[0] < 0 or args[0] >= turn_order.size() or Cheat.Method.find_key(args[1]) == null:
		push_warning("Ignoring submit_accuse from peer %d: no such seat or method %s" % [peer, args])
		return -1
	return args[0]


## The seat a slip names, -1 when the payload is not a seat and a card id.
func _slipped_seat_arg(peer: int, args: Array) -> int:
	if args.size() != 2 or typeof(args[0]) != TYPE_INT or typeof(args[1]) != TYPE_INT:
		push_warning("Ignoring submit_slip from peer %d: bad arguments %s" % [peer, args])
		return -1
	if args[0] < 0 or args[0] >= turn_order.size():
		push_warning("Ignoring submit_slip from peer %d: no such seat %s" % [peer, args[0]])
		return -1
	return args[0]


## The arguments come off the wire, so nothing about them is given.
func _has_int_arg(method: String, peer: int, args: Array) -> bool:
	if args.size() == 1 and typeof(args[0]) == TYPE_INT:
		return true
	push_warning("Ignoring %s from peer %d: bad arguments %s" % [method, peer, args])
	return false


## The seat a peer plays at this table, -1 for none. The room owns the seating;
## `seating` stands in while a table has been handed one without a room.
func _seat_for_peer(peer: int) -> int:
	if peer == 0:
		return -1
	if room != null:
		return room.seat_for_peer(peer)
	return seating.find(peer)


## Server side the room decides who sits where, client side its own Net does.
func _peer_for_seat(index: int) -> int:
	if Net.is_server():
		return seating[index] if index >= 0 and index < seating.size() else 0
	return Net.peer_for_seat(index)


## Peers whose NetSync handshake is still owed before the first deal.
var _pending_peers: PackedInt32Array = []
## Handshakes that arrived before this manager knew whom to wait for.
var _ready_peers: PackedInt32Array = []
var _round_started: bool = false


## Waits for every human peer's NetSync handshake, then deals.
func _start_when_peers_ready() -> void:
	# On a dedicated server Net.peer_left also fires for the peers of other rooms.
	if room != null:
		room.peer_left.connect(_on_peer_left)
	else:
		Net.peer_left.connect(_on_peer_left)
	for peer in seating:
		if peer != 0 and peer != Net.SERVER_PEER and not _ready_peers.has(peer):
			_pending_peers.append(peer)
	if _pending_peers.is_empty():
		_start_round()
		return
	# One stuck client must not hold the table for good.
	get_tree().create_timer(PEER_READY_TIMEOUT).timeout.connect(func() -> void:
		if not _round_started:
			push_warning("Dealing without peers %s: handshake timed out" % [_pending_peers])
			_start_round())


## Called by NetSync once a peer has main_scene loaded and is listening.
func peer_ready(peer: int) -> void:
	if not _ready_peers.has(peer):
		_ready_peers.append(peer)
	_stop_waiting_for(peer)


func _stop_waiting_for(peer: int) -> void:
	var index := _pending_peers.find(peer)
	if index == -1:
		return
	_pending_peers.remove_at(index)
	if _pending_peers.is_empty():
		_start_round()


## A dropped peer keeps neither the deal nor its seat waiting: the seat plays itself on.
func _on_peer_left(peer: int) -> void:
	_stop_waiting_for(peer)
	var index := seating.find(peer)
	if index < 0 or index >= turn_order.size():
		return
	var seat := turn_order[index]
	seat.autoplay = true
	if _is_on_turn(seat):
		_schedule_autoplay()


## A client may only ever submit for the seat it sits at.
func _is_local_seat(seat: MauMauPlayer) -> bool:
	return seat != null and player != null and seat == player.maumau_player


func _is_on_turn(seat: MauMauPlayer) -> bool:
	return not is_game_over and seat != null and seat == current_player_node

func _play_card(card_id: int) -> bool:
	# A server-side table has no sound at all; indexing the empty list aborts the move.
	if not move_card_sfx_list.is_empty():
		AudioManager.play_sfx(move_card_sfx_list.pick_random())
	var card := deck.card(card_id)
	if card == null:
		push_warning("Player %d tried to play unknown card id %d" % [current_player_index, card_id])
		return false
	# Checked before the cheat offer: a card the seat does not hold must not cost juice.
	if not current_player_node.has_card(card_id):
		push_warning("Player %d does not hold %s" % [current_player_index, card])
		return false

	var legal := MauMauRules.is_valid_move(card, discard_pile.back(), wished_suit, current_draw_penalty)
	print("player %d tried to play %s. The move is %s." % [current_player_index, card, legal])
	if not legal:
		var cost: int = Cheat.JUICE_COSTS.get(Cheat.Method.ONE, 0)
		if not current_player_node.trigger_cheat(Cheat.Method.ONE, card):
			private_cheat_refused.emit(current_player_index, Cheat.Method.ONE, cost)
			return false
		private_cheat_charged.emit(current_player_index, Cheat.Method.ONE, cost)

	current_player_node.remove_card(card_id)
	discard_pile.append(card)
	card_played.emit(current_player_index, card)

	#check if player won
	if current_player_node.get_hand_size() == 0:
		winners.append(current_player_node)
		current_player_node.placement = winners.size()
		seat_placed.emit(current_player_index, current_player_node.placement)
		print( "%d won the game and is placed in %d place" % [current_player_index, winners.size()])

		if winners.size() >= turn_order.size() - 1:
			game_over()
			return true

	# Wish cleared after play
	wished_suit = Card.Suit.NONE
	current_effect = MauMauRules.get_effect(card)
	effect_triggered.emit(current_effect)

	if current_effect == "wish_suit":
		print("player %d played %s, he can now choose a suit" % [current_player_index, card])
		awaiting_wish = true
		wish_requested.emit(current_player_index)
		current_player_node.wish_requested.emit()
		return true

	advance_turn()
	return true


func _draw_card(seat: MauMauPlayer) -> bool:
	# A pending penalty may always be taken instead of countering with a seven;
	# checked before the pass so an off-turn cheat penalty never passes for the seat on turn.
	var taking_penalty := current_draw_penalty > 0
	if not taking_penalty and has_drawn_this_turn:
		print("Player %d passes" % seat.turn_position)
		advance_turn()
		return true

	#if current_draw_penalty == 0 and MauMauRules.has_valid_move(
			#current_player_node.hand, discard_pile.back(), wished_suit, current_draw_penalty):
		#print("Player %d may not draw: a card in hand can be played" % current_player_index)
		#return false

	var draw_cards := current_draw_penalty if taking_penalty else 1
	current_draw_penalty = 0

	var drawn_card: Card
	var drawn := 0
	for i in range(draw_cards):
		drawn_card = _draw_from_pile()
		if drawn_card == null:
			break
		seat.add_card(drawn_card)
		drawn += 1
		print("Player %d drew %s" % [seat.turn_position, drawn_card])
	cards_drawn.emit(seat.turn_position, drawn)

	if taking_penalty:
		advance_turn()
		return true

	# House rule: a drawn card that fits may be played right away.
	has_drawn_this_turn = true
	if drawn_card != null and MauMauRules.is_valid_move(drawn_card, discard_pile.back(), wished_suit, current_draw_penalty):
		print("Player %d may play the drawn %s" % [seat.turn_position, drawn_card])
		return true
	advance_turn()
	return true


func _set_wished_suit(suit: Card.Suit) -> void:
	suit_wished.emit(suit)
	awaiting_wish = false
	wished_suit = suit
	print("%s was wished" % Card.suit_name(suit))
	advance_turn()

## A cheat penalty is dealt straight into the seat: it is not the pending draw
## penalty (a seven stack the seat on turn still owes), does not end anyone's turn
## and does not count as this turn's draw.
func _deal_penalty(seat: MauMauPlayer, count: int) -> void:
	seat.cheat_penalties += 1
	var drawn := 0
	for i in count:
		var card := _draw_from_pile()
		if card == null:
			break
		seat.add_card(card)
		drawn += 1
	print("Seat %d drew %d cards as a cheat penalty" % [seat.turn_position, drawn])
	if drawn > 0:
		cards_drawn.emit(seat.turn_position, drawn)


## An upheld Method.ONE: the illegally played card goes back to the cheater and
## whatever of its effect is not spent yet is undone. What the next seat already
## paid stands — a taken draw_two, a served skip_next — because that seat's turn
## is over by the time anyone can accuse.
func _take_back_card(cheater: MauMauPlayer, card: Card) -> void:
	if card == null:
		return
	var index := -1
	for i in range(discard_pile.size() - 1, -1, -1):
		if discard_pile[i] == card:
			index = i
			break
	# Gone means the pile was reshuffled around it; the penalty still stands.
	if index == -1:
		return
	discard_pile.remove_at(index)
	cheater.add_card(card)
	if not discard_pile.is_empty():
		# The signal LastPlayedCard already reads as "the pile shows this now".
		base_card_played.emit(discard_pile.back())

	if cheater.placement > -1:
		_unplace(cheater)
	if awaiting_wish and current_player_node == cheater:
		# The wish was owed for this very Jack, so nobody owes one now.
		awaiting_wish = false
		current_effect = "none"
		advance_turn()
	elif card.rank == Card.Rank.JACK and wished_suit != Card.Suit.NONE:
		wished_suit = Card.Suit.NONE


## An upheld Method.FIVE: the slipped card goes back to the seat that pressed it
## on. Whoever holds it now gives it up; once it has been played, nobody does.
func _return_slipped_card(cheater: MauMauPlayer, card: Card) -> void:
	if card == null:
		return
	for seat in turn_order:
		if seat != cheater and seat.has_card(card.id):
			seat.remove_card(card.id)
			cheater.add_card(card)
			return


## The seat did not go out after all; the seats behind it move up.
func _unplace(seat: MauMauPlayer) -> void:
	var index := winners.find(seat)
	if index != -1:
		winners.remove_at(index)
	seat.placement = -1
	seat_placed.emit(seat.turn_position, -1)
	for i in winners.size():
		if winners[i].placement != i + 1:
			winners[i].placement = i + 1
			seat_placed.emit(winners[i].turn_position, winners[i].placement)


## null only when both piles are exhausted.
func _draw_from_pile() -> Card:
	if draw_pile.is_empty():
		if discard_pile.size() <= 1:
			push_warning("No cards left to draw")
			return null
		var top_card: Card = discard_pile.pop_back()
		draw_pile = discard_pile.duplicate()
		discard_pile.clear()
		discard_pile.append(top_card)
		draw_pile.shuffle()
	return draw_pile.pop_back()


#################PUBLIC / PRIVATE PAYLOADS########################

func snapshot() -> MauMauTable:
	var table := MauMauTable.new()
	table.top_card = discard_pile.back().id if not discard_pile.is_empty() else -1
	table.turn = current_player_index
	table.wished_suit = wished_suit
	table.draw_penalty = current_draw_penalty
	table.awaiting_wish = awaiting_wish
	table.has_drawn = has_drawn_this_turn
	table.draw_pile_size = draw_pile.size()
	table.round_over = is_game_over
	for seat in turn_order:
		table.hand_counts.append(seat.get_hand_size())
		table.placements.append(seat.placement)
	for seat in winners:
		table.finish_order.append(seat.turn_position)
	if is_game_over:
		for seat in turn_order:
			if seat.placement == -1:
				table.finish_order.append(seat.turn_position)
	return table


func _publish() -> void:
	table_changed.emit(snapshot())


func _end_acting_turn() -> void:
	if _acting_seat != null:
		_acting_seat.turn_ended.emit()
		_acting_seat = null


#################AUTOPLAY########################

func _schedule_autoplay() -> void:
	var serial := _turn_serial
	get_tree().create_timer(npc_think_time).timeout.connect(func() -> void:
		if serial == _turn_serial and not is_game_over:
			_autoplay_step())


func _autoplay_step() -> void:
	var seat := current_player_node
	var serial := _turn_serial
	if awaiting_wish:
		seat.select_suit(MauMauAi.choose_suit(seat.hand))
		return
	var card := MauMauAi.choose_card(seat.hand, discard_pile.back(), wished_suit, current_draw_penalty)
	if card != null:
		seat.try_play_card_by_id(card.id)
	else:
		seat.draw_card()
	if serial == _turn_serial and not is_game_over:
		_schedule_autoplay()

func game_over() -> void:
	is_game_over = true
	_end_acting_turn()
	var final := snapshot()
	round_over.emit(final)
	print("Game over! Winner is %s, finish order %s" % [winners[0], final.finish_order])

#################GAME INITIALIZATION########################

func reset_game() -> void:
	draw_pile.clear()
	discard_pile.clear()
	turn_order.clear()
	current_player_index = 0
	# The deal hands out fresh bottles, so an order from the last round is void.
	if waiter != null:
		waiter.clear_orders()

func build_draw_pile() -> void:
	draw_pile = deck.all()

func init_player_hands() -> void:
	# One card has to be left over for the first discard.
	var per_player := mini(cards_per_player, (deck.size() - 1) / turn_order.size())
	if per_player < cards_per_player:
		push_warning("cards_per_player %d is more than %d cards can deal to %d seats; dealing %d" %
			[cards_per_player, deck.size(), turn_order.size(), per_player])
	for seat in turn_order:
		var player_hand: Array[Card] = []
		for i in range(per_player):
			var card := _draw_from_pile()
			if card == null:
				break
			player_hand.append(card)
		seat.init_hand(player_hand)
		seat.init_juice_bottle()

## Seats participants in order: marker i, turn position i. Online, the seating
## (decided by the server before the scene loaded) says which seat is a human;
## the local human's Player node takes Net.my_seat() and the Npc nodes fill the rest.
func init_player_positions() -> void:
	turn_order.clear()
	for participant in _participants():
		if participant == null or participant.maumau_player == null:
			push_error("Participant %s has no MauMauPlayer" % participant)
			continue
		var index := turn_order.size()
		if index < seat_markers.size() and seat_markers[index] != null:
			seat_markers[index].occupy(participant, participant == player)
		else:
			push_warning("No seat marker for %s; it stays where the scene put it" % participant)
		var seat: MauMauPlayer = participant.maumau_player
		seat.move_card_sfx_list = move_card_sfx_list
		if Net.is_online():
			# Only the authority lets NPC seats play themselves; a client never acts for anyone.
			seat.autoplay = Net.is_server() and _peer_for_seat(index) == 0
		turn_order.append(seat)
		seat.seat_at(self, index)
		seat.hand_changed.connect(func(_hand: Array[Card]) -> void:
			private_hand_changed.emit(index, seat.hand_ids()))
		if seat.juice != null:
			seat.juice.juice_changed.connect(func(_current: int) -> void:
				_publish_juice(index, seat))
		seat.bottle_changed.connect(func(_content: int) -> void:
			_publish_juice(index, seat))


## Juice and bottle travel together: one message carries this seat's whole meter.
## A sip changes both, so the two signals behind it would say the same thing twice.
func _publish_juice(index: int, seat: MauMauPlayer) -> void:
	var current: int = seat.juice.current_juice if seat.juice != null else 0
	var meter := Vector2i(current, seat.bottle_content())
	if _published_juice.get(index) == meter:
		return
	_published_juice[index] = meter
	private_juice_changed.emit(index, current, seat.bottle_content())


func _participants() -> Array:
	var participants: Array = []
	participants.append_array(npcs)
	if player != null:
		participants.insert(clampi(Net.my_seat(), 0, participants.size()), player)
	return participants

#################FUNCTIONS FOR DEBUGGING########################

# Keyboard input for the human seat only; the gate refuses it off turn.
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	if player == null or player.maumau_player == null:
		return
	var seat := player.maumau_player

	if event.keycode == KEY_SPACE:
		seat.draw_card()
		return

	match event.keycode:
		KEY_H:
			seat.select_suit(Card.Suit.HEARTS)
			return
		KEY_D:
			seat.select_suit(Card.Suit.DIAMONDS)
			return
		KEY_S:
			seat.select_suit(Card.Suit.SPADES)
			return
		KEY_C:
			seat.select_suit(Card.Suit.CLUBS)
			return

	var key_index: int = -1

	# Map Key 1-5 (or Numpad 1-5) to 0-based array index (0-4)
	match event.keycode:
		KEY_1, KEY_KP_1: key_index = 0
		KEY_2, KEY_KP_2: key_index = 1
		KEY_3, KEY_KP_3: key_index = 2
		KEY_4, KEY_KP_4: key_index = 3

	if key_index != -1 and key_index < turn_order.size():
		seat.try_accuse(turn_order[key_index], Cheat.Method.ONE)

func log_gamestate() -> void:
	print("\n--- PLAYER HANDS INITIALIZED ---")
	for i in range(turn_order.size()):
		print("Seat %d [%s]:" % [i, turn_order[i]])
		for card in turn_order[i].hand:
			print("  - %s" % card)
	# Print the starting card on the discard pile
	if not discard_pile.is_empty():
		print("\nLast Discard Card: %s" % discard_pile.back())
	print("--------------------------------\n")
