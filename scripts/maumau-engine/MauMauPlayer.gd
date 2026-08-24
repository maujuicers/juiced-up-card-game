extends Node

class_name MauMauPlayer

signal card_selected(selected_card:Card)

var hand:Array = []
var turn_position:int
var turn_active:bool = false;

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

func play_card(player_index: int, played_card: Card) -> void:
	if player_index == turn_position:
		print("card was played")
		turn_active = false
		if played_card in hand:
			hand.erase(played_card)
