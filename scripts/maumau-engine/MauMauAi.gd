## Decisions for seats that play themselves. Static and stateless, like
## [MauMauRules]; the manager asks and then feeds the answer through the same
## seat methods a human uses.
class_name MauMauAi


## The card to play now, or null when nothing in [param hand] is legal.
## Prefers cards of the suit the seat holds most of (so the next turn is more
## likely to have a match again) and keeps Jacks for when nothing else fits.
static func choose_card(hand: Array[Card], top_card: Card, wished_suit: Card.Suit, penalty_draw: int) -> Card:
	var counts := suit_counts(hand)
	var best: Card = null
	var best_score := -INF
	for card in hand:
		if not MauMauRules.is_valid_move(card, top_card, wished_suit, penalty_draw):
			continue
		var score := float(counts.get(card.suit, 0))
		if card.rank == Card.Rank.JACK:
			score -= 100.0
		if score > best_score:
			best = card
			best_score = score
	return best


## The suit to wish after a Jack: the one the seat still holds most of.
static func choose_suit(hand: Array[Card]) -> Card.Suit:
	var counts := suit_counts(hand)
	var best := Card.Suit.HEARTS
	var best_count := -1
	for suit: Card.Suit in counts:
		if counts[suit] > best_count:
			best = suit
			best_count = counts[suit]
	return best


## How many non-Jack cards of each suit [param hand] holds.
static func suit_counts(hand: Array[Card]) -> Dictionary[Card.Suit, int]:
	var counts: Dictionary[Card.Suit, int] = {}
	for card in hand:
		if card.rank == Card.Rank.JACK:
			continue
		counts[card.suit] = counts.get(card.suit, 0) + 1
	return counts
