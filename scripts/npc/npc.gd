extends Node3D

class_name Npc

@export var maumau_player: MauMauPlayer
@export var neutral_meow_sfx_list: Array[AudioStream]

func _ready() -> void:
	maumau_player.neutral_meow_sfx_list = neutral_meow_sfx_list
