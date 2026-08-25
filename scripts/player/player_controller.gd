extends CharacterBody3D

class_name PlayerController

@export var player_camera: Camera3D
@export var player_head: Node3D
@export var max_juice: int = 100
@export var juice_meter: JuiceMeter
@export var maumau_player: MauMauPlayer

@onready var current_juice: int = max_juice

signal juice_changed

const SPEED = 5.0

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

func _ready() -> void:
	juice_meter._init_juice_meter()

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
			

func _physics_process(delta: float) -> void:
	# Add gravity
	if not is_on_floor():
		velocity.y -= gravity * delta
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir := Input.get_vector("left", "right", "forward", "backward")
	var direction = (player_head.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = direction.x * SPEED
		velocity.z = direction.z * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)
		velocity.z = move_toward(velocity.z, 0, SPEED)

	move_and_slide()
	
