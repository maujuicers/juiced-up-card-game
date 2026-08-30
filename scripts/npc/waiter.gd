extends CharacterBody3D

class_name Waiter

## The bar's waiter. Wanders the room until a seat orders, then walks to the bar
## for a bottle and carries it to that seat. The delivery is what grants the
## bottle: the authority's [MauMauGameManager] listens to [signal delivered].

## The waiter reached the seat that ordered.
signal delivered(seat: int)

enum State { IDLE, TO_BAR, AT_BAR, TO_SEAT, AT_SEAT }

## An unreachable serve point must not strand an order for good.
const TRAVEL_TIMEOUT := 30.0

@export var nav_agent: NavigationAgent3D
@export var nav_mesh: NavigationRegion3D
@export var move_speed: float = 1.0
@export var model_rotation_offset_deg: float = -90.0
@export var wait_time_at_target: float = 2.0
## Where the bottles are picked up.
@export var bar_point: Node3D
@export_range(0.0, 10.0, 0.1, "suffix:s") var bar_wait_time: float = 2.0
## Where to stand to serve, in the seat marker's own frame: to the seat's right
## and behind the chair, which is the side the nav mesh leaves free.
@export var serve_offset := Vector3(0.85, 0.0, 0.6)

@export_group("Models")
@export var without_bottles: Node3D
@export var without_bottles_animation: AnimationPlayer
@export var with_bottles: Node3D
@export var with_bottles_animation: AnimationPlayer

var _state := State.IDLE
## Seats waiting to be served, in order.
var _orders: Array[int] = []
## Seat -> the SeatMarker its serve point is derived from.
var _markers: Dictionary = {}
var _travelled: float = 0.0
var _wait_timer: float = 0.0
var _idle_target: Vector3
var _has_idle_target: bool = false
var _animation: AnimationPlayer


func _ready() -> void:
	_carry_bottles(false)


## Queue a bottle for `seat`; `marker` is that seat's chair.
func order(seat: int, marker: Node3D) -> void:
	if has_order(seat):
		return
	_orders.append(seat)
	_markers[seat] = marker
	if _state == State.IDLE:
		_leave_for_bar()


func has_order(seat: int) -> bool:
	return _orders.has(seat)


func clear_orders() -> void:
	_orders.clear()
	_markers.clear()
	_carry_bottles(false)
	_go_idle()


func _physics_process(delta: float) -> void:
	# Paths only resolve once the navigation map has synced, a frame or two after
	# the scene loads; walking before that reports "arrived" on the first step.
	if not _map_ready():
		return
	match _state:
		State.IDLE:
			_wander(delta)
		State.TO_BAR:
			if _travel(delta):
				_stand_still(State.AT_BAR, bar_wait_time)
		State.AT_BAR:
			if _wait(delta):
				_carry_bottles(true)
				_leave_for_seat()
		State.TO_SEAT:
			if _travel(delta):
				if not _orders.is_empty():
					delivered.emit(_orders[0])
				_stand_still(State.AT_SEAT, wait_time_at_target)
		State.AT_SEAT:
			if _wait(delta):
				_carry_bottles(false)
				_finish_order()
	move_and_slide()


func _wander(delta: float) -> void:
	if _wait_timer > 0.0:
		_wait(delta)
		return
	if not _has_idle_target:
		var region := nav_mesh.get_rid() if nav_mesh != null else RID()
		if not region.is_valid():
			return
		_idle_target = NavigationServer3D.region_get_random_point(region, 1, false)
		_has_idle_target = true
		_set_destination(_idle_target)
	if _travel(delta):
		_has_idle_target = false
		_wait_timer = wait_time_at_target


func _leave_for_bar() -> void:
	if bar_point == null:
		_carry_bottles(true)
		_leave_for_seat()
		return
	_state = State.TO_BAR
	_set_destination(bar_point.global_position)


func _leave_for_seat() -> void:
	if _orders.is_empty():
		_go_idle()
		return
	_state = State.TO_SEAT
	_set_destination(_serve_point(_markers.get(_orders[0])))


func _finish_order() -> void:
	if not _orders.is_empty():
		_markers.erase(_orders.pop_front())
	if _orders.is_empty():
		_go_idle()
	else:
		_leave_for_bar()


func _go_idle() -> void:
	_state = State.IDLE
	_has_idle_target = false
	_wait_timer = 0.0
	velocity = Vector3.ZERO


func _stand_still(next: State, seconds: float) -> void:
	_state = next
	_wait_timer = seconds
	velocity = Vector3.ZERO


## The floor beside `marker`, snapped onto the nav mesh: the chairs and the table
## are baked into it, so the offset alone would often name a spot inside them.
func _serve_point(marker: Node3D) -> Vector3:
	if marker == null:
		return global_position
	var wanted: Vector3 = marker.global_transform * serve_offset
	var map := nav_agent.get_navigation_map() if nav_agent != null else RID()
	if not map.is_valid():
		return wanted
	return NavigationServer3D.map_get_closest_point(map, wanted)


func _map_ready() -> bool:
	if nav_agent == null:
		return false
	var map := nav_agent.get_navigation_map()
	return map.is_valid() and NavigationServer3D.map_get_iteration_id(map) > 0


func _set_destination(target: Vector3) -> void:
	_travelled = 0.0
	if nav_agent != null:
		nav_agent.target_position = target


## Walks one step towards the current destination; true once it is reached.
func _travel(delta: float) -> bool:
	_play("Walk")
	_travelled += delta
	var next_path_pos := nav_agent.get_next_path_position()
	var direction := global_position.direction_to(next_path_pos)
	velocity = direction * move_speed

	if direction.length_squared() > 0.0:
		var rotation_speed := 4.0
		var target_rotation := direction.signed_angle_to(Vector3.FORWARD, Vector3.DOWN) + deg_to_rad(model_rotation_offset_deg)
		var angle_diff := wrapf(target_rotation - rotation.y, -PI, PI)
		if absf(angle_diff) > deg_to_rad(60):
			rotation_speed = 20.0
		rotation.y += clampf(angle_diff, -delta * rotation_speed, delta * rotation_speed)

	if nav_agent.is_navigation_finished() or _travelled > TRAVEL_TIMEOUT:
		velocity = Vector3.ZERO
		return true
	return false


## Counts the pause down; true on the frame it ends.
func _wait(delta: float) -> bool:
	_play("WaiterIdle")
	velocity = Vector3.ZERO
	_wait_timer -= delta
	return _wait_timer <= 0.0


func _carry_bottles(on: bool) -> void:
	if with_bottles != null:
		with_bottles.visible = on
	if without_bottles != null:
		without_bottles.visible = not on
	_animation = with_bottles_animation if on else without_bottles_animation


func _play(animation: String) -> void:
	if _animation != null and _animation.current_animation != animation:
		_animation.play(animation)
