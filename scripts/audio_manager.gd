extends Node

const MUSIC := preload("res://assets/audio/tema.wav")
const PICKUP := preload("res://assets/audio/cristal.wav")
const HIT := preload("res://assets/audio/golpe.wav")
const DEATH := preload("res://assets/audio/muerte.wav")
const COMPLETE := preload("res://assets/audio/mision.wav")
const STEP := preload("res://assets/audio/paso.wav")
var volume := 0.7
var music_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _next_player := 0

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	var music_stream := MUSIC.duplicate() as AudioStreamWAV
	music_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	music_player.stream = music_stream
	add_child(music_player)
	for i in 8:
		var player := AudioStreamPlayer.new()
		add_child(player)
		_sfx_players.append(player)
	apply_volume()
	music_player.play()

func set_volume(value: float) -> void:
	volume = clampf(value, 0.0, 1.0)
	apply_volume()

func apply_volume() -> void:
	var db := linear_to_db(maxf(volume, 0.001))
	if music_player:
		music_player.volume_db = db - 5.0
	for player in _sfx_players:
		player.volume_db = db

func play_sfx(kind: String) -> void:
	var stream: AudioStream
	match kind:
		"pickup": stream = PICKUP
		"hit": stream = HIT
		"death": stream = DEATH
		"complete": stream = COMPLETE
		"step": stream = STEP
		_: return
	var player := _sfx_players[_next_player]
	_next_player = (_next_player + 1) % _sfx_players.size()
	player.stream = stream
	player.play()
