extends Node
## Reproductor central de SFX con pool y variación de pitch (GDD §11.1: sonido en capas).
## Los .wav placeholder se generan proceduralmente; se reemplazan 1:1 desde assets-list.md.

const SFX_DIR := "res://assets/audio/placeholder/"
const FOOTSTEP_DIR := "res://assets/audio/footsteps/"

const POOL_3D_SIZE := 16
const POOL_UI_SIZE := 8

var _streams: Dictionary = {}
var _footsteps: Array[AudioStream] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _pool_ui: Array[AudioStreamPlayer] = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL_3D_SIZE:
		var p := AudioStreamPlayer3D.new()
		p.bus = &"SFX"
		p.max_distance = 60.0
		add_child(p)
		_pool_3d.append(p)
	for i in POOL_UI_SIZE:
		var p := AudioStreamPlayer.new()
		p.bus = &"SFX"
		add_child(p)
		_pool_ui.append(p)
	_load_footsteps()


func _load_footsteps() -> void:
	if not DirAccess.dir_exists_absolute(FOOTSTEP_DIR):
		return
	for file in DirAccess.get_files_at(FOOTSTEP_DIR):
		if file.ends_with(".ogg") or file.ends_with(".wav"):
			var stream: AudioStream = load(FOOTSTEP_DIR + file)
			if stream != null:
				_footsteps.append(stream)


## Paso aleatorio del pack (no espacial: son los pies del propio player).
func play_footstep(volume_db := -13.0) -> void:
	if _footsteps.is_empty():
		return
	var p := _free_player_ui()
	p.stream = _footsteps[randi() % _footsteps.size()]
	p.volume_db = volume_db
	p.pitch_scale = randf_range(0.92, 1.08)
	p.play()


## SFX espacial (impactos, goblins, explosiones). `pitch_base` recolorea un
## placeholder sin regenerarlo (los goblins usan ~1.3: voz más aguda).
func play_3d(sfx_name: String, pos: Vector3, volume_db := 0.0, pitch_variation := 0.08, pitch_base := 1.0) -> void:
	var stream := _get_stream(sfx_name)
	if stream == null:
		return
	var p := _free_player_3d()
	p.stream = stream
	p.global_position = pos
	p.volume_db = volume_db
	p.pitch_scale = pitch_base * randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	p.play()


## SFX no espacial (arco propio, hitmarkers, UI).
func play_ui(sfx_name: String, volume_db := 0.0, pitch_variation := 0.05, pitch_base := 1.0) -> void:
	var stream := _get_stream(sfx_name)
	if stream == null:
		return
	var p := _free_player_ui()
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = pitch_base * randf_range(1.0 - pitch_variation, 1.0 + pitch_variation)
	p.play()


func _get_stream(sfx_name: String) -> AudioStream:
	if _streams.has(sfx_name):
		return _streams[sfx_name]
	var path := SFX_DIR + sfx_name + ".wav"
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: no existe el SFX '%s' (%s)" % [sfx_name, path])
		_streams[sfx_name] = null
		return null
	var stream: AudioStream = load(path)
	_streams[sfx_name] = stream
	return stream


func _free_player_3d() -> AudioStreamPlayer3D:
	for p in _pool_3d:
		if not p.playing:
			return p
	return _pool_3d[0]


func _free_player_ui() -> AudioStreamPlayer:
	for p in _pool_ui:
		if not p.playing:
			return p
	return _pool_ui[0]
