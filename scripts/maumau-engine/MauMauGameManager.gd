extends Node

#Signals
signal card_played(player_index: int, card: Card)
signal turn_changed(new_player_index: int)
signal effect_triggered(effect: String)
signal game_over_signal(winner_index: int)

@export var npcs: Array[Npc]
@export var player: PlayerController
@export var music: AudioStream
## The canonical card set; every pile and hand shares its [Card] instances.
## Falls back to [method CardDeck.load_default] when the scene does not set it.
@export var deck: CardDeck
## Seconds an autoplaying seat waits before each of its actions, so its turns
## are readable at the table.
@export_range(0.0, 5.0, 0.05, "suffix:s") var npc_think_time: float = 1.0
var maumau_players: Array[MauMauPlayer]

#Game state
@export_range(1, 8) var cards_per_player := 5
var draw_pile: Array[Card] = []
var discard_pile: Array[Card] = []
var turn_order: Array = []
var current_player_index: int
var current_player_node: MauMauPlayer
var wished_suit: Card.Suit = Card.Suit.NONE
var current_draw_penalty: int = 0
var current_effect: String = "none"
## Set once the seat on turn has taken its regular draw; it may then play the
## drawn card or draw again to pass.
var has_drawn_this_turn: bool = false
var is_game_over: bool = false
## Bumped on every start_turn(); lets a delayed autoplay action notice that the
## turn it was scheduled for is already over.
var _turn_serial: int = 0

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
	#set up Game 
	reset_game()
	init_player_positions()
	build_draw_pile()
	draw_pile.shuffle()
	init_player_hands()
	
	#draw first card
	var first_card: Card = draw_pile.pop_back()
	discard_pile.append(first_card)
	
func start_turn() -> void:
	
	if is_game_over:
		return
	
	var active_player = turn_order[current_player_index]
	current_player_node = active_player.maumau_player
	
	if current_player_node.placement > -1:
		print("player %s already won next players turn" % current_player_node.name)
		advance_turn()
		return
		
	emit_signal("turn_changed", current_player_index)
	has_drawn_this_turn = false
	_turn_serial += 1
	var serial := _turn_serial
	
	print("turn started for ", active_player.name)
	
	current_player_node.on_turn_started()
	current_player_node.card_selected.connect(play_card)
	current_player_node.card_drawn.connect(draw_card)
	
	match current_effect:
		"draw_two": 
			current_effect = "none"
			current_draw_penalty += 2
			current_player_node.draw_penalty_card(current_draw_penalty)
		"skip_next": 
			print("Player %d was skipped!" % current_player_index)
			current_effect = "none"
			# A skipped seat must be closed like any other ended turn, or it
			# keeps its connections and turn_active and can act out of turn.
			_end_turn()
			return 
		"wish_suit": 
			current_effect = "none"
	
	# The penalty draw above may already have ended this turn (and started the
	# next one, which schedules its own autoplay).
	if serial == _turn_serial and not is_game_over and current_player_node.autoplay:
		_schedule_autoplay()
	
func advance_turn() -> void:
	current_player_index = (current_player_index + 1) % turn_order.size()
	log_gamestate()
	start_turn()

func play_card(card_id: int) -> void:
	var card := deck.card(card_id)
	if card == null:
		push_error("Player %d tried to play unknown card id %d" % [current_player_index, card_id])
		return

	#Debug Line
	print("player %d tried to play %s — The move is %s." % 
	[current_player_index, 
	card,
	MauMauRules.is_valid_move(card, discard_pile.back(), wished_suit, current_draw_penalty)
	])
 	#########

	if MauMauRules.is_valid_move(card, discard_pile.back(), wished_suit, current_draw_penalty):
		# The seat removes the card by id; a seat that does not hold it simply keeps its turn.
		if current_player_node.play_card(current_player_index, card_id) == null:
			push_warning("Player %d does not hold %s" % [current_player_index, card])
			return

		current_player_node.card_selected.disconnect(play_card)
		current_player_node.card_drawn.disconnect(draw_card)
		
		discard_pile.append(card)
		
		#check if player won
		if current_player_node.get_hand_size() == 0:
			winners.append(current_player_node)
			current_player_node.placement = winners.size()
			print( "%d won the game and is placed in %d place" % [current_player_index, winners.size()])
			
			if winners.size() >= turn_order.size() - 1:
				game_over()
				return
		
		# Any played card satisfies (or replaces) a wish; a Jack sets a new one below.
		wished_suit = Card.Suit.NONE
		current_effect = MauMauRules.get_effect(card)
		effect_triggered.emit(current_effect)
		if current_effect == "wish_suit":
			print("player %d played %s — He can now choose a suit" % [current_player_index, card])
			current_player_node.suit_wished.connect(set_wished_suit)
			return
		
		advance_turn()

func draw_card(draw_amount: int) -> void:
	# Second draw request in one turn: the seat keeps the card it drew and passes.
	if has_drawn_this_turn:
		print("Player %d passes" % current_player_index)
		_end_turn()
		return

	# Drawing is only allowed when nothing in hand can be played. A pending
	# draw penalty is the exception: the player may always take it instead of
	# countering with a seven.
	if current_draw_penalty == 0 and MauMauRules.has_valid_move(
			current_player_node.hand, discard_pile.back(), wished_suit, current_draw_penalty):
		print("Player %d may not draw: a card in hand can be played" % current_player_index)
		return

	var taking_penalty := current_draw_penalty > 0
	var draw_cards := current_draw_penalty if taking_penalty else 1
	# Taking the penalty completes it; the next seat starts clean.
	current_draw_penalty = 0

	var drawn_card: Card
	for i in range(draw_cards):
		drawn_card = _draw_from_pile()
		if drawn_card == null:
			break
		current_player_node.add_card(drawn_card)
		print("Player %d drew %s" % [current_player_node.turn_position, drawn_card])

	if taking_penalty:
		_end_turn()
		return

	# A regular draw: if the drawn card fits, the seat may play it now (or draw
	# again to pass); otherwise the turn is over.
	has_drawn_this_turn = true
	if drawn_card != null and MauMauRules.is_valid_move(drawn_card, discard_pile.back(), wished_suit, current_draw_penalty):
		print("Player %d may play the drawn %s" % [current_player_index, drawn_card])
		return
	_end_turn()


