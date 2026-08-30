extends Node3D

class_name PlayerController

## The look limits, in radians. Shared with the head-look sync, which clamps what
## arrives from the wire to the same range a local mouse could have produced.
const MIN_PITCH := -PI / 6.0
const MAX_PITCH := PI / 3.0
const YAW_LIMIT := PI / 2.0

## Radians per pixel. Fallback only: _ready loads the saved setting.
@export var look_sensitivity := 0.01

@export var player_camera: Camera3D
@export var player_head: Node3D
@export var maumau_player: MauMauPlayer
@export var crosshair: Control

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

## Head yaw and camera pitch, in radians — the whole of what HeadSync ships.
func look_angles() -> Vector2:
	return Vector2(player_head.rotation.y, player_camera.rotation.x)

# So we can capture the mouse in the browser builds as well
func _input(event: InputEvent) -> void:
	if not _look_enabled or Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		return
	if (event is InputEventMouseButton or event is InputEventKey) and event.is_pressed():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
		if event is InputEventMouseButton:
			get_viewport().set_input_as_handled()

# Clicks are left for Hand.
func _unhandled_input(event: InputEvent) -> void:
	if _look_enabled and event is InputEventMouseMotion:
		_rotate_view(event.relative)
	if maumau_player == null:
		return
	if event.is_action_pressed("drink"):
		maumau_player.drink()
	elif event.is_action_released("drink"):
		maumau_player.stop_drinking()
	elif event.is_action_pressed("call_waiter"):
		maumau_player.call_waiter()

func _rotate_view(relative: Vector2) -> void:
	player_head.rotate_y(-relative.x * look_sensitivity)
	player_camera.rotate_x(-relative.y * look_sensitivity)
	player_camera.rotation.x = clampf(player_camera.rotation.x, MIN_PITCH, MAX_PITCH)
	player_head.rotation.y = clampf(player_head.rotation.y, -YAW_LIMIT, YAW_LIMIT)
