extends Node3D

@export var manager: MauMauGameManager
@export var card_scene: PackedScene
@export var card_back: Texture2D
@export var player: PlayerController

func _ready() -> void:
	manager.base_card_played.connect(show_base_card)
	manager.card_played.connect(show_last_card)
	
	if card_back == null:
		var deck := CardDeck.load_default()
		if deck != null:
			card_back = deck.back_texture
	
	for child in get_children():
		child.queue_free()

## The same as show last card but without second param
func show_base_card(card: Card) -> void:
	for child in get_children():
		child.queue_free()
		
	if not card_scene:
		return
	
	var head_global = player.player_head.global_position
	var card_instance := card_scene.instantiate() as PlayingCardVisual
	
	card_instance.hover_highlight = false
	add_child(card_instance)
	card_instance.setup(card, true, card_back)
	card_instance.scale = Vector3(2.0,2.0,1.0)
	card_instance.look_at(head_global, Vector3.UP, true)

func show_last_card(_player_index: int, card: Card) -> void:
	for child in get_children():
		child.queue_free()
		
	if not card_scene:
		return
	
	var head_global = player.player_head.global_position
	var card_instance := card_scene.instantiate() as PlayingCardVisual
	
	card_instance.hover_highlight = false
	add_child(card_instance)
	card_instance.setup(card, true, card_back)
	card_instance.scale = Vector3(2.0,2.0,1.0)
	card_instance.look_at(head_global, Vector3.UP, true)
