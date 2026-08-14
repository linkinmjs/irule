class_name AllyArcher
extends Node3D
## "Nuestro aliado dispara desde acá" (boceto 2026-08-12): arquero NPC en la
## torre aliada. Dispara flechas reales (Arrow) al goblin más cercano en rango.
## Preview del sistema de torres aliadas de M5 — cuando llegue la negociación,
## su cadencia/munición dependerán de los pactos (GDD §9).

const SHOOT_INTERVAL := 2.6
const RANGE := 30.0
const DAMAGE := 24.0
const ARROW_SPEED := 36.0

const WARNINGS := [
	"¡Ey! ¡Cuidado con eso!",
	"¡Soy de tu lado, arquero!",
	"¡Apuntale a los goblins!",
	"¡La próxima te la devuelvo!",
	"¡¿En serio?! ¡EY!",
]

## Trama por ronda (pedido 2026-08-13): una línea al empezar cada ronda.
## El aliado es la voz del mundo — cuenta qué pasa más allá del puesto.
## Indexado por ronda; de ahí en adelante cicla las últimas genéricas.
const LORE := [
	"Teru: Vienen del bosque quemado. Antes ahí había un pueblo.",
	"Teru: ¿Viste la bruma? No es niebla. Es lo que queda de los campos.",
	"Teru: Dicen que un mago anda cruzando las islas. Cobra caro, pero ayuda.",
	"Teru: El Portón lo construyó mi abuelo. No dejes que lo tiren.",
	"Teru: Cada vez son más. Algo los está empujando hacia acá.",
	"Teru: Anoche vi luces verdes tierra adentro. Eso no es fuego normal.",
	"Teru: Si caemos nosotros, después siguen los puertos. Somos el tapón.",
	"Teru: Guardá flechas. Esto recién empieza.",
]

var _cooldown := 0.0
var _warn_cooldown := 0.0
var _visual: Node3D


func _ready() -> void:
	add_to_group("allies")
	_cooldown = randf_range(0.5, 2.0)
	_build_visual()
	_build_hitbox()
	WorldState.round_started.connect(_on_round_started)


## La línea de trama entra unos segundos después del cartel "RONDA N",
## para que no se pisen en el HUD.
func _on_round_started(round_number: int) -> void:
	var line: String = LORE[mini(round_number - 1, LORE.size() - 1)]
	if round_number > LORE.size():
		line = LORE[LORE.size() - 1 - (round_number % 3)]
	get_tree().create_timer(3.5, false).timeout.connect(func() -> void:
		if WorldState.round_number == round_number:
			EventBus.announcement.emit(line))


## Flechazo amigo (pedido 2026-08-13): el aliado se queja, no muere.
func take_arrow_hit(_damage: float, _headshot: bool, _dir: Vector3, _pos: Vector3) -> void:
	if Time.get_ticks_msec() < _warn_cooldown:
		return
	_warn_cooldown = Time.get_ticks_msec() + 3000
	EventBus.announcement.emit(WARNINGS[randi() % WARNINGS.size()])
	AudioManager.play_3d("goblin_growl", global_position, -6.0, 0.1, 1.7)  # gruñido indignado
	# Se agacha un instante: el reproche también se ve.
	var tween := create_tween()
	tween.tween_property(_visual, "scale:y", 0.7, 0.1)
	tween.tween_property(_visual, "scale:y", 1.0, 0.25)


## Hitbox para que las flechas del player lo detecten (Area3D con redirect,
## capa destructibles — mismo patrón que la cabeza del goblin). El flechazo
## "cerca" (isla/torre) lo detecta la propia flecha por distancia al impactar
## (Arrow._notify_allies_near) — un Area3D grande frenaría flechas en el aire.
func _build_hitbox() -> void:
	var area := Area3D.new()
	area.collision_layer = 128
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("redirect_to", self)
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.2, 1.9, 1.2)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, 0.95, 0.0)
	area.add_child(col)
	add_child(area)


func _physics_process(delta: float) -> void:
	_cooldown -= delta
	if _cooldown > 0.0:
		return
	var target := _closest_goblin()
	if target == null:
		_cooldown = 0.4  # re-chequeo barato mientras no hay blancos
		return
	_cooldown = SHOOT_INTERVAL * randf_range(0.85, 1.2)
	_shoot_at(target)


func _shoot_at(target: Node3D) -> void:
	var origin := global_position + Vector3(0.0, 0.5, 0.0)
	var dist := origin.distance_to(target.global_position)
	# Lead simple: apuntar a donde va a estar cuando llegue la flecha.
	var target_vel := Vector3.ZERO
	if target is CharacterBody3D:
		target_vel = (target as CharacterBody3D).velocity
	var aim := target.global_position + Vector3(0.0, 0.9, 0.0) + target_vel * (dist / ARROW_SPEED)
	var dir := (aim - origin).normalized()

	var arrow := Arrow.new()
	get_tree().current_scene.add_child(arrow)
	arrow.setup(self, origin + dir * 0.6, dir * ARROW_SPEED, DAMAGE)
	AudioManager.play_3d("bow_shoot", origin, -8.0)

	# El arquero mira hacia donde tira.
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() > 0.01:
		_visual.rotation.y = atan2(flat.x, flat.z)


func _closest_goblin() -> Node3D:
	var best: Node3D = null
	var best_dist := RANGE
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_3d := enemy as Node3D
		if enemy_3d == null:
			continue
		var d := global_position.distance_to(enemy_3d.global_position)
		if d < best_dist:
			best_dist = d
			best = enemy_3d
	return best


## Placeholder de primitivas con los colores del aliado (azul — GDD §9: cada
## torre tiene su personaje; el modelo llega con M5).
func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var ally_cloth := PSXMaterials.cloth_red()
	var skin := PSXMaterials.cloth()
	_piece(Vector3(0.44, 0.55, 0.26), Vector3(0.0, 0.95, 0.0), ally_cloth)
	_piece(Vector3(0.28, 0.28, 0.28), Vector3(0.0, 1.4, 0.0), skin)
	for side in [-1.0, 1.0]:
		_piece(Vector3(0.12, 0.45, 0.12), Vector3(0.3 * side, 0.95, 0.05), ally_cloth)
		_piece(Vector3(0.14, 0.6, 0.14), Vector3(0.12 * side, 0.32, 0.0), ally_cloth)
	# Arco de perfil.
	var bow := _piece(Vector3(0.05, 0.85, 0.05), Vector3(0.34, 1.0, 0.25), PSXMaterials.wood_dark())
	bow.rotation.x = 0.25


func _piece(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	_visual.add_child(mi)
	return mi
