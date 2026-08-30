class_name NetTable
extends Node

## The server-side table of one room: a MaumauEngine, four npc.tscn seats and
## the bare walkable world the waiter needs (nav mesh, bar point, seat markers) —
## no cats, no scenery, no camera. Net instantiates one per room when the round
## starts and hands it its NetRoom before adding it to the tree.

@export var manager: MauMauGameManager

var room: NetRoom
