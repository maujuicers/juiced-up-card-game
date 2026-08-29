extends Node3D

@export var settings_menu: Control
@export var click_sfx: AudioStream

const MAIN_SCENE = preload("uid://be4pqwq2ycfn3")

func _ready() -> void:
	# Making sure to hide the settings menu
	settings_menu.hide()
	AudioManager.stop_music()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		AudioManager.play_ui(click_sfx)
		settings_menu.hide()

func _on_start_game_button_pressed() -> void:
	AudioManager.play_ui(click_sfx)
	get_tree().change_scene_to_packed(MAIN_SCENE)


func _on_tutorial_button_pressed() -> void:
	#TODO: Open tutorial popup
	AudioManager.play_ui(click_sfx)
	pass


func _on_settings_button_pressed() -> void:
	AudioManager.play_ui(click_sfx)
	settings_menu.show()


func _on_quit_button_pressed() -> void:
	AudioManager.play_ui(click_sfx)
	get_tree().quit()
