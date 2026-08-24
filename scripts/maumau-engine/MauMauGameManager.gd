extends Node

#Signals
signal card_played(player_index: int, card: Card)
signal turn_changed(new_player_index: int)
signal effect_triggered(effect: String)
signal game_over(winner_index: int)

@export var npcs: Array[Npc]
@export var player: PlayerController
var maumau_players: Array[MauMauPlayer]

#Game state
var cards_per_player :=5
var draw_pile: Array[Card] = []
var discard_pile: Array[Card] = []
var turn_order: Array = []
var hands: Array = []
var current_player: int
var current_player_node: MauMauPlayer
var wished_suit: Card.Suit

func _ready() -> void:
	start_game()
	print("\n--- PLAYER HANDS INITIALIZED ---")
	for i in range(turn_order.size()):
		var participant = turn_order[i]
		print("Seat %d [%s]:" % [i, participant.name])
		
		# Safely check if 'player_script' exists on this participant
		if "maumau_player" in participant and participant.maumau_player != null:
			for card in participant.maumau_player.hand:
				var rank_str = Card.Rank.keys()[card.rank]
				var suit_str = Card.Suit.keys()[card.suit]
				print("  - %s of %s" % [rank_str, suit_str])
		else:
			print("  ERROR: maumau_player is missing or null on %s!" % participant.name)
	# Print the starting card on the discard pile
	if not discard_pile.is_empty():
		var top_card: Card = discard_pile.back()
		var top_rank = Card.Rank.keys()[top_card.rank]
		var top_suit = Card.Suit.keys()[top_card.suit]
		print("\nStarting Discard Card: %s of %s" % [top_rank, top_suit])
	print("--------------------------------\n")
	
	current_player = 0
	start_turn()
	
#function for DEBUGGING
func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
		
	var key_index: int = -1
	
	# Map Key 1-5 (or Numpad 1-5) to 0-based array index (0-4)
	match event.keycode:
		KEY_1, KEY_KP_1: key_index = 0
		KEY_2, KEY_KP_2: key_index = 1
		KEY_3, KEY_KP_3: key_index = 2
		KEY_4, KEY_KP_4: key_index = 3
		KEY_5, KEY_KP_5: key_index = 4
		
	if key_index != -1:
		current_player_node.try_play_card(key_index)

func start_game() -> void:
	reset_game()
	init_player_positions()
	build_draw_pile()
	draw_pile.shuffle()
	init_player_hands()
	
	#draw first card
	var first_card: Card = draw_pile.pop_back()
	discard_pile.append(first_card)
	
func start_turn() -> void:
	var active_player = turn_order[current_player]
	current_player_node = active_player.maumau_player
	emit_signal("turn_changed", current_player)
	
	print("turn started for ", active_player.name)
	
	current_player_node.on_turn_started()
	current_player_node.card_selected.connect(check_turn)

func check_turn(card: Card) -> void:
	print("player %d tried to play %s of %s — The move is %s." % 
	[current_player, 
	Card.Rank.keys()[card.rank], 
	Card.Suit.keys()[card.suit],
	MauMauRules.is_valid_move(card, discard_pile.back())
	])
	
	#current_player_node.card_selected.disconnect(check_turn)
	

func advance_turn() -> void:
	current_player = (current_player + 1) % turn_order.size()
	start_turn()
	#TODO: implement skip effect

func play_card(player_index: int, card: Card) -> void:
	pass # TODO: check MauMauRules.is_valid_move, move the card, trigger effects

func draw_card(player_index: int) -> void:
	pass # TODO: move the top of draw_pile into that player's hand

func reset_game() -> void:
	draw_pile.clear()
	discard_pile.clear()
	hands.clear()
	turn_order.clear()
	current_player = 0
	
func build_draw_pile() -> void:
	for suit in Card.Suit.values():
		for rank in Card.Rank.values():
			var new_card := Card.new()
			new_card.suit = suit
			new_card.rank = rank
			draw_pile.append(new_card)
			
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
		
		hands.append(player_hand)
		
		
		
func init_player_positions() -> void:
	turn_order.clear()
	turn_order.append(player)
	turn_order.append_array(npcs)
	turn_order.shuffle()
	
	for i in range(turn_order.size()):
		var p = turn_order[i]
		p.maumau_player.init_pos(i)
	
	
	
	
	
