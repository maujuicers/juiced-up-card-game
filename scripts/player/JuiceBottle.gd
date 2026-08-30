class_name JuiceBottle extends Resource

## What a seat drinks from. Pure data: the sip loop is the seat's, because only
## the authority may run it and a Resource has no place in the scene tree.

@export var max_juice_content: int = 50
@export var current_juice_content: int = 50

## The amount actually taken; the last sip of a bottle is short.
func take_sip(amount: int) -> int:
	var sip: int = clampi(amount, 0, current_juice_content)
	current_juice_content -= sip
	return sip

func is_empty() -> bool:
	return current_juice_content < 1
