class_name JuiceBottle extends Resource

signal juice_empty
signal sip_taken(amount: int)

@export var max_juice_content: int = 50
@export var current_juice_content: int = 50

var drink_enabled: bool = false

func drink() -> void:
	if drink_enabled or is_empty():
		return
		
	drink_enabled = true
		
	while drink_enabled and not is_empty():
		await Engine.get_main_loop().create_timer(1.0).timeout
		
		if not drink_enabled:
			break
			
		current_juice_content -= 10
		sip_taken.emit(10)
		
		if is_empty():
			print("drink is empty")
			current_juice_content = 0 # Clamp to 0 to prevent negative values
			drink_enabled = false
			juice_empty.emit()
		
func stop_drinking() -> void:
	drink_enabled = false
	
func is_empty() -> bool:
	return current_juice_content < 1
