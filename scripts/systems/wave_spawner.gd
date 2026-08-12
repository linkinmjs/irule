class_name WaveSpawner
extends Node3D
## Oleadas nocturnas (GDD §4.1, §8): tres empujes por noche (21:00, 23:00, 01:00),
## élites en el último empuje desde el día 2. A las 03:00 los vivos se retiran
## entre la niebla (GDD §4.1 — congelación).

const PUSH_HOURS := [21.0, 23.0, 25.0]  # 25.0 == 01:00

var door: Node3D = null
var spawn_center := Vector3.ZERO

var _pushes_launched := 0
var _active_batches := 0  # contador, no bool: los batches se solapan con reloj rápido
var _night_over_reported := true


func _ready() -> void:
	WorldState.night_started.connect(_on_night_started)
	WorldState.time_frozen.connect(_on_time_frozen)
	# Precalienta el FBX del goblin: el primer spawn de la noche no paga el load.
	if ResourceLoader.exists(Goblin.MODEL_PATH):
		load(Goblin.MODEL_PATH)


func _process(_delta: float) -> void:
	if WorldState.phase != WorldState.Phase.NIGHT:
		return
	if _pushes_launched < PUSH_HOURS.size() and WorldState.hour >= PUSH_HOURS[_pushes_launched]:
		_launch_push(_pushes_launched)
		_pushes_launched += 1
	elif _pushes_launched == PUSH_HOURS.size() and _active_batches == 0 and not _night_over_reported:
		if get_tree().get_nodes_in_group("enemies").is_empty():
			_night_over_reported = true
			EventBus.night_cleared.emit()


func _on_night_started(_day: int) -> void:
	_pushes_launched = 0
	_night_over_reported = false


func _launch_push(index: int) -> void:
	var day := WorldState.day
	var count := 4 + day * 2 + index * 2
	var elites := 0
	if day >= 2 and index == PUSH_HOURS.size() - 1:
		elites = 1 + day / 3
	EventBus.wave_started.emit(index + 1, PUSH_HOURS.size())
	AudioManager.play_3d("wave_horn", spawn_center + Vector3.UP * 2.0, 4.0)
	_spawn_batch(count, elites)


func _spawn_batch(count: int, elites: int) -> void:
	_active_batches += 1
	for i in count:
		if not is_inside_tree() or WorldState.phase != WorldState.Phase.NIGHT:
			break
		_spawn_goblin(i >= count - elites)
		# process_always=false: el batch respeta la pausa (si no, spawnea en ESC).
		await get_tree().create_timer(randf_range(0.7, 1.4), false).timeout
		if not is_inside_tree():
			break
	_active_batches -= 1


func _spawn_goblin(elite: bool) -> void:
	var goblin := Goblin.new()
	goblin.configure(WorldState.day, elite)
	get_tree().current_scene.add_child(goblin)
	goblin.global_position = spawn_center + Vector3(randf_range(-1.6, 1.6), 0.05, randf_range(-1.2, 1.2))
	goblin.set_target(door)
	EventBus.enemy_spawned.emit(goblin)


func _on_time_frozen() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("retreat"):
			enemy.retreat()
