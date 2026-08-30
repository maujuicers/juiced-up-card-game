extends Node

class_name MauMauPlayer

signal hand_changed(hand: Array[Card])
## Relayed by the manager to this seat alone, so the views beside it can
## subscribe before the manager exists.
signal turn_started
signal turn_ended
signal wish_requested
## This seat's bottle: how much is left, -1 for no bottle at all.
signal bottle_changed(content: int)

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
var cheat_penalties: int = 0

# variables for drinking
const SIP_INTERVAL := 1.0
const SIP_AMOUNT := 10

@export var juice: Juice
var juice_bottle: JuiceBottle
## Authority only: whether the sip timer is running.
var is_drinking: bool = false
var _sip_timer: Timer


func init_hand(first_hand: Array[Card]) -> void:
	self.hand = first_hand
	hand_changed.emit(hand)

func init_juice_bottle() -> void:
	juice_bottle = JuiceBottle.new()
	bottle_changed.emit(bottle_content())

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


## The four intents. Each returns whether the manager accepted the action.
func try_play_card(selected_card_pos: int) -> bool:
	if selected_card_pos < 0 or selected_card_pos >= hand.size():
		return false
	return try_play_card_by_id(hand[selected_card_pos].id)


func try_play_card_by_id(card_id: int) -> bool:
	if autoplay:
		_play_meow(neutral_meow_sfx_list)
	else:
		AudioManager.play_ui(click_sfx, -5.0)
	return manager != null and manager.submit_move(self, card_id)

func try_choosing_suit(suit: Card.Suit) -> bool:
	return manager != null and manager.submit_wish(self, suit)

func draw_card() -> bool:
	_play_meow(sad_meow_sfx_list)
	_play_meow(move_card_sfx_list)
	return manager != null and manager.submit_draw(self)


func select_suit(suit: Card.Suit) -> bool:
	return manager != null and manager.submit_wish(self, suit)


## Accuse another seat of a cheat; the manager's gate decides and penalises.
func try_accuse(target: MauMauPlayer, method: Cheat.Method = Cheat.Method.ONE) -> bool:
	return manager != null and manager.submit_accuse(self, target, method)


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
	
## Three more intents, all off turn; the gate decides, the authority acts.
func drink() -> bool:
	return manager != null and manager.submit_drink(self, true)


func stop_drinking() -> bool:
	return manager != null and manager.submit_drink(self, false)


func call_waiter() -> bool:
	return manager != null and manager.submit_waiter(self)


## How much is left to drink, -1 when the seat holds no bottle.
func bottle_content() -> int:
	return juice_bottle.current_juice_content if juice_bottle != null else -1


## Authority only. Already drinking is accepted and changes nothing, so a
## second press cannot double the sip rate.
func begin_drinking() -> bool:
	if is_drinking:
		return true
	if juice_bottle == null or juice_bottle.is_empty():
		return false
	if juice == null or juice.current_juice >= juice.max_juice:
		return false
	is_drinking = true
	_sips().start(SIP_INTERVAL)
	return true


## Authority only.
func end_drinking() -> bool:
	if not is_drinking:
		return false
	is_drinking = false
	if _sip_timer != null:
		_sip_timer.stop()
	return true


## Authority only: the waiter brings a bottle only when there is none to finish.
func order_bottle() -> bool:
	if juice_bottle != null and not juice_bottle.is_empty():
		return false
	juice_bottle = JuiceBottle.new()
	bottle_changed.emit(bottle_content())
	return true


## The mirror of the authority's bottle on this seat's own client, which never sips.
func set_bottle_content(content: int) -> void:
	if content < 0:
		juice_bottle = null
	else:
		if juice_bottle == null:
			juice_bottle = JuiceBottle.new()
		juice_bottle.current_juice_content = content
	bottle_changed.emit(bottle_content())


func _sips() -> Timer:
	if _sip_timer == null:
		_sip_timer = Timer.new()
		_sip_timer.timeout.connect(_on_sip)
		add_child(_sip_timer)
	return _sip_timer


func _on_sip() -> void:
	if juice_bottle == null:
		end_drinking()
		return
	var amount := juice_bottle.take_sip(SIP_AMOUNT)
	if amount > 0 and juice != null:
		juice.set_juice(juice.current_juice + amount)
	if juice_bottle.is_empty():
		juice_bottle = null
		end_drinking()
	elif juice != null and juice.current_juice >= juice.max_juice:
		end_drinking()
	bottle_changed.emit(bottle_content())


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
	var attempted_cheat := Cheat.init_cheat(method, card, exchanged_card)
	if juice == null or not juice.deduct_juice(attempted_cheat.juice_cost):
		return false

	_play_meow(cheat_meow_sfx_list)
	cheat_counter += 1
	cheated = true
	cheats.append(attempted_cheat)
	print("Player %s just cheated" %[self.turn_position])

	return true


## Flavour only: this seat pointed the finger. The manager judged it already.
func on_accusation_made() -> void:
	_play_meow(angry_meow_sfx_list)


## Flavour only: this seat was caught.
func on_caught_cheating() -> void:
	_play_meow(cheat_meow_sfx_list)


## A server-side table has no sound at all, so an empty list must not be indexed.
func _play_meow(sounds: Array[AudioStream]) -> void:
	if sounds.is_empty():
		return
	if autoplay:
		if npc_audio != null:
			npc_audio.play_random(sounds)
	else:
		AudioManager.play_sfx(sounds.pick_random())


## Removes this seat's pending cheat of that method and returns it, null for none.
func take_cheat(method: Cheat.Method) -> Cheat:
	var index := cheat_index(method)
	if index == -1:
		return null
	var caught: Cheat = cheats[index]
	cheats.remove_at(index)
	cheated = not cheats.is_empty()
	return caught


func remove_cheat(method: Cheat.Method) -> bool:
	return take_cheat(method) != null

func cheat_index(method: Cheat.Method) -> int:
	for i in cheats.size():
		if cheats[i].method == method:
			return i
	return -1
