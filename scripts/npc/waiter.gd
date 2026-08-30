extends CharacterBody3D

@export var nav_agent: NavigationAgent3D
@export var nav_mesh: NavigationRegion3D
@export var move_speed: float = 1.0
@export var model_rotation_offset_deg: float = -90.0
@export var animation_player: AnimationPlayer
@export var wait_time_at_target: float = 2.0

var target_pos: Vector3
var has_target: bool = false
var is_waiting: bool = false
var wait_timer: float = 0.0

func _physics_process(delta: float) -> void:
	if has_target:
		animation_player.play("Walk")
		nav_agent.target_position = target_pos
		var next_path_pos := nav_agent.get_next_path_position()
		var direction := global_position.direction_to(next_path_pos)
		velocity = direction * move_speed
		
		if nav_agent.is_navigation_finished():
			has_target = false
			velocity = Vector3.ZERO
			is_waiting = true
			wait_timer = wait_time_at_target
		
		var rotation_speed = 4
		var target_rotation := direction.signed_angle_to(Vector3.FORWARD, Vector3.DOWN) + deg_to_rad(model_rotation_offset_deg)
		var angle_diff := wrapf(target_rotation - rotation.y, -PI, PI)
		if abs(angle_diff) > deg_to_rad(60):
			rotation_speed = 20
		rotation.y += clampf(angle_diff, -delta * rotation_speed, delta * rotation_speed)
	elif is_waiting:
		animation_player.play("WaiterIdle")
		wait_timer -= delta
		if wait_timer <= 0.0:
			is_waiting = false
	else:
		has_target = true
		target_pos = NavigationServer3D.region_get_random_point(nav_mesh, 1, false)
	
	move_and_slide()
	
