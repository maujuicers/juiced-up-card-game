extends Node

class_name Juice

@export var max_juice: int = 100
@export var current_juice: int = 0
var drain_enabled: bool = true

@onready var timer: Timer = $Timer

signal juice_changed(current: int)
signal juice_empty

func _ready() -> void:
	timer.timeout.connect(_on_timeout)
	timer.start()

func set_juice(amount: int) -> void:
	current_juice = clamp(amount, 0, max_juice)
	juice_changed.emit(current_juice)
	if current_juice < 1:
		timer.stop()
		juice_empty.emit()

func reset() -> void:
	set_juice(max_juice)
	timer.start()

func _on_timeout() -> void:
	if not drain_enabled:
		return
	set_juice(current_juice - 1)
	
func deduct_juice(amount: int) -> void:
	current_juice -= amount
