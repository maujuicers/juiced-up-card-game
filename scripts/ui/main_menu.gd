extends Node3D


func _on_start_game_button_pressed() -> void:
	#TODO: get_tree().change_to_packed()
	pass


func _on_tutorial_button_pressed() -> void:
	#TODO: Open tutorial popup
	pass


func _on_settings_button_pressed() -> void:
	#TODO: Open settings menu
	pass


func _on_quit_button_pressed() -> void:
	get_tree().quit()
