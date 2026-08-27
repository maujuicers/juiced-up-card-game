extends Control

class_name SettingsMenu

## Slider midpoint (50) maps to this.
const DEFAULT_MOUSE_SENSITIVITY := 0.01
const MOUSE_SENSITIVITY_SLIDER_MIDPOINT := 50.0

## Using floats from 0 to 1
const DEFAULT_MASTER_VOLUME := 1
const DEFAULT_MUSIC_VOLUME := 1
const DEFAULT_SFX_VOLUME := 1

const DEFAULT_WINDOW_MODE := DisplayServer.WINDOW_MODE_WINDOWED

signal mouse_sensitivity_changed(sensitivity: float)

@export var master_volume_value_label: Label
@export var music_value_label: Label
@export var sfx_value_label: Label
@export var master_volume_slider: HSlider
@export var music_slider: HSlider
@export var sfx_slider: HSlider
@export var mouse_sensitivity_value_label: Label
@export var mouse_sensitivity_slider: HSlider
@export var fullscreen_button: CheckButton
@export var settings_saved_label: Label
@export var save_settings_question: Control

var save_button_was_pressed: bool = false

## The one place slider and radians-per-pixel meet, so load/save/live agree.
static func slider_value_to_sensitivity(value: float) -> float:
	return value / MOUSE_SENSITIVITY_SLIDER_MIDPOINT * DEFAULT_MOUSE_SENSITIVITY

static func sensitivity_to_slider_value(sensitivity: float) -> float:
	return sensitivity / DEFAULT_MOUSE_SENSITIVITY * MOUSE_SENSITIVITY_SLIDER_MIDPOINT

## For PlayerController at startup, without a menu in the scene.
static func load_mouse_sensitivity() -> float:
	var config = ConfigFile.new()
	if config.load("user://settings.cfg") != OK:
		return DEFAULT_MOUSE_SENSITIVITY
	return config.get_value("ControlSettings", "MouseSensitivity", DEFAULT_MOUSE_SENSITIVITY)

func _ready() -> void:
	load_settings_config()
	settings_saved_label.hide()
	save_settings_question.hide()

func load_settings_config() -> void:
	var config = ConfigFile.new()
	var err = config.load("user://settings.cfg")
	
	if err != OK:
		master_volume_slider.value = DEFAULT_MASTER_VOLUME * 100
		music_slider.value = DEFAULT_MUSIC_VOLUME * 100
		sfx_slider.value = DEFAULT_SFX_VOLUME * 100
		fullscreen_button.button_pressed = false
		mouse_sensitivity_slider.value = sensitivity_to_slider_value(DEFAULT_MOUSE_SENSITIVITY)
		return
	
	var master_volume = config.get_value("AudioSettings", "Master", DEFAULT_MASTER_VOLUME)
	var music_volume = config.get_value("AudioSettings", "Music", DEFAULT_MUSIC_VOLUME)
	var sfx_volume = config.get_value("AudioSettings", "SFX", DEFAULT_SFX_VOLUME)
	var window_mode = config.get_value("VideoSettings", "WindowMode", DEFAULT_WINDOW_MODE)
	var mouse_sensitivity = config.get_value("ControlSettings", "MouseSensitivity", DEFAULT_MOUSE_SENSITIVITY)
	
	master_volume_slider.value = master_volume * 100
	music_slider.value = music_volume * 100
	sfx_slider.value = sfx_volume * 100
	mouse_sensitivity_slider.value = sensitivity_to_slider_value(mouse_sensitivity)
	
	if(window_mode == DisplayServer.WINDOW_MODE_FULLSCREEN):
		fullscreen_button.button_pressed = true
	else:
		fullscreen_button.button_pressed = false

func _on_close_button_pressed() -> void:
	if(save_button_was_pressed):
		save_button_was_pressed = false
		self.hide()
	else:
		save_settings_question.show()

func _on_fullscreen_button_toggled(toggled_on: bool) -> void:
	if toggled_on == true:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	save_button_was_pressed = false

func _on_save_button_pressed() -> void:
	var new_config = ConfigFile.new()
	
	save_button_was_pressed = true
	
	new_config.set_value("AudioSettings", "Master", AudioServer.get_bus_volume_linear(0))
	new_config.set_value("AudioSettings", "Music", AudioServer.get_bus_volume_linear(3))
	new_config.set_value("AudioSettings", "SFX", AudioServer.get_bus_volume_linear(1))
	new_config.set_value("VideoSettings", "WindowMode", DisplayServer.window_get_mode())
	new_config.set_value("ControlSettings", "MouseSensitivity", slider_value_to_sensitivity(mouse_sensitivity_slider.value))
	
	new_config.save("user://settings.cfg")
	
	print("Saved Master Volume value: %s" % new_config.get_value("AudioSettings", "Master", 1))
	
	settings_saved_label.show()
	await get_tree().create_timer(2).timeout
	settings_saved_label.hide()

func _on_master_volume_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(0, value/100) # value/100 because it's way too loud otherwise
	master_volume_value_label.text = str(int(value))
	save_button_was_pressed = false

func _on_music_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(3, value/100)
	music_value_label.text = str(int(value))
	save_button_was_pressed = false

func _on_sfx_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_linear(1, value/100)
	AudioServer.set_bus_volume_linear(2, value/100)
	sfx_value_label.text = str(int(value))
	save_button_was_pressed = false

func _on_mouse_sensitivity_slider_value_changed(value: float) -> void:
	mouse_sensitivity_value_label.text = str(int(value))
	mouse_sensitivity_changed.emit(slider_value_to_sensitivity(value))
	save_button_was_pressed = false

func _on_yes_button_pressed() -> void:
	_on_save_button_pressed()
	save_settings_question.hide()
	self.hide()

func _on_no_button_pressed() -> void:
	load_settings_config()
	save_button_was_pressed = false
	save_settings_question.hide()
	self.hide()
