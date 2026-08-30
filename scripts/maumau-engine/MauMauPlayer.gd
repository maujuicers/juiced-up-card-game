extends Node

class_name MauMauPlayer

signal hand_changed(hand: Array[Card])
## Relayed by the manager to this seat alone, so the views beside it can
## subscribe before the manager exists.
signal turn_started
signal turn_ended
signal wish_requested

## Only set true for AI players
@export var autoplay: bool = false

## Audio
@export var click_sfx: AudioStream
@export var cheat_meow_sfx_list: Array[AudioStream]
@export var angry_meow_sfx_list: Array[AudioStream]
@export var sad_meow_sfx_list: Array[AudioStream]
@export var npc_audio: EntityAudio

@export var current_player_label: CurrentPlayerLabel
@export var current_player_arrow: CurrentPlayerArrow


@export var suit_choice_node: SuitChoiceNode

var move_card_sfx_list: Array[AudioStream]
var neutral_meow_sfx_list: Array[AudioStream]
var hand: Array[Card] = []
var turn_position: int
var placement: int = -1

## The MauMauGameManager that placed this seat; whether the seat may act is its call.
## Typed as Node: the manager names this class, and the cycle breaks the parser.
var manager: Node
var _filler: Card

# Cheat Variables
var cheated: bool = false
var cheats: Array[Cheat]
var cheat_counter: int = 0
var cheat_accusation: bool = false
var cheat_penalties: int = 0

# variables for drinking
@export var juice: Juice
var juice_bottle: JuiceBottle
var is_drinking: bool


func init_hand(first_hand: Array[Card]) -> void:
	self.hand = first_hand
	hand_changed.emit(hand)

func init_juice_bottle() -> void:
	juice_bottle = JuiceBottle.new()

func seat_at(game_manager: Node, index: int) -> void:
	manager = game_manager
	turn_position = index
	if current_player_label != null:
		current_player_label.init_label(self, manager)
	if current_player_arrow != null:
		current_player_arrow.init_player_arrow(self, manager)
	if suit_choice_node != null:
		suit_choice_node.init_suit_choice()
	init_card_played_listener()

func init_card_played_listener() -> void:
	if manager != null:
		manager.connect("card_played", _on_card_played)

func _on_card_played(player_index: int, card: Card) -> void:
	if player_index == turn_position:
		return  
		
	print("player %s sees that a move was made")
	for i in range(cheats.size() - 1, -1, -1):
		cheats[i].tick_turn()
		if cheats[i].is_expired():
			cheats.remove_at(i)
	cheated = not cheats.is_empty()


## The private payload: this hand as card ids.
func hand_ids() -> PackedInt32Array:
	var ids := PackedInt32Array()
	for card in hand:
		ids.append(card.id)
	return ids


## Replaces the hand from the private payload, resolved through the manager's deck.
func set_hand_ids(ids: PackedInt32Array) -> void:
	var cards: Array[Card] = []
	for id in ids:
		var card: Card = manager.deck.card(id)
		if card == null:
			push_error("%s received unknown card id %d" % [self, id])
			continue
		cards.append(card)
	hand = cards
	hand_changed.emit(hand)


## Mirrors another seat's hand on a client, where only its size is public:
## the cards are one shared placeholder and are never shown face up.
func set_hand_count(count: int) -> void:
	count = maxi(count, 0)
	if count == hand.size():
		return
	if count < hand.size():
		hand.resize(count)
	else:
		var filler := _face_down_filler()
		if filler == null:
			push_error("%s cannot pad a hidden hand without a deck" % self)
			return
		while hand.size() < count:
			hand.append(filler)
	hand_changed.emit(hand)


func _face_down_filler() -> Card:
	if _filler != null:
		return _filler
	if manager == null or manager.deck == null:
		return null
	var cards: Array[Card] = manager.deck.all()
	if not cards.is_empty():
		_filler = cards[0]
	return _filler


## The three intents. Each returns whether the manager accepted the action.
func try_play_card(selected_card_pos: int) -> bool:
	if selected_card_pos < 0 or selected_card_pos >= hand.size():
		return false
	return try_play_card_by_id(hand[selected_card_pos].id)


