extends ProgressBar

class_name JuiceMeter

@export var player: PlayerController

@onready var timer: Timer = $Timer

var stop_juice_drop: bool = false

func _init_juice_meter() -> void:
	player.juice_changed.connect(update_juice)
	timer.timeout.connect(_on_timeout)
	update_juice()
	timer.start()

func update_juice():
	value = player.current_juice

func _on_timeout() -> void:
	player.current_juice -= 1
	update_juice()
	timer.start()
