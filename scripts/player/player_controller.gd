extends Node3D

class_name PlayerController

## Radians of view rotation per pixel of mouse motion. The editor value is the
## fallback; _ready overwrites it with the saved Mouse Sensitivity setting, and
## MainScene keeps it in step with the settings slider while the game runs.
@export var look_sensitivity := 0.01

@export var player_camera: Camera3D
@export var player_head: Node3D
@export var juice: Juice
@export var maumau_player: MauMauPlayer

## True while gameplay owns the mouse: the cursor is captured and mouse motion
## turns the head. MainScene is the single owner of this flag -- it turns looking
## off for as long as the pause or settings menu is up -- so nothing else may
## touch Input.set_mouse_mode() while the gameplay scene is running.
var _look_enabled := false

func _ready() -> void:
	set_look_sensitivity(SettingsMenu.load_mouse_sensitivity())
	set_look_enabled(true)

func set_look_sensitivity(value: float) -> void:
	look_sensitivity = value

## Captures (or releases) the mouse and gates _rotate_view accordingly.
func set_look_enabled(enabled: bool) -> void:
	_look_enabled = enabled
	if enabled:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

## Only mouse motion is consumed here; clicks are left alone so Hand can use
## them to pick the card under the screen centre.
func _unhandled_input(event: InputEvent) -> void:
	if _look_enabled and event is InputEventMouseMotion:
		_rotate_view(event.relative)

func _rotate_view(relative: Vector2) -> void:
	player_head.rotate_y(-relative.x * look_sensitivity)
	player_camera.rotate_x(-relative.y * look_sensitivity)
	player_camera.rotation.x = clamp(player_camera.rotation.x, deg_to_rad(-30), deg_to_rad(60))
	player_head.rotation.y = clamp(player_head.rotation.y, deg_to_rad(-90), deg_to_rad(90))
