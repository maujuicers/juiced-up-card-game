extends Node3D

class_name  CurrentPlayerArrow

var mau_mau_player: MauMauPlayer
var manager: MauMauGameManager
@export var arrow_mesh: MeshInstance3D

func init_player_arrow(calling_player: MauMauPlayer, calling_player_manager: MauMauGameManager) -> void:
	self.mau_mau_player = calling_player
	self.manager = calling_player_manager
	manager.turn_changed.connect(show_current_player_arrow)
	self.hide()

func show_current_player_arrow(player_index: int) -> void:
	if mau_mau_player.turn_position == player_index:
		self.show()
	else:
		self.hide()
