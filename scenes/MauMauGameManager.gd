extends Node

#Signals
signal card_played(player_index: int, card: Card)
signal turn_changed(new_player_index: int)
signal effect_triggered(effect: String)
signal game_over(winner_index: int)

@export var npcs: Array[Node]
@export var player: Node

#Game state
var cards_per_player :=5
var draw_pile: Array[Card] = []
var discard_pile: Array[Card] = []
var hands: Array = []
var current_player: int = 0
var wished_suit: Card.Suit

func _ready() -> void:
	start_game()
	for i in range(hands.size()):
		print("Player ", i, " hand")
		for card in hands[i]:
			print(Card.Rank.keys()[card.rank] , " " , Card.Suit.keys()[card.suit])

func start_game() -> void:
	reset_game()
	build_draw_pile()
	draw_pile.shuffle()
	init_player_hands(npcs.size() + 1)
	
	
	pass # TODO: build + shuffle the deck, deal hands, flip first discard

func play_card(player_index: int, card: Card) -> void:
	pass # TODO: check MauMauRules.is_valid_move, move the card, trigger effects

func draw_card(player_index: int) -> void:
	pass # TODO: move the top of draw_pile into that player's hand

func advance_turn() -> void:
	pass # TODO: move current_player forward, respecting skip effects
	
func reset_game() -> void:
	draw_pile.clear()
	discard_pile.clear()
	hands.clear()
	current_player = 0
	
func build_draw_pile() -> void:
	for suit in Card.Suit.values():
		for rank in Card.Rank.values():
			var new_card := Card.new()
			new_card.suit = suit
			new_card.rank = rank
			draw_pile.append(new_card)
			
func init_player_hands(num_players: int) -> void:
	for p in range(num_players):
		var player_hand: Array[Card] = []
		for i in range(cards_per_player):
			player_hand.append(draw_pile.pop_back())
		hands.append(player_hand)
	
