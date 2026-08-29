extends Node

## Autoload `Net`: the one multiplayer peer, the lobby roster and the
## lobby → round handoff. Four roles: offline (solo play, unchanged),
## dedicated server (headless, no human), host (a server that also plays
## a seat) and client. Everything that survives the scene change from the
## lobby to main_scene lives here — in particular the seating decision.

const DEFAULT_URL := "wss://meowmau.game.ozoromo.com"
const LOCAL_URL := "ws://127.0.0.1:9080"
## Caddy proxies the public endpoint to this port on localhost; never exposed.
const SERVER_PORT := 9080
const SERVER_PEER := 1
const MAX_SEATS := 4
const MAIN_SCENE_UID := "uid://be4pqwq2ycfn3"

enum Role { OFFLINE, DEDICATED, HOST, CLIENT }

signal peer_joined(id: int)
signal peer_left(id: int)
signal connected_to_server
signal connection_failed
signal server_disconnected
## The server decided the seating and every peer is loading main_scene.
signal round_starting(seat_peers: PackedInt32Array)

## Index = seat, value = peer id; 0 marks an NPC seat. Empty while offline.
## On a client: the seating of the one room it is in. On a server the seating
## lives on each NetRoom; this stays empty there.
var seat_peers: PackedInt32Array = []

#################ROOMS (phase 4b)########################
# One server process holds many rooms keyed by a short code. A client is in at
# most one room and knows only its code; a host has exactly one room (its own
# main_scene is that room's table); a dedicated server instantiates table.tscn
# per room under /root/Rooms/<code>.

const TABLE_SCENE_UID := "uid://di8ur8ivhm7ii"
const ROOM_CODE_LENGTH := 4
## Freed this long after round_over unless everyone left first.
const ROOM_LINGER := 60.0

## Entered a room (the code is the one to read out loud).
signal room_joined(code: String)
signal room_left
## A create/join/start request the server refused, with a reason for the lobby.
signal room_error(message: String)

## Server side: code → NetRoom.
var rooms: Dictionary = {}
## Client and host: the code of the room this peer is in; "" in no room.
var room_code: String = ""


## Client → server: join the room with this code, creating it when it does not
## exist. Answered by room_joined or room_error.
func join_room(code: String) -> void:
	pass


## Client → server: a fresh random code. Answered by room_joined.
func create_room() -> void:
	pass


## Leave the room but stay connected to the server.
func leave_room() -> void:
	pass


## Server: the room a peer is in, null if none.
func room_of_peer(peer: int) -> NetRoom:
	return null


## Server: called by a table's manager in its _ready to learn its room. On a
## dedicated server the room is the one whose table is being instantiated; on a
## host it is the host's single room.
func room_for_table(manager: MauMauGameManager) -> NetRoom:
	return null


## Client: NetSync registers itself so relayed table messages reach it.
func attach_sync(sync: MauMauNetSync) -> void:
	pass


# Relay. Godot addresses an RPC by node path and two rooms cannot share one, so
# every table message goes through these three instead of @rpc on the table.
# Methods: "table" [dict] · "hand" [ids] · "event" [name, args] · "client_ready" []
# (server ← client) · "submit_move" [card_id] · "submit_draw" [] · "submit_wish" [suit].

## Client → its room's table on the server.
func to_server(method: String, args: Array) -> void:
	pass


## Server → every peer in the room (never the server itself).
func to_room(room: NetRoom, method: String, args: Array) -> void:
	pass


## Server → one peer.
func to_peer(peer: int, method: String, args: Array) -> void:
	pass

var _role := Role.OFFLINE
var _roster: PackedInt32Array = []
var _round_running := false


func _ready() -> void:
	# The MultiplayerAPI outlives every peer swap, so these connect once.
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

	var args := OS.get_cmdline_user_args()
	if not (OS.has_feature("dedicated_server") or args.has("--server")):
		return
	var port := SERVER_PORT
	var bind := "127.0.0.1"
	for arg in args:
		if arg.begins_with("--port="):
			port = arg.trim_prefix("--port=").to_int()
		elif arg.begins_with("--bind="):
			bind = arg.trim_prefix("--bind=")
	var err := host(port, false, bind)
	if err != OK:
		printerr("Net: cannot listen on %s:%d (error %d)" % [bind, port, err])
		get_tree().quit(1)
		return
	print("Net: dedicated server listening on ws://%s:%d" % [bind, port])


