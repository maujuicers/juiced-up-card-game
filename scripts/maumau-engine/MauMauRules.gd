class_name MauMauRules

## With a draw penalty pending only a counter (matching rank, i.e. another
## seven) is legal; everything else, including a Jack, has to wait.
static func is_valid_move(card: Card, top_card: Card, wished_suit: Card.Suit, penalty_draw:int) -> bool:
	return card.suit == top_card.suit and penalty_draw == 0 \
		or card.rank == top_card.rank and top_card.rank != Card.Rank.JACK \
		or card.suit == wished_suit and penalty_draw == 0 \
		or card.rank == Card.Rank.JACK and top_card.rank != Card.Rank.JACK and penalty_draw == 0
	
## True when at least one card in [param hand] could be played right now.
static func has_valid_move(hand: Array[Card], top_card: Card, wished_suit: Card.Suit, penalty_draw: int) -> bool:
	for card in hand:
		if is_valid_move(card, top_card, wished_suit, penalty_draw):
			return true
	return false


static func get_effect(card: Card) -> String:
	match card.rank:
		Card.Rank.SEVEN: return "draw_two"
		Card.Rank.EIGHT: return "skip_next"
		Card.Rank.JACK: return "wish_suit"
		_: return "none"
