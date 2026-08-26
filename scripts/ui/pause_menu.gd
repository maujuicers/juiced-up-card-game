extends Control

@export var settings_menu: Control

var main_menu = load("uid://balrrf21sxhil")

func _on_settings_button_pressed() -> void:
	settings_menu.show()


func _on_main_menu_button_pressed() -> void:
	get_tree().change_scene_to_packed(main_menu)


func _on_close_button_pressed() -> void:
	self.hide()
