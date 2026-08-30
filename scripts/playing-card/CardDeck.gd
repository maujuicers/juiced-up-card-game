## One shared [Card] instance per (suit, rank); ids from other peers resolve
## through [method card]. To change the deck size set [member lowest_rank] and
## press "Rebuild cards" (or run generate_deck.gd); textures are kept.
@tool
class_name CardDeck extends Resource

const DEFAULT_UID := "uid://cmfvknwcvgqj5"

## playingCards_Mat_baseColor.png (4096²): one row per suit, one column per
## rank Ace..King, backs in the top half. Faces are stored mirrored, so the
## sprite flips horizontally. The cards were laid out by hand, so the column
## pitch wanders (299–332 px) and each left edge is listed explicitly.
const ATLAS_CELL := Vector2i(259, 387)
const ATLAS_COLUMN_X: Array[int] = [
	64, 370, 675, 989, 1298, 1608, 1917, 2216, 2518, 2820, 3119, 3439, 3771,
]
const ATLAS_ROW_Y := {
	Card.Suit.SPADES: 2370,
	Card.Suit.CLUBS: 2808,
	Card.Suit.DIAMONDS: 3235,
	Card.Suit.HEARTS: 3660,
}
const ATLAS_BACK := Rect2i(85, 72, 259, 387)

## SEVEN = 32-card deck, SIX = 36.
@export var lowest_rank: Card.Rank = Card.Rank.SEVEN
## Edit textures here; regenerate the list with [method rebuild], not by hand.
@export var cards: Array[Card] = []
@export_tool_button("Rebuild cards") var _rebuild_button := rebuild
@export var atlas: Texture2D
## Cut from [member atlas] when left empty.
@export var back_texture: Texture2D

var _by_id: Dictionary[int, Card] = {}


static func load_default() -> CardDeck:
	return load(DEFAULT_UID) as CardDeck


## A copy of the list; the [Card] instances are shared.
func all() -> Array[Card]:
	_ensure_index()
	return cards.duplicate()


func size() -> int:
	return cards.size()


func card(a_id: int) -> Card:
	_ensure_index()
	return _by_id.get(a_id)


func has_id(a_id: int) -> bool:
	_ensure_index()
	return _by_id.has(a_id)


func ranks_in_play() -> Array[Card.Rank]:
	var ranks: Array[Card.Rank] = []
	for rank: Card.Rank in Card.Rank.values():
		if rank >= lowest_rank:
			ranks.append(rank)
	return ranks


func expected_ids() -> Array[int]:
	var ids: Array[int] = []
	for suit: Card.Suit in Card.Suit.values():
		if suit == Card.Suit.NONE:
			continue
		for rank in ranks_in_play():
			ids.append(Card.make_id(suit, rank))
	ids.sort()
	return ids


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


## Keeps existing instances; see [method _is_own_cut] for which textures survive.
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
		if atlas != null and _is_own_cut(c.texture):
			c.texture = _cut(atlas_face_region(c.suit, c.rank), str(c))
		rebuilt.append(c)
	if atlas != null and _is_own_cut(back_texture):
		back_texture = _cut(ATLAS_BACK, "card back")
	cards = rebuilt
	_by_id.clear()
	emit_changed()


static func atlas_face_region(a_suit: Card.Suit, a_rank: Card.Rank) -> Rect2i:
	var column := 0 if a_rank == Card.Rank.ACE else a_rank - 1
	return Rect2i(Vector2i(ATLAS_COLUMN_X[column], ATLAS_ROW_Y[a_suit]), ATLAS_CELL)


## Only hand-assigned textures survive a rebuild; regions cut from the deck's
## own atlas are re-derived so a constant change reaches deck.tres.
func _is_own_cut(tex: Texture2D) -> bool:
	return tex == null or (tex is AtlasTexture and (tex as AtlasTexture).atlas == atlas)


func _cut(region: Rect2i, name: String) -> AtlasTexture:
	var tex := AtlasTexture.new()
	tex.atlas = atlas
	tex.region = region
	tex.resource_name = name
	return tex


func _ensure_index() -> void:
	if not _by_id.is_empty() or cards.is_empty():
		return
	var valid := validate()
	assert(valid, "CardDeck is inconsistent, see errors above; run rebuild()")
	for c in cards:
		if c != null:
			_by_id[c.id] = c
