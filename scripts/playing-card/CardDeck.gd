## The canonical set of [Card]s for one client: exactly one instance per
## (suit, rank) in play. Everything that hands out cards (draw pile, hands,
## discard pile) shares these instances, and [method card] resolves an id
## received from another peer back to the local instance.
##
## The default deck lives in [code]scenes/playing-card/deck.tres[/code]; that
## file is the single place where textures are assigned to cards.
##
## To change the size of the deck (e.g. include sixes) set
## [member lowest_rank] and either press "Rebuild cards" in the inspector or run
## [code]godot --path . --headless --script scripts/playing-card/generate_deck.gd[/code].
## Both keep already-assigned textures.
@tool
class_name CardDeck extends Resource

const DEFAULT_UID := "uid://cmfvknwcvgqj5"

## The lowest rank dealt. SEVEN is the classic 32-card German deck; SIX makes 36.
@export var lowest_rank: Card.Rank = Card.Rank.SEVEN
## One entry per (suit, rank) from [member lowest_rank] up to Ace, sorted by id.
## Edit textures here; regenerate the list with [method rebuild] instead of by hand.
@export var cards: Array[Card] = []
@export_tool_button("Rebuild cards") var _rebuild_button := rebuild

var _by_id: Dictionary[int, Card] = {}


static func load_default() -> CardDeck:
	return load(DEFAULT_UID) as CardDeck


## A fresh, unshuffled copy of the card list (the [Card] instances are shared).
func all() -> Array[Card]:
	_ensure_index()
	return cards.duplicate()


func size() -> int:
	return cards.size()


## The local instance for a card id, or [code]null[/code] for an id that is
## not part of this deck.
func card(a_id: int) -> Card:
	_ensure_index()
	return _by_id.get(a_id)


func has_id(a_id: int) -> bool:
	_ensure_index()
	return _by_id.has(a_id)


## Every rank in play, lowest first.
func ranks_in_play() -> Array[Card.Rank]:
	var ranks: Array[Card.Rank] = []
	for rank: Card.Rank in Card.Rank.values():
		if rank >= lowest_rank:
			ranks.append(rank)
	return ranks


## Every id this deck must contain, sorted.
func expected_ids() -> Array[int]:
	var ids: Array[int] = []
	for suit: Card.Suit in Card.Suit.values():
		if suit == Card.Suit.NONE:
			continue
		for rank in ranks_in_play():
			ids.append(Card.make_id(suit, rank))
	ids.sort()
	return ids


## True when [member cards] holds exactly one card for every id in
## [method expected_ids] and nothing else. Reports each problem via
## [method @GlobalScope.push_error].
func validate() -> bool:
	var ok := true
	var seen: Dictionary[int, bool] = {}
	var expected := expected_ids()
	for i in cards.size():
		var c := cards[i]
		if c == null:
			push_error("CardDeck: cards[%d] is empty" % i)
			ok = false
			continue
		if seen.has(c.id):
			push_error("CardDeck: duplicate card %s" % c)
			ok = false
		elif not expected.has(c.id):
			push_error("CardDeck: %s is outside the deck (lowest rank is %s)"
					% [c, Card.rank_name(lowest_rank)])
			ok = false
		seen[c.id] = true
	for a_id in expected:
		if not seen.has(a_id):
			push_error("CardDeck: missing %s" % Card.id_to_string(a_id))
			ok = false
	return ok


## Makes [member cards] match [member lowest_rank]: adds missing cards, drops
## cards that are no longer in play, keeps existing instances (and their
## textures), and sorts by id.
func rebuild() -> void:
	var keep: Dictionary[int, Card] = {}
	for c in cards:
		if c != null and not keep.has(c.id):
			keep[c.id] = c
	var rebuilt: Array[Card] = []
	for a_id in expected_ids():
		var c: Card = keep.get(a_id)
		if c == null:
			c = Card.new()
			c.suit = Card.suit_of(a_id)
			c.rank = Card.rank_of(a_id)
		c.resource_name = str(c)
		rebuilt.append(c)
	cards = rebuilt
	_by_id.clear()
	emit_changed()


func _ensure_index() -> void:
	if not _by_id.is_empty() or cards.is_empty():
		return
	var valid := validate()
	assert(valid, "CardDeck is inconsistent — see errors above; run rebuild()")
	for c in cards:
		if c != null:
			_by_id[c.id] = c
