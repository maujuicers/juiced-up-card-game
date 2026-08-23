extends Node

class_name MauMauPlayer

signal played_card

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
	
func play_card(played_card:Card) -> void:
	if not turn_active:
		return
		
	if played_card in hand:
		hand.erase(played_card)
		turn_active = false
		played_card.emit(played_card)	