func try_play_card_by_id(card_id: int) -> bool:
	if autoplay:
		if npc_audio != null:
			npc_audio.play_random(neutral_meow_sfx_list)
	else:
		AudioManager.play_ui(click_sfx, -5.0)
	return manager != null and manager.submit_move(self, card_id)

func try_choosing_suit(suit: Card.Suit) -> bool:
	return manager != null and manager.submit_wish(self, suit)

func draw_card() -> bool:
	if autoplay:
		if npc_audio != null:
			npc_audio.play_random(sad_meow_sfx_list)
			npc_audio.play_random(move_card_sfx_list)
	else:
		AudioManager.play_sfx(sad_meow_sfx_list[randi_range(0, 1)])
		AudioManager.play_sfx(move_card_sfx_list[randi_range(0, 2)])
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
	
func call_waiter() -> void:
	if juice_bottle.is_empty():
		var ordered_juice = JuiceBottle.new()
		juice_bottle = ordered_juice
		
func drink() -> void:
	if juice_bottle != null and not juice_bottle.is_empty():
		is_drinking = true
		juice_bottle.juice_empty.connect(stop_drinking)
		juice_bottle.sip_taken.connect(_on_bottle_sip_taken)

func stop_drinking()-> void:
	if self.is_drinking:
		juice_bottle.juice_empty.disconnect(stop_drinking)
		juice_bottle.sip_taken.disconnect(_on_bottle_sip_taken)
		is_drinking = false
		if juice_bottle != null:
			juice_bottle.stop_drinking()
		
func _on_bottle_sip_taken(amount: int) -> void:
	if self.juice != null:
		self.juice.set_juice(self.juice.current_juice + amount)
		print("Player drank juice! Juice level is now: ", self.juice.current_juice)
	
############ Cheat Functions ###########
func peek(player: MauMauPlayer) -> void:
	trigger_cheat(Cheat.Method.TWO)
	
func play_fixed_card(card: Card) -> void:
	trigger_cheat(Cheat.Method.THREE, card)
	
func exchange_card(player: MauMauPlayer, given_card: Card, stolen_card: Card) -> void:
	trigger_cheat(Cheat.Method.FOUR, given_card, stolen_card)
	
func slip_card(player: MauMauPlayer, given_card: Card) -> void:
	trigger_cheat(Cheat.Method.FIVE, given_card)
	
func spike_drink(player: MauMauPlayer) -> void:
	trigger_cheat(Cheat.Method.SIX)

func trigger_cheat(method: Cheat.Method, card: Card = null, exchanged_card: Card = null) -> bool:
	#check if player has enough juice first
	var attempted_cheat = Cheat.init_cheat(method, card, exchanged_card)
	if(self.juice.current_juice < attempted_cheat.juice_cost):
		return false
		
	
	if autoplay:
		if npc_audio != null:
			npc_audio.play_random(cheat_meow_sfx_list)
	else:
		AudioManager.play_sfx(cheat_meow_sfx_list[randi_range(0, 1)])
		
	# set all cheat variables for player
	self.juice.deduct_juice(attempted_cheat.juice_cost)
	cheat_counter += 1
	cheated = true
	cheats.append(attempted_cheat)
	print("Player %s just cheated" %[self.turn_position])
	
	return true
	
		
func call_cheater(cheater: MauMauPlayer, method : Cheat.Method)-> void:
	if autoplay:
		if npc_audio != null:
			npc_audio.play_random(angry_meow_sfx_list)
	else:
		AudioManager.play_sfx(angry_meow_sfx_list[randi_range(0, 2)])
	print(cheater.cheated)
	cheat_accusation = true
	if cheater.remove_cheat(method):
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
	
func remove_cheat(method: Cheat.Method) -> bool:
	var index := cheat_index(method)
	if index == -1:
		return false
	cheats.remove_at(index)
	cheated = not cheats.is_empty()
	return true

func cheat_index(method: Cheat.Method) -> int:
	for i in cheats.size():
		if cheats[i].method == method:
			return i
	return -1
