extends Node3D
class_name Hand

@export var card_scene: PackedScene
@export var card_spacing: float = 0.6

var cards: Array[Card] = []

func update_hand(new_cards: Array[Card]) -> void:
	cards = new_cards.duplicate()
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
	# Remove old card nodes
	for child in get_children():
		child.queue_free()

	if not card_scene or cards.is_empty():
		return

	# Center-align cards along the local X-axis
	var total_cards := cards.size()
	var start_offset := -((total_cards - 1) * card_spacing) / 2.0

	for i in total_cards:
		var card_instance := card_scene.instantiate() as CardVisual
		add_child(card_instance)
		
		card_instance.setup(cards[i])
		card_instance.position = Vector3(start_offset + (i * card_spacing), 0.0, 0.0)
