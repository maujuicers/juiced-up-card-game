extends Node

@export var music_player: AudioStreamPlayer
@export var ui_player: AudioStreamPlayer
@export var sfx_player: AudioStreamPlayer
@export var max_polyphony: int = 32

var sfx_playback: AudioStreamPlaybackPolyphonic

func _ready() -> void:
	_setup_polyphonic_sfx()

func _setup_polyphonic_sfx() -> void:
	var poly_stream := AudioStreamPolyphonic.new()
	poly_stream.polyphony = max_polyphony

	sfx_player.stream = poly_stream
	sfx_player.bus = "SFX"
	sfx_player.play()
	
	sfx_playback = sfx_player.get_stream_playback() as AudioStreamPlaybackPolyphonic

func play_music(stream: AudioStream, volume_db: float = 0.0) -> void:
	if not stream:
		return

	if music_player.stream == stream and music_player.playing:
		music_player.volume_db = volume_db
		return

	music_player.stream = stream
	music_player.volume_db = volume_db
	music_player.play()

func stop_music() -> void:
	music_player.stop()

func play_ui(stream: AudioStream) -> void:
	if not stream:
		return
	ui_player.stream = stream
	ui_player.play()

func play_sfx(stream: AudioStream, volume_db: float = 0.0, pitch_randomness: float = 0.0) -> void:
	if not stream or not sfx_playback:
		return

	var pitch := 1.0 + randf_range(-pitch_randomness, pitch_randomness)
	sfx_playback.play_stream(stream, 0.0, volume_db, pitch)

# E.g. a destroyed bottle would not exist anymore to play sfx itself.
func play_spatial_sfx(stream: AudioStream, global_pos: Vector2, volume_db: float = 0.0, pitch_randomness: float = 0.08) -> void:
	if not stream:
		return

	var temp_player := AudioStreamPlayer2D.new()
	temp_player.stream = stream
	temp_player.global_position = global_pos
	temp_player.bus = "SFX"
	temp_player.volume_db = volume_db
	temp_player.pitch_scale = 1.0 + randf_range(-pitch_randomness, pitch_randomness)
	temp_player.autoplay = true

	temp_player.finished.connect(temp_player.queue_free)
	get_tree().current_scene.add_child(temp_player)
