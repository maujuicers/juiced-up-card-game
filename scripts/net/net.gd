extends Node

## Autoload `Net`: the one multiplayer peer, the rooms a server holds and the
## lobby → round handoff. Four roles: offline (solo play, unchanged), dedicated
## server (headless, no human), host (a server that also plays a seat) and
## client. Everything that survives the scene change from the lobby to
## main_scene lives here — in particular the seating decision.
##
## One server process holds many rooms keyed by a short code; a peer is in at
## most one. A host has exactly one room whose table is its own main_scene; a
## dedicated server instantiates table.tscn per room under /root/Rooms/<code>.

const DEFAULT_URL := "wss://meowmau.game.ozoromo.com"
const LOCAL_URL := "ws://127.0.0.1:9080"
## Caddy proxies the public endpoint to this port on localhost; never exposed.
const SERVER_PORT := 9080
const SERVER_PEER := 1
## A plain-HTTP liveness endpoint beside the game port: GET /healthz answers
## "ok" from _process, so a hung server stops answering and its container is restarted.
const HEALTH_PORT := 9081
const MAX_SEATS := 4
const MAIN_SCENE_UID := "uid://be4pqwq2ycfn3"
const TABLE_SCENE_UID := "uid://di8ur8ivhm7ii"
const ROOM_CODE_LENGTH := 4
## A code is read out loud and typed back, so no 0/O and no 1/I.
const ROOM_CODE_ALPHABET := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
## Longer than any code this server hands out, but a client may name its own.
const ROOM_CODE_MAX_LENGTH := 8
## Freed this long after round_over unless everyone left first.
const ROOM_LINGER := 60.0
## Holds one child per room on a dedicated server.
const ROOMS_ROOT := "Rooms"

enum Role { OFFLINE, DEDICATED, HOST, CLIENT }

## Scoped to my room on a client and on a host. On a dedicated server these stay
## raw connections; the room-scoped versions there are NetRoom.peer_joined/left.
signal peer_joined(id: int)
signal peer_left(id: int)
signal connected_to_server
signal connection_failed
signal server_disconnected
## The server decided the seating and every peer is loading main_scene.
signal round_starting(seat_peers: PackedInt32Array)
## Entered a room (the code is the one to read out loud).
signal room_joined(code: String)
signal room_left
## A create/join/start request the server refused, with a reason for the lobby.
signal room_error(message: String)

## Index = seat, value = peer id; 0 marks an NPC seat. Empty while offline.
## On a client and a host: the seating of the one room this peer is in. On a
## dedicated server the seating lives on each NetRoom; this stays empty there.
var seat_peers: PackedInt32Array = []

## Server side: code → NetRoom.
var rooms: Dictionary = {}
## Client and host: the code of the room this peer is in; "" in no room.
var room_code: String = ""

var _role := Role.OFFLINE
var _health: TCPServer
## Client: the server address without a path; a room is joined on "<base>/ws/<CODE>"
## so a load balancer hashing on the URI keeps one room on one instance.
var _base_url := ""
var _connected_url := ""
## Client: the room to ask for once the room-affine connection is up.
var _pending_room := ""
var _roster: PackedInt32Array = []
## Client side: the NetSync of the table scene, if one is loaded.
var _sync: MauMauNetSync


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
	var health_port := HEALTH_PORT
	for arg in args:
		if arg.begins_with("--port="):
			port = arg.trim_prefix("--port=").to_int()
		elif arg.begins_with("--bind="):
			bind = arg.trim_prefix("--bind=")
		elif arg.begins_with("--health-port="):
			health_port = arg.trim_prefix("--health-port=").to_int()
	var err := host(port, false, bind)
	if err != OK:
		printerr("Net: cannot listen on %s:%d (error %d)" % [bind, port, err])
		get_tree().quit(1)
		return
	print("Net: dedicated server listening on ws://%s:%d" % [bind, port])
	if health_port > 0:
		_health = TCPServer.new()
		if _health.listen(health_port, bind) == OK:
			print("Net: health endpoint on http://%s:%d/healthz" % [bind, health_port])
		else:
			printerr("Net: cannot listen for health checks on %s:%d" % [bind, health_port])
			_health = null


