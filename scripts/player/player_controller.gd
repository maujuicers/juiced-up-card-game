extends Node3D

class_name PlayerController

## The look limits, in radians. Shared with the head-look sync, which clamps what
## arrives from the wire to the same range a local mouse could have produced.
const MIN_PITCH := -PI / 6.0
const MAX_PITCH := PI / 3.0
const YAW_LIMIT := PI / 2.0

const DRINK_ENTER_TIME := 0.35
const DRINK_EXIT_TIME := 0.3
## How far below its resting place the bottle starts, so it rises into frame.
const DRINK_BOTTLE_RISE := 0.35

## Radians per pixel. Fallback only: _ready loads the saved setting.
@export var look_sensitivity := 0.01

@export var player_camera: Camera3D
@export var player_head: Node3D
@export var maumau_player: MauMauPlayer
@export var crosshair: Control
## The bottle held to the mouth while drinking. Hidden the rest of the time.
@export var drink_bottle: Node3D

## MainScene owns this (menus release the mouse); nothing else may call
## Input.set_mouse_mode() during gameplay.
var _look_enabled := false

var _drinking := false
## True for the whole of both tweens as well, so a look that is on its way back
## is never fought over with the mouse.
var _view_locked := false
var _view_tween: Tween
var _look_before_drink := Vector2.ZERO
var _bottle_rest := Vector3.ZERO

func _ready() -> void:
	set_look_sensitivity(SettingsMenu.load_mouse_sensitivity())
	set_look_enabled(true)
	if drink_bottle != null:
		_bottle_rest = drink_bottle.position
		drink_bottle.visible = false
	if maumau_player != null:
		maumau_player.bottle_changed.connect(_on_bottle_changed)
		if maumau_player.juice != null:
			maumau_player.juice.juice_changed.connect(_on_juice_changed)

func set_look_sensitivity(value: float) -> void:
	look_sensitivity = value

func set_look_enabled(enabled: bool) -> void:
	_look_enabled = enabled
	if enabled:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		if _drinking:
			# A menu eats the button release, so the sip loop would never stop.
			if maumau_player != null:
				maumau_player.stop_drinking()
			_exit_drink_view()

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
		if _can_drink():
			_enter_drink_view()
	elif event.is_action_released("drink"):
		maumau_player.stop_drinking()
		_exit_drink_view()
	elif event.is_action_pressed("call_waiter"):
		maumau_player.call_waiter()

func _rotate_view(relative: Vector2) -> void:
	if _view_locked:
		return
	player_head.rotate_y(-relative.x * look_sensitivity)
	player_camera.rotate_x(-relative.y * look_sensitivity)
	player_camera.rotation.x = clampf(player_camera.rotation.x, MIN_PITCH, MAX_PITCH)
	player_head.rotation.y = clampf(player_head.rotation.y, -YAW_LIMIT, YAW_LIMIT)


#################DRINK VIEW########################
# Bottle to the mouth: the look is taken over for as long as the sip lasts. The
# preconditions mirror MauMauPlayer.begin_drinking(), which is what the authority
# actually tests — mirrored onto every peer, so a client reads the same answer.


func is_drinking_view() -> bool:
	return _drinking


func _can_drink() -> bool:
	if maumau_player == null or maumau_player.bottle_content() <= 0:
		return false
	var juice := maumau_player.juice
	return juice != null and juice.current_juice < juice.max_juice


func _enter_drink_view() -> void:
	if _drinking:
		return
	_drinking = true
	_view_locked = true
	_look_before_drink = look_angles()
	if crosshair != null:
		crosshair.visible = false
	_view_tween = _fresh_tween()
	_view_tween.tween_property(player_head, "rotation:y", 0.0, DRINK_ENTER_TIME)
	_view_tween.parallel().tween_property(player_camera, "rotation:x", MAX_PITCH, DRINK_ENTER_TIME)
	if drink_bottle != null:
		drink_bottle.position = _bottle_rest - Vector3(0.0, DRINK_BOTTLE_RISE, 0.0)
		drink_bottle.visible = true
		_view_tween.parallel().tween_property(drink_bottle, "position", _bottle_rest, DRINK_ENTER_TIME)


func _exit_drink_view() -> void:
	if not _drinking:
		return
	_drinking = false
	_view_tween = _fresh_tween()
	_view_tween.tween_property(player_head, "rotation:y", _look_before_drink.x, DRINK_EXIT_TIME)
	_view_tween.parallel().tween_property(player_camera, "rotation:x", _look_before_drink.y, DRINK_EXIT_TIME)
	if drink_bottle != null:
		_view_tween.parallel().tween_property(
			drink_bottle, "position", _bottle_rest - Vector3(0.0, DRINK_BOTTLE_RISE, 0.0), DRINK_EXIT_TIME
		)
	_view_tween.finished.connect(_on_return_finished)


func _fresh_tween() -> Tween:
	if _view_tween != null and _view_tween.is_valid():
		_view_tween.kill()
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	return tween


func _on_return_finished() -> void:
	# A new sip may have started while the look was on its way back.
	if _drinking:
		return
	_view_locked = false
	if drink_bottle != null:
		drink_bottle.visible = false
	if crosshair != null:
		crosshair.visible = true


func _on_bottle_changed(content: int) -> void:
	if content <= 0:
		_exit_drink_view()


func _on_juice_changed(current: int) -> void:
	if maumau_player.juice != null and current >= maumau_player.juice.max_juice:
		_exit_drink_view()
