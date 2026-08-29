extends Control

@export var settings_menu: Control
@export var click_sfx: AudioStream

var main_menu = load("uid://balrrf21sxhil")

func _on_settings_button_pressed() -> void:
	AudioManager.play_ui(click_sfx)
	settings_menu.show()


func _on_main_menu_button_pressed() -> void:
	AudioManager.play_ui(click_sfx)
	# The main menu has no PlayerController to release the mouse.
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().change_scene_to_packed(main_menu)


func _on_close_button_pressed() -> void:
	AudioManager.play_ui(click_sfx)
	self.hide()
