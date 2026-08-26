extends Control

@export var master_volume_value_label: Label
@export var music_value_label: Label
@export var sfx_value_label: Label
@export var master_volume_slider: HSlider
@export var music_slider: HSlider
@export var sfx_slider: HSlider
@export var fullscreen_button: CheckButton
@export var settings_saved_label: Label

func _ready() -> void:
	load_settings_config()
	settings_saved_label.hide()

func load_settings_config() -> void:
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	
	if err != OK:
		return
	
	var master_volume = config.get_value("AudioSettings", "Master", 0)
	var music_volume = config.get_value("AudioSettings", "Music", 0)
	var sfx_volume = config.get_value("AudioSettings", "SFX", 0)
	var window_mode = config.get_value("VideoSettings", "WindowMode", DisplayServer.WINDOW_MODE_WINDOWED)
	
	master_volume_slider.value = master_volume * 100
	music_slider.value = music_volume * 100
	sfx_slider.value = sfx_volume * 100
	
	if(window_mode == DisplayServer.WINDOW_MODE_FULLSCREEN):
		fullscreen_button.button_pressed = true
	else:
		fullscreen_button.button_pressed = false

func _on_close_button_pressed() -> void:
	self.hide()


func _on_fullscreen_button_toggled(toggled_on: bool) -> void:
	if toggled_on == true:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func _on_save_button_pressed() -> void:
	var new_config = ConfigFile.new()
	
	new_config.set_value("AudioSettings", "Master", AudioServer.get_bus_volume_linear(0))
	new_config.set_value("AudioSettings", "Music", AudioServer.get_bus_volume_linear(3))
	new_config.set_value("AudioSettings", "SFX", AudioServer.get_bus_volume_linear(1))
	new_config.set_value("VideoSettings", "WindowMode", DisplayServer.window_get_mode())
	
	new_config.save("user://settings.cfg")
	
	
	settings_saved_label.show()
	await get_tree().create_timer(2).timeout
	settings_saved_label.hide()

func _on_master_volume_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(0, value/100) # value/100 because it's way too loud otherwise
	master_volume_value_label.text = str(int(value))


func _on_music_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(3, value/100)
	music_value_label.text = str(int(value))

func _on_sfx_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(1, value/100)
	AudioServer.set_bus_volume_linear(2, value/100)
	sfx_value_label.text = str(int(value))
