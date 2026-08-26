## Headless (re)generator for the default [CardDeck]:
## [code]godot --path . --headless --script scripts/playing-card/generate_deck.gd[/code]
##
## Loads [code]deck.tres[/code] if it exists (keeping its [member CardDeck.lowest_rank]
## and any textures already assigned), rebuilds the card list, and saves it back
## under the stable [constant CardDeck.DEFAULT_UID].
extends SceneTree

const DECK_PATH := "res://scenes/playing-card/deck.tres"


func _initialize() -> void:
	var deck: CardDeck = load(DECK_PATH) if ResourceLoader.exists(DECK_PATH) else CardDeck.new()
	deck.rebuild()
	if not deck.validate():
		push_error("generate_deck: rebuilt deck is invalid, not saving")
		quit(1)
		return
	var err := ResourceSaver.save(deck, DECK_PATH)
	if err == OK:
		err = _stamp_uid(DECK_PATH, CardDeck.DEFAULT_UID)
	if err != OK:
		push_error("generate_deck: could not save %s (%s)" % [DECK_PATH, error_string(err)])
		quit(1)
		return
	print("generate_deck: wrote %d cards (%s and up) to %s"
			% [deck.size(), Card.rank_name(deck.lowest_rank), DECK_PATH])
	quit()


## Outside the editor ResourceSaver writes no uid, so put the canonical one into
## the [code][gd_resource ...][/code] header ourselves.
func _stamp_uid(path: String, uid: String) -> Error:
	var text := FileAccess.get_file_as_string(path)
	if text.is_empty():
		return FileAccess.get_open_error()
	var header_end := text.find("]")
	var header := text.substr(0, header_end)
	var uid_start := header.find(" uid=")
	if uid_start != -1:
		header = header.substr(0, uid_start)
	text = header + ' uid="%s"' % uid + text.substr(header_end)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(text)
	return OK
