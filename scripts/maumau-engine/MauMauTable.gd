class_name MauMauTable
extends RefCounted

## The public half of the game state: everything every seat may see. The manager
## emits one on [signal MauMauGameManager.table_changed] after each change;
## [method to_dict] is the wire shape. Hands are deliberately absent — only their
## counts are here; the cards go to one seat via
## [signal MauMauGameManager.private_hand_changed].

## Card id of the discard top; -1 until the first discard.
var top_card: int = -1
## Seat index on turn.
var turn: int = -1
var wished_suit: Card.Suit = Card.Suit.NONE
var draw_penalty: int = 0
var awaiting_wish: bool = false
## The seat on turn already drew: it may play that card or draw again to pass.
var has_drawn: bool = false
var hand_counts: PackedInt32Array = []
## Per seat; -1 while still in the round.
var placements: PackedInt32Array = []
## Seat indices in the order they went out. Complete once [member round_over].
var finish_order: PackedInt32Array = []
var draw_pile_size: int = 0
var round_over: bool = false


func seat_count() -> int:
	return hand_counts.size()


func winner() -> int:
	return finish_order[0] if finish_order.size() > 0 else -1


func loser() -> int:
	return finish_order[-1] if round_over and finish_order.size() > 0 else -1


func to_dict() -> Dictionary:
	return {
		"top_card": top_card,
		"turn": turn,
		"wished_suit": wished_suit,
		"draw_penalty": draw_penalty,
		"awaiting_wish": awaiting_wish,
		"has_drawn": has_drawn,
		"hand_counts": hand_counts,
		"placements": placements,
		"finish_order": finish_order,
		"draw_pile_size": draw_pile_size,
		"round_over": round_over,
	}


static func from_dict(data: Dictionary) -> MauMauTable:
	var table := MauMauTable.new()
	table.top_card = data.get("top_card", -1)
	table.turn = data.get("turn", -1)
	table.wished_suit = data.get("wished_suit", Card.Suit.NONE) as Card.Suit
	table.draw_penalty = data.get("draw_penalty", 0)
	table.awaiting_wish = data.get("awaiting_wish", false)
	table.has_drawn = data.get("has_drawn", false)
	table.hand_counts = PackedInt32Array(data.get("hand_counts", []))
	table.placements = PackedInt32Array(data.get("placements", []))
	table.finish_order = PackedInt32Array(data.get("finish_order", []))
	table.draw_pile_size = data.get("draw_pile_size", 0)
	table.round_over = data.get("round_over", false)
	return table


func _to_string() -> String:
	return "MauMauTable(top=%d turn=%d wish=%s penalty=%d hands=%s over=%s)" % [
		top_card, turn, Card.suit_name(wished_suit), draw_penalty, hand_counts, round_over]
