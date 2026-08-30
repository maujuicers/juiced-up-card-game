extends Control

class_name Tutorial

@export var pages: Array[Texture]
@export var page_node: TextureRect

var counter: int = 0

func show_first_page() -> void:
	counter = 0
	page_node.texture = pages[counter]


func _on_next_button_pressed() -> void:
	if counter == 2:
		return
	counter += 1
	page_node.texture = pages[counter]


func _on_close_button_pressed() -> void:
	show_first_page()
	self.hide()


func _on_back_button_pressed() -> void:
	if counter == 0:
		return
	counter -=  1
	page_node.texture = pages[counter]