func _process(_delta: float) -> void:
	if _health == null:
		return
	while _health.is_connection_available():
		var probe := _health.take_connection()
		probe.get_data(probe.get_available_bytes())
		probe.put_data("HTTP/1.1 200 OK\r\nContent-Type: text/plain\r\nContent-Length: 2\r\nConnection: close\r\n\r\nok".to_utf8_buffer())
		probe.disconnect_from_host()


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


## Every human peer in my room, the host's own (1) included when it plays.
## On a dedicated server: every connected peer, room or no room.
func peers() -> PackedInt32Array:
	if _role == Role.HOST:
		var room := _my_room()
		return room.peers.duplicate() if room != null else PackedInt32Array()
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
	_roster = PackedInt32Array()
	if plays:
		var room := _make_room(_fresh_code())
		_add_peer_to_room(room, SERVER_PEER)
	return OK


func join(url: String = DEFAULT_URL) -> Error:
	if is_online():
		leave()
	_base_url = _base_of(url)
	return _connect(_base_url + "/ws")


## Reconnects when the room-affine path differs; the swap replaces the peer
## outright so no server_disconnected fires for a connection we chose to drop.
func _connect(url: String) -> Error:
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_client(url)
	if err != OK:
		return err
	var old := multiplayer.multiplayer_peer
	if old != null and not (old is OfflineMultiplayerPeer):
		old.close()
	multiplayer.multiplayer_peer = peer
	_connected_url = url
	_role = Role.CLIENT
	_roster = PackedInt32Array()
	return OK


static func _base_of(url: String) -> String:
	var trimmed := url.strip_edges()
	var scheme_end := trimmed.find("://")
	var host_start := scheme_end + 3 if scheme_end != -1 else 0
	var path_start := trimmed.find("/", host_start)
	return trimmed.substr(0, path_start) if path_start != -1 else trimmed


func _join_room_over_wire(code: String) -> void:
	var wanted := code.strip_edges().to_upper()
	var url := "%s/ws/%s" % [_base_url, wanted]
	if url == _connected_url:
		_rpc_join_room.rpc_id(SERVER_PEER, wanted)
		return
	_pending_room = wanted
	room_code = ""
	seat_peers = PackedInt32Array()
	if _connect(url) != OK:
		_pending_room = ""
		room_error.emit("Could not reach %s" % url)


func leave() -> void:
	var peer := multiplayer.multiplayer_peer
	if peer != null and not (peer is OfflineMultiplayerPeer):
		peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	for room in rooms.values():
		_free_room_nodes(room)
	rooms.clear()
	room_code = ""
	_roster = PackedInt32Array()
	seat_peers = PackedInt32Array()
	_role = Role.OFFLINE
	_pending_room = ""
	_connected_url = ""


#################ROOMS########################


## Client → server: join the room with this code, creating it when it does not
## exist. Answered by room_joined or room_error.
func join_room(code: String) -> void:
	if is_server():
		_join_room_for(SERVER_PEER, code)
	elif is_client():
		_join_room_over_wire(code)
	else:
		room_error.emit("Not connected to a server")


## Client → server: a fresh random code. Answered by room_joined.
func create_room() -> void:
	if is_server():
		# A host has one room and it already exists; a fresh code would only
		# invalidate the one it is showing.
		_join_room_for(SERVER_PEER, room_code if not room_code.is_empty() else _fresh_code())
	elif is_client():
		# Minted here, not on the server: the code picks the instance to connect to.
		_join_room_over_wire(_fresh_code())
	else:
		room_error.emit("Not connected to a server")


## Leave the room but stay connected to the server.
func leave_room() -> void:
	if room_code.is_empty():
		return
	if is_server():
		_remove_peer_from_room(SERVER_PEER)
		return
	_rpc_leave_room.rpc_id(SERVER_PEER)
	room_code = ""
	_roster = PackedInt32Array()
	seat_peers = PackedInt32Array()
	room_left.emit()


