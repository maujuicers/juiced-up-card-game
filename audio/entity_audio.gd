extends AudioStreamPlayer3D
class_name EntityAudio

@export var polyphony: int = 4

var playback: AudioStreamPlaybackPolyphonic

func _ready() -> void:
	var poly_stream := AudioStreamPolyphonic.new()
	poly_stream.polyphony = polyphony
	
	stream = poly_stream
	bus = "SFX"
	play()
	
	playback = get_stream_playback() as AudioStreamPlaybackPolyphonic

func play_sound(sound_stream: AudioStream, pitch_randomness: float = 0.08, volume_adjustment: float = 0.0) -> void:
	if not sound_stream or not playback:
		return
		
	var pitch := 1.0 + randf_range(-pitch_randomness, pitch_randomness)
	playback.play_stream(sound_stream, 0.0, volume_adjustment, pitch)

func play_random(streams: Array[AudioStream], pitch_randomness: float = 0.08, volume_adjustment: float = 0.0) -> void:
	if streams.is_empty():
		return
		
	var random_stream: AudioStream = streams.pick_random()
	play_sound(random_stream, pitch_randomness, volume_adjustment)
