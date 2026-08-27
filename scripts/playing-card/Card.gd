## All card instances are shared so NEVER EDIT A CARDS RANK OR VALUE
class_name Card extends Resource

enum Suit {NONE = -1, HEARTS, DIAMONDS, CLUBS, SPADES}

enum Rank {SIX = 6, SEVEN = 7, EIGHT = 8, NINE = 9, TEN = 10, JACK = 11, QUEEN = 12, KING = 13, ACE = 14}

## Larger than any rank value.
const _RANK_STRIDE := 16

@export var suit: Suit
@export var rank: Rank
@export var texture: Texture2D

## Stable card ID derived from [member suit] and
## [member rank], same card -> same id
## Send this int to other peers, they resolve it with [method CardDeck.card].
var id: int:
	get:
		return make_id(suit, rank)


static func make_id(a_suit: Suit, a_rank: Rank) -> int:
	return a_suit * _RANK_STRIDE + a_rank


static func suit_of(a_id: int) -> Suit:
	@warning_ignore("integer_division")
	return (a_id / _RANK_STRIDE) as Suit


static func rank_of(a_id: int) -> Rank:
	return (a_id % _RANK_STRIDE) as Rank


static func suit_name(a_suit: Suit) -> String:
	return Suit.find_key(a_suit)


static func rank_name(a_rank: Rank) -> String:
	return Rank.find_key(a_rank)


static func id_to_string(a_id: int) -> String:
	return "%s of %s" % [rank_name(rank_of(a_id)), suit_name(suit_of(a_id))]


func _to_string() -> String:
	return id_to_string(id)