## Top card of the draw pile, refilling it from the discard pile when empty.
## Returns null only when both piles are exhausted.
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


func _end_turn() -> void:
	current_player_node.on_turn_ended()
	current_player_node.card_selected.disconnect(play_card)
	current_player_node.card_drawn.disconnect(draw_card)
	advance_turn()


#################AUTOPLAY########################

## Runs one autoplay action for the seat on turn after [member npc_think_time],
## unless that turn has ended in the meantime.
func _schedule_autoplay() -> void:
	var serial := _turn_serial
	get_tree().create_timer(npc_think_time).timeout.connect(func() -> void:
		if serial == _turn_serial and not is_game_over:
			_autoplay_step())


## One decision for the seat on turn: answer a pending wish, play the best
## legal card, or draw. Schedules a follow-up whenever the turn continues
## (a Jack waiting for its wish, or a drawn card that may be played).
func _autoplay_step() -> void:
	var seat := current_player_node
	var serial := _turn_serial
	if seat.suit_wished.is_connected(set_wished_suit):
		seat.select_suit(MauMauAi.choose_suit(seat.hand))
		return
	var card := MauMauAi.choose_card(seat.hand, discard_pile.back(), wished_suit, current_draw_penalty)
	if card != null:
		seat.try_play_card_by_id(card.id)
	else:
		seat.draw_card()
	if serial == _turn_serial and not is_game_over:
		_schedule_autoplay()

func set_wished_suit(suit: Card.Suit) -> void:
	current_player_node.suit_wished.disconnect(set_wished_suit)
	print(wished_suit)
	wished_suit = suit
	print(wished_suit)
	advance_turn()
	
func game_over() -> void:
	is_game_over = true
	game_over_signal.emit(winners[0].turn_position)
	print("Game over! Winner is player: ", winners[0].name)
	
#################GAME INITIALIZATION########################

func reset_game() -> void:
	draw_pile.clear()
	discard_pile.clear()
	turn_order.clear()
	current_player_index = 0
	
func build_draw_pile() -> void:
	draw_pile = deck.all()
			
func init_player_hands() -> void:
	for p in range(turn_order.size()):
		var player_hand: Array[Card] = []
		for i in range(cards_per_player):
			player_hand.append(draw_pile.pop_back())
			
		var participant = turn_order[p]
		
		if "maumau_player" in participant and participant.maumau_player != null:
			participant.maumau_player.init_hand(player_hand)
		else:
			push_error("Participant at seat%d (%s) missing valid player_script" % [p, participant.name])
		
		
		
func init_player_positions() -> void:
	turn_order.clear()
	turn_order.append(player)
	turn_order.append_array(npcs)
	turn_order.shuffle()
	
	for i in range(turn_order.size()):
		var p = turn_order[i]
		p.maumau_player.init_pos(i)
		
#################FUNCTIONS FOR DEBUGGING########################

func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
		
	if event.keycode == KEY_SPACE:
		draw_card(1)
		return
		
	match event.keycode:
		KEY_H:
			current_player_node.select_suit(Card.Suit.HEARTS)
			return
		KEY_D:
			current_player_node.select_suit(Card.Suit.DIAMONDS)
			return
		KEY_S:
			current_player_node.select_suit(Card.Suit.SPADES)
			return
		KEY_C:
			current_player_node.select_suit(Card.Suit.CLUBS)
			return
		
	var key_index: int = -1
	
	# Map Key 1-5 (or Numpad 1-5) to 0-based array index (0-4)
	match event.keycode:
		KEY_1, KEY_KP_1: key_index = 0
		KEY_2, KEY_KP_2: key_index = 1
		KEY_3, KEY_KP_3: key_index = 2
		KEY_4, KEY_KP_4: key_index = 3
		KEY_5, KEY_KP_5: key_index = 4
		KEY_6, KEY_KP_6: key_index = 5
		KEY_7, KEY_KP_7: key_index = 6
		KEY_8, KEY_KP_8: key_index = 7
		KEY_9, KEY_KP_9: key_index = 8
		
	if key_index != -1:
		current_player_node.try_play_card(key_index)

func log_gamestate() -> void:
	print("\n--- PLAYER HANDS INITIALIZED ---")
	for i in range(turn_order.size()):
		var participant = turn_order[i]
		print("Seat %d [%s]:" % [i, participant.name])
		
		# Safely check if 'player_script' exists on this participant
		if "maumau_player" in participant and participant.maumau_player != null:
			for card in participant.maumau_player.hand:
				print("  - %s" % card)
		else:
			print("  ERROR: maumau_player is missing or null on %s!" % participant.name)
	# Print the starting card on the discard pile
	if not discard_pile.is_empty():
		print("\nLast Discard Card: %s" % discard_pile.back())
	print("--------------------------------\n")
	
	
	
	
	
