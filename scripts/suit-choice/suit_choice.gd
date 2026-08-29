extends Node3D

class_name SuitChoiceNode

@export var interactive: bool = true
@export var mau_mau_player: MauMauPlayer
@export var current_wished_suit_node: Node3D
@export var wished_suit_sprite: Sprite3D
@export var heart_sprite: Texture
@export var club_sprite: Texture
@export var spade_sprite: Texture
@export var diamond_sprite: Texture

const PICK_RAY_LENGTH := 2.0

var _aimed: SuitChoiceVisual = null

func init_suit_choice() -> void:
	current_wished_suit_node.hide()
	mau_mau_player.manager.suit_wished.connect(translate_suit_to_sprite)
	mau_mau_player.manager.suit_wished.connect(self.hide)
	# Hides the sprite every time a card is played after wish; TODO: maybe modify for wrong card cheat
	mau_mau_player.manager.card_played.connect(current_wished_suit_node.hide)

func _physics_process(_delta: float) -> void:
	if not interactive:
		return
	_set_aimed(_suit_choice_at(_screen_centre()))

func _unhandled_input(event: InputEvent) -> void:
	if not interactive or mau_mau_player == null:
		return
	var button := event as InputEventMouseButton
	if button == null or button.button_index != MOUSE_BUTTON_LEFT or not button.pressed:
		return
	var suit_choice := _suit_choice_at(_screen_centre())
	if suit_choice == null or suit_choice.suit == null:
		return
		
	get_viewport().set_input_as_handled()
	mau_mau_player.try_choosing_suit(suit_choice.suit)

func _set_aimed(suit_choice: SuitChoiceVisual) -> void:
	if suit_choice == _aimed and is_instance_valid(_aimed):
		return
	if is_instance_valid(_aimed):
		_aimed.set_highlighted(false)
	_aimed = suit_choice
	if _aimed != null:
		_aimed.set_highlighted(true)

func _screen_centre() -> Vector2:
	return get_viewport().get_visible_rect().size / 2.0

func _suit_choice_at(screen_pos: Vector2) -> SuitChoiceVisual:
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
	while node != null and not (node is SuitChoiceVisual):
		node = node.get_parent()
	# Cards dropped by a rebuild linger for one more frame.
	if node != null and node.get_parent() == self and not node.is_queued_for_deletion():
		return node as SuitChoiceVisual
	return null

func translate_suit_to_sprite(suit: Card.Suit) -> void:
	match suit:
		Card.Suit.HEARTS:
			wished_suit_sprite.texture = heart_sprite
		Card.Suit.DIAMONDS:
			wished_suit_sprite.texture = diamond_sprite
		Card.Suit.CLUBS:
			wished_suit_sprite.texture = club_sprite
		Card.Suit.SPADES:
			wished_suit_sprite.texture = spade_sprite