## Server: the room a peer is in, null if none.
func room_of_peer(peer: int) -> NetRoom:
	for value in rooms.values():
		var room: NetRoom = value
		if room.has_peer(peer):
			return room
	return null


## Server: called by a table's manager in its _ready to learn its room. On a
## dedicated server the room is the one whose table is being instantiated; on a
## host it is the host's single room.
func room_for_table(manager: MauMauGameManager) -> NetRoom:
	if manager.room != null:
		return manager.room
	if _role != Role.HOST:
		return null
	var room := _my_room()
	if room == null:
		return null
	room.table = manager.get_tree().current_scene
	room.manager = manager
	room.sync = manager.net_sync
	_watch_round(room)
	return room


## Client: NetSync registers itself so relayed table messages reach it.
func attach_sync(sync: MauMauNetSync) -> void:
	_sync = sync
	sync.tree_exited.connect(func() -> void:
		if _sync == sync:
			_sync = null)


func _my_room() -> NetRoom:
	var room: NetRoom = rooms.get(room_code)
	return room


func _make_room(code: String) -> NetRoom:
	var room := NetRoom.new()
	room.code = code
	rooms[code] = room
	return room


func _fresh_code() -> String:
	while true:
		var code := ""
		for i in ROOM_CODE_LENGTH:
			code += ROOM_CODE_ALPHABET[randi() % ROOM_CODE_ALPHABET.length()]
		if not rooms.has(code):
			return code
	return ""


## Server: put `peer` in `code`, creating the room when it is new. A host has
## exactly one room, so every request lands in that one whatever code was asked.
func _join_room_for(peer: int, code: String) -> void:
	var wanted := code.strip_edges().to_upper()
	if _role == Role.HOST:
		var mine := _my_room()
		wanted = mine.code if mine != null else wanted
	if wanted.is_empty() or wanted.length() > ROOM_CODE_MAX_LENGTH:
		_refuse(peer, "That is not a room code")
		return
	var room: NetRoom = rooms.get(wanted)
	if room != null and room.has_peer(peer):
		_announce_room(peer, room)
		return
	if room != null and room.state != NetRoom.State.LOBBY:
		_refuse(peer, "Room %s has already started" % wanted)
		return
	if room != null and room.peers.size() >= MAX_SEATS:
		_refuse(peer, "Room %s is full" % wanted)
		return
	_remove_peer_from_room(peer)
	if room == null:
		room = _make_room(wanted)
	_add_peer_to_room(room, peer)


func _add_peer_to_room(room: NetRoom, peer: int) -> void:
	room.peers.append(peer)
	_announce_room(peer, room)
	_send_roster(room)
	room.peer_joined.emit(peer)
	if _role == Role.HOST:
		peer_joined.emit(peer)


func _announce_room(peer: int, room: NetRoom) -> void:
	if peer == SERVER_PEER:
		room_code = room.code
		room_joined.emit(room.code)
		return
	_rpc_room_joined.rpc_id(peer, room.code)


func _refuse(peer: int, message: String) -> void:
	if peer == SERVER_PEER:
		room_error.emit(message)
		return
	_rpc_room_error.rpc_id(peer, message)


func _remove_peer_from_room(peer: int) -> void:
	var room := room_of_peer(peer)
	if room == null:
		return
	var at := room.peers.find(peer)
	if at != -1:
		room.peers.remove_at(at)
	if peer == SERVER_PEER:
		room_code = ""
		seat_peers = PackedInt32Array()
		room_left.emit()
	room.peer_left.emit(peer)
	if _role == Role.HOST:
		peer_left.emit(peer)
	if room.peers.is_empty():
		_free_room(room)
		return
	_send_roster(room)


func _send_roster(room: NetRoom) -> void:
	for peer in room.peers:
		if peer != SERVER_PEER:
			_rpc_roster.rpc_id(peer, room.peers)


func _free_room(room: NetRoom) -> void:
	rooms.erase(room.code)
	for peer in room.peers:
		if peer != SERVER_PEER:
			_rpc_room_left.rpc_id(peer)
	room.peers = PackedInt32Array()
	if room_code == room.code:
		room_code = ""
		seat_peers = PackedInt32Array()
		room_left.emit()
	_free_room_nodes(room)


