extends Node

class_name MauMauPlayer

signal hand_changed(hand: Array[Card])

## Only set true for AI players
@export var autoplay: bool = false

var hand: Array[Card] = []
var turn_position: int
var placement: int = -1
var cheated: bool = false
var cheat: Cheat
var cheat_counter: int = 0
var cheat_accusation: bool = false
var cheat_penalties: int = 0
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
	
func trigger_cheat(duration: float, method: Cheat.Method, card: Card = null, exchanged_card: Card = null) -> void:
	cheat_counter += 1
	cheated = true
	cheat = Cheat.with_card(Cheat.Method.ONE, card)
	print("I just cheated hehe")
	var this_call := cheat_counter
	await get_tree().create_timer(duration).timeout
	if this_call == cheat_counter:
		cheated = false
		cheat = null
		print("cheat cant be called anymore")
		
func call_cheater(cheater: MauMauPlayer)-> void:
	print(cheater.cheated)
	cheat_accusation = true
	if cheater.cheated:
		cheater.cheat_accusation = true;
		print("player %s got called out by player %s for his cheat and has to draw cards" % [cheater.turn_position, self.turn_position])
		cheater.cheat_penalty()
	else:
		print("player %s didnt cheat so player %s has to draw cards, for calling him out" % [cheater.turn_position, self.turn_position])
		cheat_penalty()
		
	cheat_accusation = false
	cheater.cheat_accusation = false

func cheat_penalty() -> void:
	cheat_penalties += 1
	print("player %s received %d penalties now" % [self.turn_position, self.cheat_penalties])
	self.manager._set_penalty()
	draw_card()

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
