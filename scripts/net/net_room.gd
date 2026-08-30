class_name NetRoom
extends RefCounted

## One lobby-and-table on a server: its code, who is in it, the seating the
## server decided, and the table node once a round runs. On a host the table
## is the host's own main_scene; on a dedicated server it is a table.tscn
## under /root/Rooms. Clients never hold one — they know only their code.

enum State { LOBBY, PLAYING, OVER }

signal peer_joined(id: int)
signal peer_left(id: int)

var code: String
var peers: PackedInt32Array = []
## Index = seat, value = peer id; 0 marks an NPC seat. Empty until the round starts.
var seat_peers: PackedInt32Array = []
var state := State.LOBBY
## Root of the table scene (dedicated) or of main_scene (host); null in the lobby.
var table: Node
var manager: MauMauGameManager
var sync: MauMauNetSync


func has_peer(id: int) -> bool:
	return peers.has(id)


func seat_for_peer(peer: int) -> int:
	return seat_peers.find(peer) if peer != 0 else -1


func peer_for_seat(seat: int) -> int:
	return seat_peers[seat] if seat >= 0 and seat < seat_peers.size() else 0