func _free_room_nodes(room: NetRoom) -> void:
	# A host's table is its own main_scene, which it goes on playing.
	if _role == Role.DEDICATED:
		var holder := _room_node(room.code)
		if holder != null:
			holder.queue_free()
		elif room.table != null:
			room.table.queue_free()
	room.table = null
	room.manager = null
	room.sync = null


func _room_node(code: String) -> Node:
	return get_tree().root.get_node_or_null(NodePath("%s/%s" % [ROOMS_ROOT, code]))


func _make_room_node(code: String) -> Node:
	var root := get_tree().root
	var holder := root.get_node_or_null(NodePath(ROOMS_ROOT))
	if holder == null:
		holder = Node.new()
		holder.name = ROOMS_ROOT
		root.add_child(holder)
	var room_node := holder.get_node_or_null(NodePath(code))
	if room_node == null:
		room_node = Node.new()
		room_node.name = code
		holder.add_child(room_node)
	return room_node


## A finished table is dead weight on a dedicated server, so its room is dropped
## after a linger. A host's room is the host itself and outlives its round.
func _watch_round(room: NetRoom) -> void:
	if room.manager == null:
		return
	room.manager.round_over.connect(func(_final: MauMauTable) -> void:
		room.state = NetRoom.State.OVER
		if _role != Role.DEDICATED:
			return
		get_tree().create_timer(ROOM_LINGER).timeout.connect(func() -> void:
			if rooms.get(room.code) == room:
				_free_room(room)))


#################RELAY########################
# Godot addresses an RPC by node path and two rooms cannot share one, so every
# table message goes through these three instead of @rpc on the table.
# Methods: "table" [dict] · "hand" [ids] · "event" [name, args] · "client_ready" []
# (server ← client) · "submit_move" [card_id] · "submit_draw" [] · "submit_wish" [suit]
# · "look" [yaw, pitch] up, [seat, yaw, pitch] down.


## Client → its room's table on the server.
func to_server(method: String, args: Array) -> void:
	if is_client():
		_rpc_to_server.rpc_id(SERVER_PEER, method, args)


## Server → every peer in the room (never the server itself).
func to_room(room: NetRoom, method: String, args: Array) -> void:
	if not is_server() or room == null:
		return
	for peer in room.peers:
		if peer != SERVER_PEER:
			_rpc_to_client.rpc_id(peer, method, args)


## Server → one peer.
func to_peer(peer: int, method: String, args: Array) -> void:
	if not is_server() or peer == SERVER_PEER or peer == 0:
		return
	_rpc_to_client.rpc_id(peer, method, args)


#################ROUND########################


## Start the round of my room: the server does it, a client asks for it.
func start_round() -> void:
	if is_client():
		_rpc_request_start.rpc_id(SERVER_PEER)
		return
	if is_server():
		_begin_round_for(_my_room())


## Kept for the lobby, which knows the request may travel.
func request_start() -> void:
	start_round()


func _begin_round_for(room: NetRoom) -> void:
	if not is_server() or room == null or room.state != NetRoom.State.LOBBY:
		return
	var humans := room.peers
	var free_seats := range(MAX_SEATS)
	free_seats.shuffle()
	var seated := mini(humans.size(), MAX_SEATS)
	if humans.size() > seated:
		push_warning("Net: %d humans for %d seats, the rest sit out" % [humans.size(), MAX_SEATS])
	var seats := PackedInt32Array()
	seats.resize(MAX_SEATS)
	for i in seated:
		seats[free_seats[i]] = humans[i]
	room.seat_peers = seats
	room.state = NetRoom.State.PLAYING

	if _role == Role.DEDICATED:
		var scene: PackedScene = load(TABLE_SCENE_UID)
		var table := scene.instantiate() as NetTable
		# The manager reads both in its _ready, which runs on add_child.
		table.room = room
		table.manager.room = room
		table.manager.seating = seats
		room.table = table
		room.manager = table.manager
		room.sync = table.manager.net_sync
		_watch_round(room)
		_make_room_node(room.code).add_child(table)
	else:
		seat_peers = seats

	for peer in room.peers:
		if peer != SERVER_PEER:
			_rpc_begin_round.rpc_id(peer, seats)

	if _role == Role.HOST:
		round_starting.emit(seat_peers)
		get_tree().change_scene_to_packed(load(MAIN_SCENE_UID))


