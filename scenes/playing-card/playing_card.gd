extends Node3D
class_name CardVisual

@export var card_sprite: Sprite3D

var card_data: Card

func setup(data: Card) -> void:
	card_data = data
	_update_graphics()

func _update_graphics() -> void:
	if not card_data:
		return
		
	if card_sprite and card_data.texture:
		card_sprite.texture = card_data.texture
