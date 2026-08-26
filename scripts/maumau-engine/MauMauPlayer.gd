extends Node

class_name MauMauPlayer

## Emitted when this seat wants to play the card with the given stable
## [member Card.id]. The manager validates the move and calls [method play_card].
signal card_selected(card_id: int)
signal card_drawn()
signal suit_wished(suit: Card.Suit)

var hand: Array[Card] = []
var turn_position: int
var turn_active: bool = false
var placement: int = -1


func init_hand(first_hand: Array[Card]) -> void:
	self.hand = first_hand


func init_pos(turn: int) -> void:
	self.turn_position = turn


func on_turn_started() -> void:
	turn_active = true
	print("MauMauPlayer at seat %d is thinking..." % turn_position)


func try_play_card(selected_card_pos: int) -> void:
	if not turn_active:
		return
	if selected_card_pos < 0 or selected_card_pos >= hand.size():
		return

	card_selected.emit(hand[selected_card_pos].id)


# draw function if player doesnt have fitting cards
func draw_card(draw_amount: int = 1) -> void:
	card_drawn.emit(draw_amount)


# draw function for rank 7 cards
func draw_penalty_card(draw_amount: int) -> void:
	if not hand.any(func(card: Card) -> bool: return card.rank == Card.Rank.SEVEN):
		card_drawn.emit(draw_amount)


func select_suit(suit: Card.Suit) -> void:
	print("%s was wished" % Card.suit_name(suit))
	suit_wished.emit(suit)


func add_card(card: Card) -> void:
	hand.append(card)


func has_card(card_id: int) -> bool:
	return card_index(card_id) != -1


## Index of the card with [param card_id] in [member hand], or -1 if not held.
func card_index(card_id: int) -> int:
	for i in hand.size():
		if hand[i].id == card_id:
			return i
	return -1


## Removes the card with [param card_id] from the hand and returns it.
## Returns null if this seat is not on turn or does not hold that card.
func play_card(player_index: int, card_id: int) -> Card:
	if player_index != turn_position:
		return null

	var index := card_index(card_id)
	if index == -1:
		return null

	var played_card: Card = hand[index]
	hand.remove_at(index)
	turn_active = false
	print("%s was played" % played_card)
	return played_card


func call_mau() -> void:
	print("meow")


func get_hand_size() -> int:
	return hand.size()
