class_name MauMauRules

static func is_valid_move(card: Card, top_card: Card, wished_suit: Variant) -> bool:
	return card.suit == top_card.suit \
		or card.rank == top_card.rank \
		or card.suit == wished_suit \
		or card.rank == Card.Rank.JACK
	
static func get_effect(card: Card) -> String:
	match card.rank:
		Card.Rank.SEVEN: return "draw_two"
		Card.Rank.EIGHT: return "skip_next"
		Card.Rank.JACK: return "wish_suit"
		_: return "none"
