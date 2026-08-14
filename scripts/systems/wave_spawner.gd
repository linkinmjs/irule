class_name WaveSpawner
extends Node3D
## Spawner v3 (D17 "rondas"): al terminar el countdown de PREP suena el cuerno
## y la horda completa de la ronda entra en tandas espaciadas. Cuando cae el
## último goblin, la ronda queda superada (WorldState.clear_round).

const BATCH_SIZE := 8
const BATCH_GAP := 11.0

var door: Node3D = null
var spawn_center := Vector3.ZERO

var _active_batches := 0
var _horde_launched := false


func _ready() -> void:
	WorldState.assault_started.connect(_on_assault_started)
	# Precalienta el FBX del goblin: el primer spawn no paga el load.
	if ResourceLoader.exists(Goblin.MODEL_PATH):
		load(Goblin.MODEL_PATH)


func _process(_delta: float) -> void:
	if not WorldState.combat_active() or not _horde_launched or _active_batches > 0:
		return
	if get_tree().get_nodes_in_group("enemies").is_empty():
		_horde_launched = false
		WorldState.clear_round()


func _on_assault_started(_round_number: int) -> void:
	var info := WorldState.current_round
	_horde_launched = true
	AudioManager.play_3d("wave_horn", spawn_center + Vector3.UP * 2.0, 4.0)
	_launch_horde(int(info.get("enemy_count", 9)), int(info.get("elites", 0)))


## La horda entera de la ronda, en tandas de BATCH_SIZE cada BATCH_GAP s.
## Los élites entran al final (el cierre pesado).
func _launch_horde(total: int, elites: int) -> void:
	_active_batches += 1
	var spawned := 0
	while spawned < total:
		if not is_inside_tree() or not WorldState.combat_active() \
				or GameManager.state != GameManager.State.PLAYING:
			break
		var batch := mini(BATCH_SIZE, total - spawned)
		for i in batch:
			_spawn_goblin(spawned >= total - elites)
			spawned += 1
			await get_tree().create_timer(randf_range(0.7, 1.3), false).timeout
			if not is_inside_tree():
				_active_batches -= 1
				return
		if spawned < total:
			await get_tree().create_timer(BATCH_GAP, false).timeout
			if not is_inside_tree():
				_active_batches -= 1
				return
	_active_batches -= 1


func _spawn_goblin(elite: bool) -> void:
	var goblin := Goblin.new()
	goblin.configure(WorldState.round_number, elite)
	get_tree().current_scene.add_child(goblin)
	goblin.global_position = spawn_center + Vector3(randf_range(-1.6, 1.6), 0.05, randf_range(-1.2, 1.2))
	goblin.set_target(door)
	EventBus.enemy_spawned.emit(goblin)
