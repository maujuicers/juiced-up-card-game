extends Node

class_name MauMauPlayer

signal card_selected(selected_card:Card)
signal card_drawn()
signal suit_wished(suit: Card.Suit)

var hand:Array = []
var turn_position:int
var turn_active:bool = false;
var placement: int = -1

func init_hand(first_hand: Array) -> void:
	self.hand = first_hand
	
func init_pos(turn: int):
	self.turn_position = turn
	
func on_turn_started() -> void:
	turn_active = true;
	print("MauMauPlayer at seat %d is thinking..." % turn_position)
	
func try_play_card(selected_card_pos:int) -> void:
	if not turn_active:
		return
		
	var selected_card: Card = hand[selected_card_pos]
	card_selected.emit(selected_card)	
	
# draw function if player doesnt have fitting cards
func draw_card(draw_amount: int = 1) -> void:
	card_drawn.emit(draw_amount)
	
# draw function for rank 7 cards
func draw_penalty_card(draw_amount: int) -> void:
	if not hand.any(func(card: Card): return card.rank == Card.Rank.SEVEN):
		card_drawn.emit(draw_amount)
	
func select_suit(suit: Card.Suit) -> void:
	print("%s was wished" % Card.Suit.keys()[suit])
	suit_wished.emit(suit)

func play_card(player_index: int, played_card: Card) -> void:
	if player_index == turn_position:
		print("card was played")
		turn_active = false
		if played_card in hand:
			hand.erase(played_card)
			
func call_mau()-> void:
	print("meow")
			
func get_hand_size() -> int:
	return hand.size()
			
