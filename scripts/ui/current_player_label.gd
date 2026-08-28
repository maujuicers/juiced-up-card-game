extends Control

class_name CurrentPlayerLabel

@export var label: Label

var manager: MauMauGameManager
var mau_mau_player: MauMauPlayer

func init_label(calling_player: MauMauPlayer, calling_player_manager: MauMauGameManager) -> void:
	self.mau_mau_player = calling_player
	self.manager = calling_player_manager
	manager.turn_changed.connect(show_current_player)

func show_current_player(player_index: int) -> void:
	if mau_mau_player.turn_position == player_index:
		label.text = "It's your turn!"
	else:
		label.text = "Current Player: %d" % player_index