func is_online() -> bool:
	return _role != Role.OFFLINE


## Dedicated server or host.
func is_server() -> bool:
	return _role == Role.DEDICATED or _role == Role.HOST


func is_dedicated() -> bool:
	return _role == Role.DEDICATED


func is_client() -> bool:
	return is_online() and not is_server()


## The seat this process plays; -1 offline (the manager then seats the
## human at 0 as before) and on a dedicated server.
func my_seat() -> int:
	if not is_online() or is_dedicated():
		return -1
	return seat_for_peer(multiplayer.get_unique_id())


## 0 for an NPC seat or an unknown seat.
func peer_for_seat(seat: int) -> int:
	return seat_peers[seat] if seat >= 0 and seat < seat_peers.size() else 0


func seat_for_peer(peer: int) -> int:
	return seat_peers.find(peer) if peer != 0 else -1


## Every human peer id, the host's own (1) included when it plays.
func peers() -> PackedInt32Array:
	return _roster.duplicate()


func host(port: int = SERVER_PORT, plays: bool = true, bind: String = "") -> Error:
	if is_online():
		leave()
	if bind.is_empty():
		# A lobby host serves the LAN; a dedicated server sits behind Caddy.
		bind = "*" if plays else "127.0.0.1"
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_server(port, bind)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_role = Role.HOST if plays else Role.DEDICATED
	_roster = PackedInt32Array([SERVER_PEER]) if plays else PackedInt32Array()
	return OK


func join(url: String = DEFAULT_URL) -> Error:
	if is_online():
		leave()
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_client(url)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	_role = Role.CLIENT
	_roster = PackedInt32Array()
	return OK


func leave() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer != null and not (peer is OfflineMultiplayerPeer):
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	_roster = PackedInt32Array()
	seat_peers = PackedInt32Array()
	_role = Role.OFFLINE
	_round_running = false


## Server only: shuffle the humans over the seats, tell every peer, load main_scene.
func start_round() -> void:
	if not is_server() or _round_running:
		return
	var humans := peers()
	var free_seats := range(MAX_SEATS)
	free_seats.shuffle()
	var seated := mini(humans.size(), MAX_SEATS)
	if humans.size() > seated:
		push_warning("Net: %d humans for %d seats, the rest sit out" % [humans.size(), MAX_SEATS])
	var seats := PackedInt32Array()
	seats.resize(MAX_SEATS)
	for i in seated:
		seats[free_seats[i]] = humans[i]
	_begin_round.rpc(seats)


## Client → server: ask for the round to start (a dedicated server has no host to press it).
func request_start() -> void:
	if is_server():
		start_round()
	elif is_client():
		_request_start.rpc_id(SERVER_PEER)


@rpc("any_peer", "call_remote", "reliable")
func _request_start() -> void:
	if is_server():
		start_round()


@rpc("authority", "call_local", "reliable")
func _begin_round(seats: PackedInt32Array) -> void:
	seat_peers = seats
	_round_running = true
	round_starting.emit(seat_peers)
	get_tree().change_scene_to_packed(load(MAIN_SCENE_UID))


# Clients learn about peers from the server's roster, not from the raw relay:
# that relay announces the server's own id 1 even when nobody plays it, and it
# arrives before the roster does, so a lobby drawing from peers() would lag.
@rpc("authority", "call_remote", "reliable")
func _sync_roster(ids: PackedInt32Array) -> void:
	var before := _roster
	_roster = ids
	for id in before:
		if not ids.has(id):
			peer_left.emit(id)
	for id in ids:
		if not before.has(id):
			peer_joined.emit(id)


func _on_peer_connected(id: int) -> void:
	if not is_server():
		return
	if not _roster.has(id):
		_roster.append(id)
	_sync_roster.rpc(_roster)
	peer_joined.emit(id)


func _on_peer_disconnected(id: int) -> void:
	if not is_server():
		return
	var at := _roster.find(id)
	if at != -1:
		_roster.remove_at(at)
	_sync_roster.rpc(_roster)
	peer_left.emit(id)


func _on_connected_to_server() -> void:
	connected_to_server.emit()


func _on_connection_failed() -> void:
	leave()
	connection_failed.emit()


func _on_server_disconnected() -> void:
	leave()
	server_disconnected.emit()
