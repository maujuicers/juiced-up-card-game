extends Node3D

class_name PlayerController

const LOOK_SENSITIVITY := 0.01

@export var player_camera: Camera3D
@export var player_head: Node3D
@export var juice: Juice
@export var maumau_player: MauMauPlayer

## True while the "look" button is held; only then does mouse motion turn the head.
var _looking := false
## Cursor position (viewport space) at the moment the look started.
var _cursor_position := Vector2.ZERO

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("look"):
		_start_look()
	elif event.is_action_released("look") or event.is_action_pressed("ui_cancel"):
		_stop_look()
	elif _looking and event is InputEventMouseMotion:
		_rotate_view(event.relative)

func _start_look() -> void:
	if _looking:
		return
	_cursor_position = get_viewport().get_mouse_position()
	_looking = true
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

## Ends the look and puts the cursor back where it was grabbed, so it does not
## jump to the screen centre. Also runs on "ui_cancel", which is what the pause
## menu opens on: the menu always comes up with a free, visible cursor.
func _stop_look() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if not _looking:
		return
	_looking = false
	get_viewport().warp_mouse(_cursor_position)

func _rotate_view(relative: Vector2) -> void:
	player_head.rotate_y(-relative.x * LOOK_SENSITIVITY)
	player_camera.rotate_x(-relative.y * LOOK_SENSITIVITY)
	player_camera.rotation.x = clamp(player_camera.rotation.x, deg_to_rad(-30), deg_to_rad(60))
	player_head.rotation.y = clamp(player_head.rotation.y, deg_to_rad(-90), deg_to_rad(90))
