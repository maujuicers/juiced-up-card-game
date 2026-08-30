extends Node3D
class_name CardSlip

## The animation behind [signal MauMauGameManager.card_slipped]: a face-down card
## glides from the cheating seat's fan into its victim's, so anyone whose eyes
## are on the table sees who did it. Which card changed hands never shows —
## that is what the two private hands are for.

## Long enough to catch out of the corner of an eye, short enough to fit between
## two turns.
const FLIGHT_TIME := 0.9
## How far above the straight line the card passes; the arc is what makes the
## move readable from the far side of the table.
const ARC_HEIGHT := 0.25

@export var manager: MauMauGameManager
@export var card_scene: PackedScene
## Taken from the default [CardDeck] when empty.
@export var card_back: Texture2D
## The local seat's head, so the back of the card keeps facing the eyes.
@export var player: PlayerController
## Where a seat's fan hangs in its marker's frame. The two participant scenes
## put their Hand node in slightly different places, so a seat gets the offset
## of whichever scene sits in it.
@export var player_hand_offset := Vector3(0.0, 0.57, -0.5)
@export var npc_hand_offset := Vector3(0.0, 0.58, -0.32)


func _ready() -> void:
	if card_back == null:
		var deck := CardDeck.load_default()
		if deck != null:
			card_back = deck.back_texture
	if manager != null:
		manager.card_slipped.connect(_on_card_slipped)


func _on_card_slipped(giver: int, receiver: int) -> void:
	if card_scene == null or manager == null:
		return
	var from := _hand_position(giver)
	var to := _hand_position(receiver)

	var card := card_scene.instantiate() as PlayingCardVisual
	card.hover_highlight = false
	add_child(card)
	card.setup(null, false, card_back)
	# A card that is only passing through must not take the crosshair's aim.
	if card.pick_area != null:
		card.pick_area.collision_layer = 0
	_fly(0.0, card, from, to)

	var flight := create_tween()
	flight.tween_method(_fly.bind(card, from, to), 0.0, 1.0, FLIGHT_TIME)
	flight.tween_callback(card.queue_free)


func _fly(progress: float, card: Node3D, from: Vector3, to: Vector3) -> void:
	if not is_instance_valid(card):
		return
	var point := from.lerp(to, progress)
	point.y += ARC_HEIGHT * sin(progress * PI)
	card.global_position = point
	if player != null and player.player_head != null:
		card.look_at(player.player_head.global_position, Vector3.UP, true)


## A seat's fan, read off its chair: a participant is snapped onto the marker,
## so the marker's frame is the participant's.
func _hand_position(seat: int) -> Vector3:
	var marker := manager.marker_for_seat(seat)
	if marker == null:
		return global_position
	var offset := player_hand_offset if marker.occupant == player else npc_hand_offset
	return marker.to_global(offset)
