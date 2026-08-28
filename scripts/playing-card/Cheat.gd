class_name Cheat extends Resource

enum Method {ONE, TWO, THREE, FOUR, FIVE, SIX}

#Cheat.Method.ONE: return "wrong_card_played"
#Cheat.Method.TWO: return "peeked_into_player_hand"
#Cheat.Method.THREE: return "played_special_card"
#Cheat.Method.FOUR: return "exchanged_card_with_player"
#Cheat.Method.FIVE: return "slipped_card_into_player_hand"
#Cheat.Method.SIX: return "spiked_drink"

const JUICE_COSTS := {
	Method.ONE:   5,
	Method.TWO:   10,
	Method.THREE: 15,
	Method.FOUR:  20,
	Method.FIVE:  25,
	Method.SIX:   30,
}

@export var method: Method
@export var card: Card #only used on cheats, using playing cars (Methods: 1,3,4,5)
@export var stolen_card: Card #only used on exchange (Method 4)

var juice_cost: int:
	get:
		return JUICE_COSTS.get(method, 0)
		
static func without_cards(m: Method) -> Cheat:
	var ch := Cheat.new()
	ch.method = m
	return ch
	
static func with_card(m: Method, c: Card) ->Cheat:
	var ch := Cheat.new()
	ch.method = m
	return ch
	
static func exchange_card(c: Card, s: Card)-> Cheat:
	var ch := Cheat.new()
	ch.method = Method.FOUR
	return ch
