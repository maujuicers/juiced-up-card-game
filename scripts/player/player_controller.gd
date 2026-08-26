extends Node3D

class_name PlayerController

@export var player_camera: Camera3D
@export var player_head: Node3D
@export var juice: Juice
@export var maumau_player: MauMauPlayer

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		if event is InputEventMouseMotion:
			player_head.rotate_y(-event.relative.x * 0.01)
			player_camera.rotate_x(-event.relative.y * 0.01)
			player_camera.rotation.x = clamp(player_camera.rotation.x, deg_to_rad(-30), deg_to_rad(60))
			player_head.rotation.y = clamp(player_head.rotation.y, deg_to_rad(-90), deg_to_rad(90))
