class_name MauMauRules

static func is_valid_move(card: Card, top_card: Card, wished_suit: Variant, penalty_draw:int) -> bool:
	return card.suit == top_card.suit and penalty_draw == 0 \
		or card.rank == top_card.rank and top_card.rank != Card.Rank.JACK \
		or card.suit == wished_suit and penalty_draw == 0 \
		or card.rank == Card.Rank.JACK and top_card.rank != Card.Rank.JACK
	
static func get_effect(card: Card) -> String:
	match card.rank:
		Card.Rank.SEVEN: return "draw_two"
		Card.Rank.EIGHT: return "skip_next"
		Card.Rank.JACK: return "wish_suit"
		_: return "none"
