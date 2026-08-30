extends Node3D
class_name Hand

## Cards sit on an arc centred on the seat's head so each one faces the eyes.
## This node's position is the middle of the fan; its rotation is ignored.

@export var card_scene: PackedScene
## Unset: [member head_offset] relative to the parent seat is used instead.
@export var head: Node3D
@export var head_offset := Vector3(0.0, 0.79, 0.0)
## Below a card's width (~0.07) so cards always overlap.
@export var max_card_spacing: float = 0.05
@export var max_spread_degrees: float = 50.0
@export var face_up: bool = true
## Taken from the default [CardDeck] when empty.
@export var card_back: Texture2D
@export var maumau_player: MauMauPlayer
## Only the human seat: aim the crosshair, left-click to play.
@export var interactive: bool = false

const PICK_RAY_LENGTH := 2.0
## The picked card's own colour, so it is never mistaken for the aim highlight.
const PICKED_COLOR := Color(1.0, 0.72, 0.2)
## How far the picked card leaves the fan, towards the eyes that look at it.
const PICKED_LIFT := 0.03

## Lifted out of the fan and waiting to be slipped to another seat, null for none.
signal picked_card_changed(card: Card)

var cards: Array[Card] = []
var picked_card: Card = null

var _aimed: PlayingCardVisual = null


func _ready() -> void:
	if card_back == null:
		var deck := CardDeck.load_default()
		if deck != null:
			card_back = deck.back_texture
	if maumau_player != null:
		maumau_player.hand_changed.connect(update_hand)
		update_hand(maumau_player.hand)


# Physics step: the pick ray queries the physics space.
func _physics_process(_delta: float) -> void:
	if not interactive:
		return
	_set_aimed(_card_at(_screen_centre()))


func _set_aimed(card: PlayingCardVisual) -> void:
	if card == _aimed and is_instance_valid(_aimed):
		return
	if is_instance_valid(_aimed):
		# The pick owns its outline; only the aim highlight is taken back.
		_aimed.set_highlighted(_is_picked(_aimed.card_data))
	_aimed = card
	if _aimed != null:
		_aimed.set_highlighted(true)


func _screen_centre() -> Vector2:
	return get_viewport().get_visible_rect().size / 2.0


# The mouse is captured, so event.position is meaningless; the crosshair
# (screen centre) is the pointer.
func _unhandled_input(event: InputEvent) -> void:
	if not interactive or maumau_player == null:
		return

	if event.is_action_pressed("pick_card"):
		var aimed := _card_at(_screen_centre())
		if aimed == null or aimed.card_data == null:
			return
		# Eaten here so the Accuser behind the hand does not read the same key
		# as "accuse the cat past this card".
		get_viewport().set_input_as_handled()
		set_picked_card(null if _is_picked(aimed.card_data) else aimed.card_data)
		return

	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
		return

	var card := _card_at(_screen_centre())
	if card == null or card.card_data == null:
		return

	get_viewport().set_input_as_handled()
	maumau_player.try_play_card_by_id(card.card_data.id)


## The card the crosshair is on, null for none. A click on one belongs to it.
func aimed_card() -> Card:
	return _aimed.card_data if is_instance_valid(_aimed) else null


## Lifts a card out of the fan; null puts down whatever was picked.
func set_picked_card(card: Card) -> void:
	if _is_picked(card) or (card == null and picked_card == null):
		return
	picked_card = card
	_rebuild_hand()
	picked_card_changed.emit(picked_card)


func _is_picked(card: Card) -> bool:
	return card != null and picked_card != null and card.id == picked_card.id


# Areas only, any layer: independent of the card scene's layer choice.
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

	var node := hit.get("collider") as Node
	while node != null and not (node is PlayingCardVisual):
		node = node.get_parent()
	# Cards dropped by a rebuild linger for one more frame.
	if node != null and node.get_parent() == self and not node.is_queued_for_deletion():
		return node as PlayingCardVisual
	return null


func update_hand(new_cards: Array[Card]) -> void:
	cards = new_cards.duplicate()
	# A card this hand no longer holds cannot stay lifted out of it.
	var lost := picked_card != null and not cards.has(picked_card)
	if lost:
		picked_card = null
	_rebuild_hand()
	if lost:
		picked_card_changed.emit(null)


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
	_set_aimed(null)
	for child in get_children():
		child.queue_free()

	if not card_scene or cards.is_empty():
		return

	var total_cards := cards.size()
	var middle := (total_cards - 1) / 2.0
	var head_global := _head_global_position()
	var up_global := _seat_up()
	var head_local := to_local(head_global)
	var up_local := (global_basis.inverse() * up_global).normalized()
	var head_to_centre := -head_local
	var radius := head_to_centre.slide(up_local).length()
	var step_angle := max_card_spacing / maxf(radius, 0.01)
	if total_cards > 1:
		step_angle = minf(step_angle, deg_to_rad(max_spread_degrees) / (total_cards - 1))

	for i in total_cards:
		var card_instance := card_scene.instantiate() as PlayingCardVisual
		# Aiming owns the highlight; a captured cursor never hovers anyway.
		card_instance.hover_highlight = not interactive
		add_child(card_instance)
		card_instance.setup(cards[i], face_up, card_back)
		# First card on the left so slots match the 1–9 debug keys.
		var offset := head_to_centre.rotated(up_local, (middle - i) * step_angle)
		# A hair nearer the eyes per card so overlaps draw in order.
		offset -= offset.normalized() * (i * 0.001)
		if _is_picked(cards[i]):
			offset -= offset.normalized() * PICKED_LIFT
			card_instance.outline_color = PICKED_COLOR
			card_instance.set_highlighted(true)
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
