class_name ForageSystem
extends Node
## Flora por ronda (F3, M4b §3 adaptado a D17): al iniciar cada ronda —y al
## arrancar la partida— brotan 6-10 plantas en puntos determinísticos de las
## islas, sesgados a los bordes (farmear te aleja de la torre). Lo no cosechado
## se reemplaza en la tanda siguiente.

const MIN_SPAWNS := 6
const MAX_SPAWNS := 10

var _spots: Array[Vector3] = []


func _ready() -> void:
	_build_spots()
	WorldState.round_started.connect(func(n: int) -> void: _spawn_batch(n))
	# La tanda inicial (el intermedio de arranque): farmeo desde el minuto cero.
	(func() -> void: _spawn_batch(WorldState.round_number)).call_deferred()


## Candidatos en anillo sobre ambas islas (radio 55-85%), lejos de la torre.
func _build_spots() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	var islands := [
		[OutpostHeightfield.PLAYER_ISLAND, OutpostHeightfield.PLAYER_ISLAND_R, 11],
		[OutpostHeightfield.ALLY_ISLAND, OutpostHeightfield.ALLY_ISLAND_R, 5],
	]
	for island in islands:
		var center: Vector2 = island[0]
		var radius: float = island[1]
		var count: int = island[2]
		for i in count:
			var angle := rng.randf() * TAU
			var r := radius * rng.randf_range(0.55, 0.85)
			var p := center + Vector2(cos(angle), sin(angle)) * r
			# Fuera de la planta de la torre y de su explanada inmediata.
			if p.x > -1.0 and p.x < 9.0 and p.y > -35.0 and p.y < -25.0:
				continue
			_spots.append(Vector3(p.x, 8.0, p.y))


func _spawn_batch(round_number: int) -> void:
	for node in get_tree().get_nodes_in_group("forage_nodes"):
		node.queue_free()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5000 + round_number * 173
	var indices := range(_spots.size())
	# Fisher-Yates con el rng seedeado (shuffle() usa el rng global).
	for i in range(indices.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp: int = indices[i]
		indices[i] = indices[j]
		indices[j] = tmp
	var count := rng.randi_range(MIN_SPAWNS, mini(MAX_SPAWNS, _spots.size()))
	for i in count:
		var node := ForageNode.new()
		node.kind = &"flor" if rng.randf() < 0.5 else &"hongo"
		get_tree().current_scene.add_child(node)
		node.global_position = _spots[indices[i]]
