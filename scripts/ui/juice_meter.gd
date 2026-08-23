extends ProgressBar

@export var player: PlayerController

var stop_juice_drop: bool = false

func _ready() -> void:
	player.juice_changed.connect(update_juice)
	update_juice()

func update_juice():
	value = player.current_juice * 100 / player.max_juice
