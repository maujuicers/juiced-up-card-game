extends ProgressBar

class_name JuiceMeter

@export var juice: Juice

func _ready() -> void:
	juice.juice_changed.connect(update_value)
	value = juice.current_juice
	max_value = juice.max_juice

func update_value(current: int) -> void:
	value = current
