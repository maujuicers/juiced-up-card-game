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

# Private surface: one seat's cards, for that seat only; send it with rpc_id.
signal private_hand_changed(seat: int, card_ids: PackedInt32Array)

@export var npcs: Array[Npc]
@export var player: PlayerController
## Participant i sits at marker i; turn order is seat order.
@export var seat_markers: Array[SeatMarker]
@export var music: AudioStream
@export var move_card_sfx_list: Array[AudioStream]
## Falls back to [method CardDeck.load_default] when the scene leaves it unset.
@export var deck: CardDeck
@export_range(0.0, 5.0, 0.05, "suffix:s") var npc_think_time: float = 5.0
@export_range(1, 5, 1, "suffix:c") var cards_drawn_on_cheat: int = 2

#Game state
@export_range(1, 8) var cards_per_player := 5
var draw_pile: Array[Card] = []
var discard_pile: Array[Card] = []
var turn_order: Array[MauMauPlayer] = []
var current_player_index: int
var current_player_node: MauMauPlayer
var wished_suit: Card.Suit = Card.Suit.NONE
var cheat_penalty: bool = false
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


func _ready() -> void:
	if deck == null:
		deck = CardDeck.load_default()
	start_game()
	log_gamestate()
	current_player_index = 0
	start_turn()
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
	if not _is_on_turn(seat) or awaiting_wish:
		return false
	var accepted := _play_card(card_id)
	if accepted:
		_publish()
	return accepted


func submit_draw(seat: MauMauPlayer) -> bool:
	# An accused (or falsely accusing) seat takes its cheat penalty off turn.
	if not ((_is_on_turn(seat) and not awaiting_wish) or _is_in_cheat_accusation(seat)):
		return false
	var accepted := _draw_card(seat)
	if accepted:
		_publish()
	return accepted


func submit_wish(seat: MauMauPlayer, suit: Card.Suit) -> bool:
	if not _is_on_turn(seat) or not awaiting_wish or suit == Card.Suit.NONE:
		return false
	_set_wished_suit(suit)
	_publish()
	return true


func _is_on_turn(seat: MauMauPlayer) -> bool:
	return not is_game_over and seat != null and seat == current_player_node

func _is_in_cheat_accusation(seat: MauMauPlayer) -> bool:
	return seat != null and seat.cheat_accusation

func _play_card(card_id: int) -> bool:
	AudioManager.play_sfx(move_card_sfx_list[randi_range(0, 2)])
	var card := deck.card(card_id)
	if card == null:
		push_error("Player %d tried to play unknown card id %d" % [current_player_index, card_id])
		return false

	var legal := MauMauRules.is_valid_move(card, discard_pile.back(), wished_suit, current_draw_penalty)
	print("player %d tried to play %s. The move is %s." % [current_player_index, card, legal])
	if not legal and not current_player_node.trigger_cheat(Cheat.Method.ONE, card):
		return false

	if current_player_node.remove_card(card_id) == null:
		push_warning("Player %d does not hold %s" % [current_player_index, card])
		return false

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
		if not cheat_penalty:
			advance_turn()
		cheat_penalty = false
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

func _set_penalty() -> void:
	current_draw_penalty = cards_drawn_on_cheat
	cheat_penalty = true

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

## Seats participants in order: marker i, turn position i. Phase 4 decides which
## peer is participant i (the seating shuffle) before this runs.
func init_player_positions() -> void:
	turn_order.clear()
	var participants: Array = [player]
	participants.append_array(npcs)
	for participant in participants:
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
		turn_order.append(seat)
		seat.seat_at(self, index)
		seat.hand_changed.connect(func(_hand: Array[Card]) -> void:
			private_hand_changed.emit(index, seat.hand_ids()))

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

	if key_index != -1:
		npcs[1].maumau_player.call_cheater(turn_order[key_index], Cheat.Method.ONE)

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
