extends ProgressBar

class_name JuiceMeter

const FULL_COLOR := Color(0.25, 0.78, 0.28)
const MID_COLOR := Color(0.95, 0.78, 0.15)
const EMPTY_COLOR := Color(0.85, 0.16, 0.13)
const FLASH_COLOR := Color(1.0, 0.18, 0.14)

const SHAKE_DURATION := 0.4
const SHAKE_AMPLITUDE := 6.0
const SHAKE_OSCILLATIONS := 2.5

@export var juice: Juice

@onready var flash_border: Panel = $FlashBorder

var _fill_style: StyleBoxFlat
var _shake_tween: Tween
var _rest_position: Vector2

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_styles()
	juice.juice_changed.connect(update_value)
	juice.juice_insufficient.connect(_on_juice_insufficient)
	max_value = juice.max_juice
	update_value(juice.current_juice)

func update_value(current: int) -> void:
	value = current
	_fill_style.bg_color = _ramp_color(value / max_value if max_value > 0.0 else 0.0)

func _build_styles() -> void:
	var background := StyleBoxFlat.new()
	background.bg_color = Color(0.05, 0.05, 0.07, 0.85)
	background.border_color = Color(0.0, 0.0, 0.0, 0.6)
	background.set_border_width_all(1)
	background.set_corner_radius_all(4)
	add_theme_stylebox_override("background", background)

	_fill_style = StyleBoxFlat.new()
	_fill_style.bg_color = FULL_COLOR
	_fill_style.set_corner_radius_all(4)
	add_theme_stylebox_override("fill", _fill_style)

	# The label sits over both the fill and the dark rest of the bar.
	add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
	add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.8))
	add_theme_constant_override("outline_size", 4)

	var flash := StyleBoxFlat.new()
	flash.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	flash.border_color = FLASH_COLOR
	flash.set_border_width_all(2)
	flash.set_corner_radius_all(4)
	flash_border.add_theme_stylebox_override("panel", flash)
	flash_border.modulate.a = 0.0

func _ramp_color(ratio: float) -> Color:
	var t := clampf(ratio, 0.0, 1.0)
	if t < 0.5:
		return EMPTY_COLOR.lerp(MID_COLOR, t / 0.5)
	return MID_COLOR.lerp(FULL_COLOR, (t - 0.5) / 0.5)

func _on_juice_insufficient(_amount: int) -> void:
	# A retrigger must not treat the mid-shake offset as the resting place.
	if _shake_tween != null and _shake_tween.is_valid():
		_shake_tween.kill()
		position = _rest_position
	_rest_position = position

	_shake_tween = create_tween()
	_shake_tween.set_parallel(true)
	_shake_tween.tween_method(_apply_shake, 0.0, 1.0, SHAKE_DURATION)
	_shake_tween.tween_property(flash_border, "modulate:a", 0.0, SHAKE_DURATION) \
		.from(1.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_shake_tween.finished.connect(_settle)

func _apply_shake(t: float) -> void:
	# Leftwards only: the bar rests flush against the right screen edge, so a
	# symmetric shake would push its border off-screen.
	var offset := -absf(sin(t * TAU * SHAKE_OSCILLATIONS)) * SHAKE_AMPLITUDE * (1.0 - t)
	position = _rest_position + Vector2(offset, 0.0)

func _settle() -> void:
	position = _rest_position
	flash_border.modulate.a = 0.0
