extends Node3D
class_name Hand

## Lays out one seat's cards on an arc around the seat's head, every card
## facing the eyes. Follows [member maumau_player] when set; otherwise drive it
## with [method update_hand] / [method update_hidden].
##
## This node's position is where the middle of the fan sits; its rotation does
## not matter.

@export var card_scene: PackedScene
## The eyes the cards face and the centre of the arc they sit on. When unset,
## [member head_offset] relative to the parent seat is used instead.
@export var head: Node3D
@export var head_offset := Vector3(0.0, 0.79, 0.0)
## Widest distance between neighbouring card centres along the arc. Smaller
## than a card's width (~0.07) so they always overlap a little.
@export var max_card_spacing: float = 0.05
## The whole fan never spans more than this; big hands get squeezed together.
@export var max_spread_degrees: float = 50.0
## Face up for the local player, face down for everyone else.
@export var face_up: bool = true
## Texture for face-down cards; taken from the default [CardDeck] when empty.
@export var card_back: Texture2D
## The seat whose hand this shows.
@export var maumau_player: MauMauPlayer
## Let the local user pick a card out of this fan with the left mouse button.
## Only the seat the human sits in should have this on.
@export var interactive: bool = false

## How far in front of the camera a click still finds a card.
const PICK_RAY_LENGTH := 2.0

var cards: Array[Card] = []


func _ready() -> void:
	if card_back == null:
		var deck := CardDeck.load_default()
		if deck != null:
			card_back = deck.back_texture
	if maumau_player != null:
		maumau_player.hand_changed.connect(update_hand)
		update_hand(maumau_player.hand)


## Left-clicking a card of this hand asks the seat to play it. Runs after the
## UI, so a click that landed on a control never reaches a card. The manager
## still validates the move: an illegal one is refused and the seat keeps its
## turn, and a Jack is followed by the usual suit wish.
func _unhandled_input(event: InputEvent) -> void:
	if not interactive or maumau_player == null:
		return
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
		return

	var card := _card_at(button.position)
	if card == null or card.card_data == null:
		return

	get_viewport().set_input_as_handled()
	maumau_player.try_play_card_by_id(card.card_data.id)


## The [PlayingCardVisual] of this hand under [param screen_pos], or null.
## Queries areas only and on every layer, so it does not care which collision
## layer the card scene puts its picking shape on.
func _card_at(screen_pos: Vector2) -> PlayingCardVisual:
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return null

	var from := camera.project_ray_origin(screen_pos)
	var to := from + camera.project_ray_normal(screen_pos) * PICK_RAY_LENGTH
	var query := PhysicsRayQueryParameters3D.create(from, to)
	query.collide_with_areas = true
	query.collide_with_bodies = false
	query.collision_mask = 0xFFFFFFFF

	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return null

	# The shape can sit anywhere below the card root; climb to the card itself.
	var node := hit.get("collider") as Node
	while node != null and not (node is PlayingCardVisual):
		node = node.get_parent()
	# Only cards of this fan; another seat's hand answers for its own.
	if node != null and node.get_parent() == self:
		return node as PlayingCardVisual
	return null


func update_hand(new_cards: Array[Card]) -> void:
	cards = new_cards.duplicate()
	_rebuild_hand()


## For seats whose cards are not known locally: show [param count] backs.
func update_hidden(count: int) -> void:
	cards.clear()
	cards.resize(count)
	_rebuild_hand()


func add_card(card_data: Card) -> void:
	cards.append(card_data)
	_rebuild_hand()


func remove_card(card_data: Card) -> void:
	cards.erase(card_data)
	_rebuild_hand()


func clear_hand() -> void:
	cards.clear()
	_rebuild_hand()


func _rebuild_hand() -> void:
	for child in get_children():
		child.queue_free()

	if not card_scene or cards.is_empty():
		return

	var total_cards := cards.size()
	var middle := (total_cards - 1) / 2.0
	var head_global := _head_global_position()
	var up_global := _seat_up()
	# Work in this node's space: the arc is centred on the head, passes through
	# this node's origin, and turns around the seat's up axis.
	var head_local := to_local(head_global)
	var up_local := (global_basis.inverse() * up_global).normalized()
	var head_to_centre := -head_local
	var radius := head_to_centre.slide(up_local).length()
	var step_angle := max_card_spacing / maxf(radius, 0.01)
	if total_cards > 1:
		step_angle = minf(step_angle, deg_to_rad(max_spread_degrees) / (total_cards - 1))

	for i in total_cards:
		var card_instance := card_scene.instantiate() as PlayingCardVisual
		add_child(card_instance)
		card_instance.setup(cards[i], face_up, card_back)
		# First card on the seat's left, so slots match the 1–9 debug keys.
		var offset := head_to_centre.rotated(up_local, (middle - i) * step_angle)
		# Each later card sits a hair nearer the eyes so overlaps draw in order.
		offset -= offset.normalized() * (i * 0.001)
		card_instance.position = head_local + offset
		card_instance.look_at(head_global, up_global, true)


func _head_global_position() -> Vector3:
	if head != null:
		return head.global_position
	var seat := get_parent() as Node3D
	if seat != null:
		return seat.to_global(head_offset)
	return global_position + head_offset


func _seat_up() -> Vector3:
	var seat := get_parent() as Node3D
	return seat.global_basis.y.normalized() if seat != null else Vector3.UP
