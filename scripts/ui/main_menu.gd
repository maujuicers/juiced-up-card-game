extends Node3D

@export var settings_menu: Control
@export var click_sfx: AudioStream
@export var start_game_button: Button
@export var status_label: Label
@export var roster_label: Label
@export var address_row: Control
@export var server_address: LineEdit
@export var idle_buttons: Control
@export var host_button: Button
@export var connected_buttons: Control
@export var start_round_button: Button
@export var room_row: Control
@export var room_code: LineEdit
@export var room_buttons: Control
@export var code_label: Label
@export var code_hint: Label
@export var leave_room_button: Button

const MAIN_SCENE = preload("uid://be4pqwq2ycfn3")

enum State { IDLE, CONNECTING, CONNECTED, IN_ROOM }

var state: State = State.IDLE

func _ready() -> void:
	# Making sure to hide the settings menu
	settings_menu.hide()
	AudioManager.stop_music()

	server_address.text = Net.DEFAULT_URL
	server_address.placeholder_text = Net.LOCAL_URL
	Net.peer_joined.connect(_on_peer_changed)
	Net.peer_left.connect(_on_peer_changed)
	Net.connected_to_server.connect(_on_connected_to_server)
	Net.connection_failed.connect(_on_connection_failed)
	Net.server_disconnected.connect(_on_server_disconnected)
	Net.room_joined.connect(_on_room_joined)
	Net.room_left.connect(_on_room_left)
	Net.room_error.connect(_on_room_error)
	if Net.is_online():
		code_label.text = Net.room_code
		_set_online_state(_connected_status())
	else:
		_set_state(State.IDLE, "Not connected")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		AudioManager.play_ui(click_sfx)
		settings_menu.hide()

func _set_state(new_state: State, status: String) -> void:
	state = new_state
	status_label.text = status
	var idle := new_state == State.IDLE
	var lobby := new_state == State.CONNECTED
	var in_room := new_state == State.IN_ROOM
	start_game_button.visible = idle
	address_row.visible = idle
	idle_buttons.visible = idle
	# A browser cannot listen on a socket.
	host_button.visible = not OS.has_feature("web")
	room_row.visible = lobby
	room_buttons.visible = lobby
	code_label.visible = in_room
	code_hint.visible = in_room
	roster_label.visible = in_room
	connected_buttons.visible = not idle
	start_round_button.visible = in_room
	leave_room_button.visible = in_room
	if not in_room:
		code_label.text = ""
	_refresh_roster()

# Hosting lands in a room before host() returns; a fresh connection does not.
func _set_online_state(status: String) -> void:
	_set_state(State.IN_ROOM if not Net.room_code.is_empty() else State.CONNECTED, status)

func _connected_status() -> String:
	if Net.is_server():
		return "Hosting on port %d" % Net.SERVER_PORT
	return "Connected to %s" % server_address.text

func _refresh_roster() -> void:
	if state != State.IN_ROOM:
		roster_label.text = ""
		return
	var me := multiplayer.get_unique_id()
	var lines := PackedStringArray()
	for id in Net.peers():
		var who := "Host" if id == Net.SERVER_PEER else "Player %d" % id
		lines.append(who + (" (you)" if id == me else ""))
	roster_label.text = "Players %d/%d\n%s" % [lines.size(), Net.MAX_SEATS, "\n".join(lines)]

func _on_peer_changed(_id: int) -> void:
	_refresh_roster()

func _on_connected_to_server() -> void:
	_set_online_state(_connected_status())

func _on_connection_failed() -> void:
	_set_state(State.IDLE, "Connection failed")

func _on_server_disconnected() -> void:
	_set_state(State.IDLE, "Server disconnected")

func _on_room_joined(code: String) -> void:
	code_label.text = code
	room_code.text = code
	_set_state(State.IN_ROOM, _connected_status())

func _on_room_left() -> void:
	_set_state(State.CONNECTED, _connected_status())

func _on_room_error(message: String) -> void:
	_set_state(state, message)

func _on_start_game_button_pressed() -> void:
	AudioManager.play_ui(click_sfx)
	get_tree().change_scene_to_packed(MAIN_SCENE)


func _on_tutorial_button_pressed() -> void:
	#TODO: Open tutorial popup
	AudioManager.play_ui(click_sfx)
	pass


func _on_settings_button_pressed() -> void:
	AudioManager.play_ui(click_sfx)
	settings_menu.show()


func _on_quit_button_pressed() -> void:
	AudioManager.play_ui(click_sfx)
	get_tree().quit()


func _on_host_button_pressed() -> void:
	AudioManager.play_ui(click_sfx)
	if Net.host() != OK:
		_set_state(State.IDLE, "Could not host on port %d" % Net.SERVER_PORT)
		return
	_set_online_state(_connected_status())


func _on_join_button_pressed() -> void:
	AudioManager.play_ui(click_sfx)
	var url := server_address.text.strip_edges()
	if url.is_empty():
		url = Net.LOCAL_URL
		server_address.text = url
	if Net.join(url) != OK:
		_set_state(State.IDLE, "Could not reach %s" % url)
		return
	_set_state(State.CONNECTING, "Connecting to %s ..." % url)


func _on_room_code_text_changed(new_text: String) -> void:
	var upper := new_text.to_upper()
	# Rewriting an unchanged text would still throw the caret to the end.
	if upper == new_text:
		return
	room_code.text = upper
	room_code.caret_column = upper.length()


func _on_join_room_button_pressed() -> void:
	AudioManager.play_ui(click_sfx)
	var code := room_code.text.strip_edges().to_upper()
	if code.is_empty():
		_set_state(state, "Enter a room code")
		return
	room_code.text = code
	# Net may answer straight away, and its answer must survive this status.
	_set_state(state, "Joining room %s ..." % code)
	Net.join_room(code)


func _on_new_room_button_pressed() -> void:
	AudioManager.play_ui(click_sfx)
	_set_state(state, "Opening a room ...")
	Net.create_room()


func _on_start_round_button_pressed() -> void:
	AudioManager.play_ui(click_sfx)
	Net.start_round()


func _on_leave_room_button_pressed() -> void:
	AudioManager.play_ui(click_sfx)
	Net.leave_room()
	_set_online_state(_connected_status())


func _on_leave_button_pressed() -> void:
	AudioManager.play_ui(click_sfx)
	Net.leave()
	_set_state(State.IDLE, "Not connected")
