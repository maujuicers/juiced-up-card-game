## The canonical set of [Card]s for one client: exactly one instance per
## (suit, rank) in play. Everything that hands out cards (draw pile, hands,
## discard pile) shares these instances, and [method card] resolves an id
## received from another peer back to the local instance.
##
## The default deck lives in [code]scenes/playing-card/deck.tres[/code]; that
## file is the single place where textures are assigned to cards. Cards without
## a texture get one cut from [member atlas] by [method rebuild].
##
## To change the size of the deck (e.g. include sixes) set
## [member lowest_rank] and either press "Rebuild cards" in the inspector or run
## [code]godot --path . --headless --script scripts/playing-card/generate_deck.gd[/code].
## Both keep already-assigned textures.
@tool
class_name CardDeck extends Resource

const DEFAULT_UID := "uid://cmfvknwcvgqj5"

## Layout of the playing-card atlas (assets/3D assets/playing cards/textures/
## playingCards_Mat_baseColor.png, 4096²). Faces sit on a grid, one row per suit
## and one column per rank from Ace to King; the top half holds card backs.
## The faces are stored mirrored, so whatever displays them flips horizontally.
const ATLAS_CELL := Vector2i(255, 383)
const ATLAS_FIRST_COLUMN_X := 65
const ATLAS_COLUMN_STEP := 309
const ATLAS_ROW_Y := {
	Card.Suit.SPADES: 2372,
	Card.Suit.CLUBS: 2808,
	Card.Suit.DIAMONDS: 3237,
	Card.Suit.HEARTS: 3662,
}
const ATLAS_BACK := Rect2i(85, 72, 255, 383)

## The lowest rank dealt. SEVEN is the classic 32-card German deck; SIX makes 36.
@export var lowest_rank: Card.Rank = Card.Rank.SEVEN
## One entry per (suit, rank) from [member lowest_rank] up to Ace, sorted by id.
## Edit textures here; regenerate the list with [method rebuild] instead of by hand.
@export var cards: Array[Card] = []
@export_tool_button("Rebuild cards") var _rebuild_button := rebuild
## Source image for card faces and the back; see the ATLAS_* constants.
@export var atlas: Texture2D
## Shown for every face-down card. Cut from [member atlas] when left empty.
@export var back_texture: Texture2D

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
## textures), sorts by id, and cuts a texture from [member atlas] for every
## card (and the back) that has none.
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
		if c.texture == null and atlas != null:
			c.texture = _cut(atlas_face_region(c.suit, c.rank), str(c))
		rebuilt.append(c)
	if back_texture == null and atlas != null:
		back_texture = _cut(ATLAS_BACK, "card back")
	cards = rebuilt
	_by_id.clear()
	emit_changed()


## Pixel rectangle of a card face in [member atlas].
static func atlas_face_region(a_suit: Card.Suit, a_rank: Card.Rank) -> Rect2i:
	var column := 0 if a_rank == Card.Rank.ACE else a_rank - 1
	var x := ATLAS_FIRST_COLUMN_X + column * ATLAS_COLUMN_STEP
	return Rect2i(Vector2i(x, ATLAS_ROW_Y[a_suit]), ATLAS_CELL)


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
	assert(valid, "CardDeck is inconsistent — see errors above; run rebuild()")
	for c in cards:
		if c != null:
			_by_id[c.id] = c
