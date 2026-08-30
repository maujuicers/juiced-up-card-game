extends Node3D

@export var path_follow: PathFollow3D
@export var move_speed: float = 1.0
@export var animation_player: AnimationPlayer

var wait: bool = false
var go: bool = true

func _physics_process(delta: float) -> void:
	if wait:
		return
	elif go:
		go = false
		animation_player.play("Walk")
		change_to_wait()
		path_follow.progress += move_speed * delta
	else:
		path_follow.progress += move_speed * delta

func change_to_wait() -> void:
	await get_tree().create_timer(15).timeout
	wait_on_path()

func wait_on_path() -> void:
	wait = true
	animation_player.play("WaiterIdle")
	await get_tree().create_timer(5).timeout
	wait = false
	go = true