#################WIRE########################
# Any peer may call an @rpc method, so every receiver checks its own role first.


@rpc("any_peer", "call_remote", "reliable")
func _rpc_join_room(code: String) -> void:
	if is_server():
		_join_room_for(multiplayer.get_remote_sender_id(), code)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_create_room() -> void:
	if is_server():
		_join_room_for(multiplayer.get_remote_sender_id(), _fresh_code())


@rpc("any_peer", "call_remote", "reliable")
func _rpc_leave_room() -> void:
	if is_server():
		_remove_peer_from_room(multiplayer.get_remote_sender_id())


@rpc("any_peer", "call_remote", "reliable")
func _rpc_request_start() -> void:
	if is_server():
		_begin_round_for(room_of_peer(multiplayer.get_remote_sender_id()))


@rpc("any_peer", "call_remote", "reliable")
func _rpc_to_server(method: String, args: Array) -> void:
	if not is_server():
		return
	var sender := multiplayer.get_remote_sender_id()
	var room := room_of_peer(sender)
	if room == null or room.sync == null:
		push_warning("Net: dropping '%s' from peer %d: no table to relay it to" % [method, sender])
		return
	room.sync.receive(sender, method, args)


@rpc("authority", "call_remote", "reliable")
func _rpc_to_client(method: String, args: Array) -> void:
	if not is_client():
		return
	if _sync == null:
		push_warning("Net: dropping '%s' from the server: no table attached" % method)
		return
	_sync.receive(SERVER_PEER, method, args)


@rpc("authority", "call_remote", "reliable")
func _rpc_room_joined(code: String) -> void:
	if not is_client():
		return
	room_code = code
	room_joined.emit(code)


@rpc("authority", "call_remote", "reliable")
func _rpc_room_left() -> void:
	if not is_client() or room_code.is_empty():
		return
	room_code = ""
	_roster = PackedInt32Array()
	seat_peers = PackedInt32Array()
	room_left.emit()


@rpc("authority", "call_remote", "reliable")
func _rpc_room_error(message: String) -> void:
	if is_client():
		room_error.emit(message)


@rpc("authority", "call_remote", "reliable")
func _rpc_begin_round(seats: PackedInt32Array) -> void:
	if not is_client():
		return
	seat_peers = seats
	round_starting.emit(seat_peers)
	get_tree().change_scene_to_packed(load(MAIN_SCENE_UID))


# Clients learn about peers from their room's roster, not from the raw relay:
# that relay announces the server's own id 1 even when nobody plays it, it
# arrives before the roster does, and it knows nothing about rooms.
@rpc("authority", "call_remote", "reliable")
func _rpc_roster(ids: PackedInt32Array) -> void:
	if not is_client():
		return
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
	# A host's peer_joined is room-scoped and fires when the peer joins the room.
	if _role == Role.DEDICATED:
		peer_joined.emit(id)


func _on_peer_disconnected(id: int) -> void:
	if not is_server():
		return
	var at := _roster.find(id)
	if at != -1:
		_roster.remove_at(at)
	# Raw first: tearing the room down may free the table that listens for this.
	if _role == Role.DEDICATED:
		peer_left.emit(id)
	_remove_peer_from_room(id)


func _on_connected_to_server() -> void:
	# Taken before the emit: a listener may call join_room and set a new one.
	var code := _pending_room
	_pending_room = ""
	connected_to_server.emit()
	if not code.is_empty():
		_rpc_join_room.rpc_id(SERVER_PEER, code)


func _on_connection_failed() -> void:
	leave()
	connection_failed.emit()


func _on_server_disconnected() -> void:
	leave()
	server_disconnected.emit()
