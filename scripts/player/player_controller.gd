extends Node3D

class_name PlayerController

## Radians per pixel. Fallback only: _ready loads the saved setting.
@export var look_sensitivity := 0.01

@export var player_camera: Camera3D
@export var player_head: Node3D
@export var juice: Juice
@export var maumau_player: MauMauPlayer

## MainScene owns this (menus release the mouse); nothing else may call
## Input.set_mouse_mode() during gameplay.
var _look_enabled := false

func _ready() -> void:
	set_look_sensitivity(SettingsMenu.load_mouse_sensitivity())
	set_look_enabled(true)

func set_look_sensitivity(value: float) -> void:
	look_sensitivity = value

func set_look_enabled(enabled: bool) -> void:
	_look_enabled = enabled
	if enabled:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

# Clicks are left for Hand.
func _unhandled_input(event: InputEvent) -> void:
	if _look_enabled and event is InputEventMouseMotion:
		_rotate_view(event.relative)

func _rotate_view(relative: Vector2) -> void:
	player_head.rotate_y(-relative.x * look_sensitivity)
	player_camera.rotate_x(-relative.y * look_sensitivity)
	player_camera.rotation.x = clamp(player_camera.rotation.x, deg_to_rad(-30), deg_to_rad(60))
	player_head.rotation.y = clamp(player_head.rotation.y, deg_to_rad(-90), deg_to_rad(90))
