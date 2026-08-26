extends Control

@export var master_volume_value_label: Label
@export var music_value_label: Label
@export var sfx_value_label: Label

func _on_close_button_pressed() -> void:
	self.hide()


func _on_fullscreen_button_toggled(toggled_on: bool) -> void:
	if toggled_on == true:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_save_button_pressed() -> void:
	pass # Replace with function body.

func _on_master_volume_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(0, value/100)
	master_volume_value_label.text = str(int(value))


func _on_music_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(3, value/100)
	music_value_label.text = str(int(value))

func _on_sfx_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(1, value/100)
	AudioServer.set_bus_volume_linear(2, value/100)
	sfx_value_label.text = str(int(value))
