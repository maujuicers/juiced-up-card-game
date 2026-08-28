extends Node

class_name MauMauPlayer

signal hand_changed(hand: Array[Card])

## Only set true for AI players
@export var autoplay: bool = false

var hand: Array[Card] = []
var turn_position: int
var placement: int = -1
## The MauMauGameManager that placed this seat; whether the seat may act is its call.
## Typed as Node: the manager names this class, and the cycle breaks the parser.
var manager: Node


func init_hand(first_hand: Array[Card]) -> void:
	self.hand = first_hand
	hand_changed.emit(hand)


func init_pos(turn: int) -> void:
	self.turn_position = turn


## The three intents. Each returns whether the manager accepted the action.
func try_play_card(selected_card_pos: int) -> bool:
	if selected_card_pos < 0 or selected_card_pos >= hand.size():
		return false
	return try_play_card_by_id(hand[selected_card_pos].id)


func try_play_card_by_id(card_id: int) -> bool:
	return manager != null and manager.submit_move(self, card_id)


func draw_card() -> bool:
	return manager != null and manager.submit_draw(self)


func select_suit(suit: Card.Suit) -> bool:
	return manager != null and manager.submit_wish(self, suit)


func add_card(card: Card) -> void:
	hand.append(card)
	hand_changed.emit(hand)


func has_card(card_id: int) -> bool:
	return card_index(card_id) != -1


func card_index(card_id: int) -> int:
	for i in hand.size():
		if hand[i].id == card_id:
			return i
	return -1


## null if this seat does not hold the card.
func remove_card(card_id: int) -> Card:
	var index := card_index(card_id)
	if index == -1:
		return null

	var removed: Card = hand[index]
	hand.remove_at(index)
	hand_changed.emit(hand)
	return removed


func call_mau() -> void:
	print("meow")


func get_hand_size() -> int:
	return hand.size()


func _to_string() -> String:
	var owner_name := get_parent().name if get_parent() != null else name
	return "%s (seat %d)" % [owner_name, turn_position]
