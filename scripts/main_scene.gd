extends Node3D

@export var player: PlayerController
@export var pause_menu: Control
@export var settings_menu: SettingsMenu

func _ready() -> void:
	pause_menu.hide()
	settings_menu.hide()
	# Driven by visibility so every close path (Esc, Close, Settings) hands the mouse back.
	pause_menu.visibility_changed.connect(_update_look)
	pause_menu.hidden.connect(show_crosshair)
	settings_menu.visibility_changed.connect(_update_look)
	settings_menu.mouse_sensitivity_changed.connect(player.set_look_sensitivity)
	_update_look()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if settings_menu.visible:
		settings_menu.hide()
	elif pause_menu.visible:
		show_crosshair()
		pause_menu.hide()
	else:
		player.crosshair.hide()
		pause_menu.show()
	get_viewport().set_input_as_handled()

func _update_look() -> void:
	player.set_look_enabled(not (pause_menu.visible or settings_menu.visible))

func show_crosshair() -> void:
	player.crosshair.show()
