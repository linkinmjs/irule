class_name WildlifeSystem
extends Node
## Fauna del intermedio (F5, M4b §3 adaptado a D17): mantiene 2-4 pájaros
## dando vueltas entre perchas y flora mientras NO hay asalto. El cuerno los
## dispersa; al superar la ronda vuelven de a poco.

const MAX_BIRDS := 4

## Perchas (XZ; la Y la asienta cada pájaro por raycast): techo y balcón de la
## torre, deco de la isla del player y la torre aliada.
const PERCH_SPOTS := [
	Vector2(2.5, -28.5), Vector2(5.5, -31.5), Vector2(4.0, -25.5),
	Vector2(10.5, -35.0), Vector2(-2.5, -25.0), Vector2(12.0, -28.0),
	Vector2(-15.0, -112.0), Vector2(-18.0, -116.0),
]

var _perches: Array[Vector3] = []
var _spawn_in := 6.0


func _ready() -> void:
	for spot in PERCH_SPOTS:
		_perches.append(Vector3(spot.x, 12.0, spot.y))
	WorldState.assault_started.connect(func(_n: int) -> void: _scatter())


func _process(delta: float) -> void:
	if WorldState.combat_active() or GameManager.state != GameManager.State.PLAYING:
		return
	_spawn_in -= delta
	if _spawn_in > 0.0:
		return
	# Ritmo (M4b §3): con menos de 4 activos, entran 1-2 cada 90-150 s.
	_spawn_in = randf_range(90.0, 150.0)
	var current := get_tree().get_nodes_in_group("birds").size()
	if current >= MAX_BIRDS:
		return
	for i in mini(randi_range(1, 2), MAX_BIRDS - current):
		_spawn_bird()


func _scatter() -> void:
	_spawn_in = 12.0  # tras el asalto, la primera vuelta no tarda 90 s
	for bird in get_tree().get_nodes_in_group("birds"):
		bird.depart()


## Entra volando desde fuera del mapa hacia una percha.
func _spawn_bird() -> void:
	var bird := Bird.new()
	bird.perches = _perches
	var angle := randf() * TAU
	var origin := Vector3(4.0, 0.0, -30.0) \
		+ Vector3(cos(angle), 0.0, sin(angle)) * 45.0 + Vector3.UP * 18.0
	get_tree().current_scene.add_child(bird)
	bird.global_position = origin
