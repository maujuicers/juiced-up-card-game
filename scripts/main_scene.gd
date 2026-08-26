extends Node3D

@export var pause_menu: Control
@export var settings_menu: Control

func _ready() -> void:
	pause_menu.hide()
	settings_menu.hide()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		pause_menu.show()
