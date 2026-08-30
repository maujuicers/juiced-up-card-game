extends ColorRect

## Maps this seat's juice level onto the drunk-effect shader in quarter-steps.
## The curve is back-loaded: the first threshold barely does anything, and
## the effect ramps up hard toward the last one.
##
## juice 0–25%   -> no effect
## juice 25–50%  -> very light effect
## juice 50–75%  -> moderate effect
## juice 75–100% -> full effect (max strength)

@export var juice: Juice

const BLUR_MAX := 1.5
const WOBBLE_STRENGTH_MAX := 0.025
const WOBBLE_SPEED_MAX := 2.0
const CHROMATIC_ABERRATION_MAX := 0.008

## Ratio applied at each step (0 = sober, 3 = fully drunk).
## Tweak these directly to reshape the curve — they don't have to be even.
const STEP_RATIOS: Array[float] = [0.0, 0.2, 0.6, 1.0]

var _current_step := -1 # forces the first update to actually apply

func _ready() -> void:
	if juice != null:
		juice.juice_changed.connect(_on_juice_changed)
		_on_juice_changed(juice.current_juice)

func _on_juice_changed(current: int) -> void:
	if juice == null or juice.max_juice <= 0:
		return

	var step := _quarter_step(current)
	if step == _current_step:
		return # same bracket as before, skip the redundant param update
	_current_step = step

	var ratio := STEP_RATIOS[step]
	var mat := material as ShaderMaterial
	if mat == null:
		return

	mat.set_shader_parameter("blur_amount", ratio * BLUR_MAX)
	mat.set_shader_parameter("wobble_strength", ratio * WOBBLE_STRENGTH_MAX)
	mat.set_shader_parameter("wobble_speed", ratio * WOBBLE_SPEED_MAX)
	mat.set_shader_parameter("chromatic_aberration", ratio * CHROMATIC_ABERRATION_MAX)

## Returns which quarter-bracket current juice falls into: 0, 1, 2, or 3.
func _quarter_step(current: int) -> int:
	var q := float(juice.max_juice) / 4.0
	if current <= q:
		return 0
	elif current <= q * 2:
		return 1
	elif current <= q * 3:
		return 2
	else:
		return 3
