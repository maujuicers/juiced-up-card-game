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
	Method.FIVE:  45,
	Method.SIX:   30,
}

## How long after being charged a cheat can still be called out. Wall clock,
## not turns: an NPC's next play used to close the window within a second.
const CALL_WINDOW_MSEC := 10_000

@export var method: Method
@export var card: Card #only used on cheats, using playing cars (Methods: 1,3,4,5)
@export var stolen_card: Card #only used on exchange (Method 4)
## Time.get_ticks_msec() when the juice was paid.
var charged_at_msec: int = 0

var juice_cost: int:
	get:
		return JUICE_COSTS.get(method, 0)
		
		
func is_expired() -> bool:
	return Time.get_ticks_msec() - charged_at_msec >= CALL_WINDOW_MSEC

##Initialization methods##
static func init_cheat(m: Method, c: Card = null, s: Card = null) -> Cheat:
	var ch: Cheat
	match m:
		Method.TWO, Method.SIX:
			ch = without_cards(m)
		Method.FOUR:
			ch = exchange_card(c, s)
		_:
			ch = with_card(m, c)
	
	ch.charged_at_msec = Time.get_ticks_msec()
	return ch
		
static func without_cards(m: Method) -> Cheat:
	var ch := Cheat.new()
	ch.method = m
	return ch
	
static func with_card(m: Method, c: Card) ->Cheat:
	var ch := Cheat.new()
	ch.method = m
	ch.card = c
	return ch
	
static func exchange_card(c: Card, s: Card)-> Cheat:
	var ch := Cheat.new()
	ch.method = Method.FOUR
	ch.card = c
	ch.stolen_card = s
	return ch
