## Decisions for seats that play themselves.
class_name MauMauAi


## Prefers the suit the seat holds most of; Jacks are kept for when stuck.
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


static func choose_suit(hand: Array[Card]) -> Card.Suit:
	var counts := suit_counts(hand)
	var best := Card.Suit.HEARTS
	var best_count := -1
	for suit: Card.Suit in counts:
		if counts[suit] > best_count:
			best = suit
			best_count = counts[suit]
	return best


static func suit_counts(hand: Array[Card]) -> Dictionary[Card.Suit, int]:
	var counts: Dictionary[Card.Suit, int] = {}
	for card in hand:
		if card.rank == Card.Rank.JACK:
			continue
		counts[card.suit] = counts.get(card.suit, 0) + 1
	return counts
