## Pure card data. Cards are a flyweight: at runtime every (suit, rank) exists
## exactly once per client, owned by a [CardDeck]. Instances are therefore
## shared and must be treated as immutable — never assign to [member suit],
## [member rank] or [member texture] outside the editor. Identity comparisons
## (`==`, `in`, `Array.erase`) work locally; only [member id] crosses the wire.
class_name Card extends Resource

## [constant NONE] is only meaningful as "no wished suit", never on a card.
enum Suit {NONE = -1, HEARTS, DIAMONDS, CLUBS, SPADES}

## Values are the card's pip value (Jack = 11 … Ace = 14). They are explicit so
## that changing the lowest rank in play (see [member CardDeck.lowest_rank])
## never renumbers the others — ids and saved [code].tres[/code] data stay valid.
## They also line up with the "<suit><01-13>" numbering of the card assets
## (there Ace is 01 and King is 13).
enum Rank {SIX = 6, SEVEN = 7, EIGHT = 8, NINE = 9, TEN = 10, JACK = 11, QUEEN = 12, KING = 13, ACE = 14}

## Stride between suits in [member id]; leaves room for every rank value.
const _RANK_STRIDE := 16

@export var suit: Suit
@export var rank: Rank
@export var texture: Texture2D

## Stable, deck-independent identity of this card, derived from (suit, rank).
## This — not the [Card] instance — is what gets sent between peers.
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


## "SEVEN of HEARTS" for a card id, without needing the [Card] instance.
static func id_to_string(a_id: int) -> String:
	return "%s of %s" % [rank_name(rank_of(a_id)), suit_name(suit_of(a_id))]


func _to_string() -> String:
	return id_to_string(id)
