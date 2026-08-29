extends Node

## The server-side table of one room: a MaumauEngine and four npc.tscn seats,
## no cats, no markers, no camera. Net instantiates one per room when the
## round starts and hands it its NetRoom before adding it to the tree.

@export var manager: MauMauGameManager

var room: NetRoom
