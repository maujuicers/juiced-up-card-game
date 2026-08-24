extends Node3D

const MAIN_SCENE = preload("uid://be4pqwq2ycfn3")

@export var settings_menu: Control

func _ready() -> void:
	# Making sure to hide the settings menu
	settings_menu.hide()

func _on_start_game_button_pressed() -> void:
	get_tree().change_scene_to_packed(MAIN_SCENE)


func _on_tutorial_button_pressed() -> void:
	#TODO: Open tutorial popup
	pass


func _on_settings_button_pressed() -> void:
	settings_menu.show()


func _on_quit_button_pressed() -> void:
	get_tree().quit()
