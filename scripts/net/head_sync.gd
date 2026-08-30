extends Node

class_name HeadSync

## Head-look on the wire: every human seat's head yaw and camera pitch, and
## nothing else — where a head *is* belongs to the seat marker, so two angles
## describe the whole of what a remote player does with theirs.
##
## They travel at [member replication_interval], not per frame, and only when
## they changed: a bar full of cats looking around does not need a shooter's
## packet rate. What arrives is interpolated over that same interval instead of
## snapped, which is what buys the low rate its smoothness.
##
## Like [MauMauNetSync] this holds no [code]@rpc[/code] — two rooms on one server
## cannot share a node path. The "look" message goes through the [code]Net[/code]
## relay and that sibling hands it here.

## Below this (radians) a look counts as unchanged and no packet goes out.
const LOOK_EPSILON := 0.001

## Seconds between samples of the local look, and the window a received one is
## played back over. 10 Hz; the point of this node is to not ship 60.
@export_range(0.02, 1.0, 0.01, "suffix:s") var replication_interval := 0.1
@export var manager: MauMauGameManager

## One seat's look, played back from [member from] to [member to] over one
## [member replication_interval].
class SeatLook:
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var elapsed := 0.0
	## False once `to` has been reached: a settled head is not rewritten every frame.
	var moving := false

## Index = seat. Only holds seats this peer can actually see a head for.
var _looks: Array[SeatLook] = []
## The last look this peer sent, so a still head sends nothing.
var _sent := Vector2.INF
var _send_timer := 0.0
## Server: peer → last relayed tick, to cap what one client can make it fan out.
var _relayed_at: Dictionary = {}


func _ready() -> void:
	# Offline there is nobody to tell; a dedicated server holds no heads and only relays.
	if manager == null or not Net.is_online() or Net.is_dedicated():
		set_process(false)
		return
	for i in manager.seat_markers.size():
		_looks.append(SeatLook.new())


func _process(delta: float) -> void:
	_interpolate(delta)
	_send_timer -= delta
	if _send_timer > 0.0:
		return
	_send_timer = replication_interval
	_send_local_look()


#################WIRE########################
# "look" arrives here from MauMauNetSync in both directions: [yaw, pitch] from a
# client, [seat, yaw, pitch] from the server. Either may be anything at all.


func receive(peer: int, args: Array) -> void:
	if Net.is_server():
		_receive_as_server(peer, args)
	elif Net.is_client():
		_receive_as_client(args)


func _receive_as_server(peer: int, args: Array) -> void:
	if args.size() < 2 or not _is_angle(args[0]) or not _is_angle(args[1]):
		push_warning("HeadSync received a malformed 'look' from peer %d: %s" % [peer, args])
		return
	var room: NetRoom = manager.room
	if room == null:
		return
	var seat := room.seat_for_peer(peer)
	# One peer's look costs the server a message per other peer in the room, so a
	# client that ignores the interval is throttled here rather than amplified.
	if seat < 0 or not _may_relay(peer):
		return
	var yaw := _clamp_yaw(args[0])
	var pitch := _clamp_pitch(args[1])
	_relay(seat, yaw, pitch, peer)
	# A host also sits at the table it serves; on a dedicated server there is no
	# head to drive and _looks is empty, so this is a no-op there.
	_receive_look(seat, yaw, pitch)


func _receive_as_client(args: Array) -> void:
	if args.size() < 3 or typeof(args[0]) != TYPE_INT or not _is_angle(args[1]) or not _is_angle(args[2]):
		push_warning("HeadSync received a malformed 'look' from the server: %s" % [args])
		return
	_receive_look(args[0], _clamp_yaw(args[1]), _clamp_pitch(args[2]))


## Server: pass one seat's look on to every other peer in the room.
func _relay(seat: int, yaw: float, pitch: float, except: int) -> void:
	var room: NetRoom = manager.room
	if room == null:
		return
	for peer in room.peers:
		if peer != except:
			Net.to_peer(peer, "look", [seat, yaw, pitch])


func _may_relay(peer: int) -> bool:
	var now := Time.get_ticks_msec()
	# Half the interval: jitter must never cost a client a legitimate packet, and
	# the worst a shouting one can buy itself is twice the fan-out.
	if now - int(_relayed_at.get(peer, -1000000)) < int(replication_interval * 500.0):
		return false
	_relayed_at[peer] = now
	return true


func _is_angle(value: Variant) -> bool:
	return typeof(value) == TYPE_FLOAT or typeof(value) == TYPE_INT


func _clamp_yaw(value: float) -> float:
	return clampf(value, -PlayerController.YAW_LIMIT, PlayerController.YAW_LIMIT)


func _clamp_pitch(value: float) -> float:
	return clampf(value, PlayerController.MIN_PITCH, PlayerController.MAX_PITCH)


#################LOCAL########################


func _send_local_look() -> void:
	var seat: int = Net.my_seat()
	if seat < 0 or manager.player == null:
		return
	var angles := manager.player.look_angles()
	if angles.distance_squared_to(_sent) < LOOK_EPSILON * LOOK_EPSILON:
		return
	_sent = angles
	if Net.is_server():
		# A host has no server to ask: it is the relay.
		_relay(seat, angles.x, angles.y, Net.SERVER_PEER)
	else:
		Net.to_server("look", [angles.x, angles.y])


#################PLAYBACK########################


## Start a new interpolation window from wherever the head currently sits, so a
## packet that arrives early or late bends the motion instead of jumping it.
func _receive_look(seat: int, yaw: float, pitch: float) -> void:
	# The local seat's own head is the camera's; it is hidden and it never lags.
	if seat < 0 or seat >= _looks.size() or seat == Net.my_seat():
		return
	var look := _looks[seat]
	look.from = _shown(look)
	look.to = Vector2(yaw, pitch)
	look.elapsed = 0.0
	look.moving = true


func _interpolate(delta: float) -> void:
	for seat in _looks.size():
		var look := _looks[seat]
		if not look.moving:
			continue
		look.elapsed += delta
		var angles := _shown(look)
		var marker: SeatMarker = manager.seat_markers[seat]
		if marker != null:
			marker.look(angles.x, angles.y)
		if look.elapsed >= replication_interval:
			look.moving = false


func _shown(look: SeatLook) -> Vector2:
	if replication_interval <= 0.0:
		return look.to
	return look.from.lerp(look.to, minf(look.elapsed / replication_interval, 1.0))
