extends Control

@export var mau_mau_player: MauMauPlayer
@export var label: Label

func init_label() -> void:
	label.text = "Current Player: %d" % mau_mau_player.manager.current_player_index

func show_current_player(player_index: int) -> void:
	if mau_mau_player.turn_position == player_index:
		label.text = "It's your turn!"
	else:
		label.text = "Current Player: %d" % player_index
