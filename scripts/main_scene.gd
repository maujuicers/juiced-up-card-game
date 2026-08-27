extends Node3D

@export var player: PlayerController
@export var pause_menu: Control
@export var settings_menu: SettingsMenu

func _ready() -> void:
	pause_menu.hide()
	settings_menu.hide()
	# Single owner of the mouse mode: whenever either menu is shown or hidden --
	# by "ui_cancel", by a Close button, by the Settings button -- looking is
	# re-evaluated, so the controller and the menus can never disagree.
	pause_menu.visibility_changed.connect(_update_look)
	settings_menu.visibility_changed.connect(_update_look)
	# Live feedback: dragging the sensitivity slider retunes the look straight
	# away; the Save button is what makes it stick to user://settings.cfg.
	settings_menu.mouse_sensitivity_changed.connect(player.set_look_sensitivity)
	_update_look()

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	# "ui_cancel" walks one menu back out: settings -> pause -> gameplay.
	if settings_menu.visible:
		settings_menu.hide()
	elif pause_menu.visible:
		pause_menu.hide()
	else:
		pause_menu.show()
	get_viewport().set_input_as_handled()

func _update_look() -> void:
	player.set_look_enabled(not (pause_menu.visible or settings_menu.visible))
