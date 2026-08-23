extends RigidBody3D

class_name Npc

var hand:Array = []

func init_hands(first_hand: Array) -> void:
	self.hand = first_hand
	
