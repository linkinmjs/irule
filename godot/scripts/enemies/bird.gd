class_name Bird
extends Node3D
## Pájaro (F5, M4b §3): la fuente de PLUMAS. Sin navmesh — steering simple
## entre perchas y la flora activa (bajan a TUS flores: cazarlos protege la
## cosecha). FSM: PERCHED (hop) → FLY (seek+arrive, seno = planeo) → FEEDING
## (saltitos junto a una flor) → FLEE (disparo cerca o player encima).
## Posado = blanco chico; comiendo = fácil y cerca; volando = dejalo ir (v1).

enum State { PERCHED, FLY, FEEDING, FLEE }

const FLY_SPEED := 6.5
const FLEE_SPEED := 11.0
const WING_FPS := 12.0
const PLAYER_SCARE_DIST := 8.0
const ARROW_SCARE_DIST := 6.0

var perches: Array[Vector3] = []  # las inyecta WildlifeSystem

var _state := State.FLY
var _timer := 3.0
var _target := Vector3.ZERO
var _target_is_flower := false
var _leaving := false  # dispersión del asalto: vuela fuera y se va
var _dead := false
var _wing_frame := 0.0
var _hop_time := 0.0
var _visual: Node3D
var _wings: Array[MeshInstance3D] = []
var _shadow: MeshInstance3D


func _ready() -> void:
	add_to_group("birds")
	_build_visual()
	_build_hitbox()
	if not perches.is_empty():
		_fly_to(perches[randi() % perches.size()], false)


func _process(delta: float) -> void:
	if _dead:
		return
	match _state:
		State.PERCHED, State.FEEDING:
			_grounded_tick(delta)
		State.FLY:
			_fly_tick(delta, FLY_SPEED)
		State.FLEE:
			_fly_tick(delta, FLEE_SPEED)


func _grounded_tick(delta: float) -> void:
	_timer -= delta
	# Saltitos a 12 fps cuantizados: el hop PS1 se ve por pasos, no suave.
	_hop_time += delta
	var hop := absf(sin(floorf(_hop_time * WING_FPS) / WING_FPS * 7.0)) * 0.06
	_visual.position.y = hop
	_check_player_scare()
	if _timer > 0.0:
		return
	if _state == State.FEEDING:
		_fly_to(_random_perch(), false)
		return
	# Desde la percha: si hay flora activa, bajar a comer; si no, cambiar percha.
	var flower := _random_flower()
	if flower != Vector3.ZERO:
		_fly_to(flower, true)
	else:
		_fly_to(_random_perch(), false)


func _fly_tick(delta: float, speed: float) -> void:
	_flap(delta)
	var to_target := _target - global_position
	if to_target.length() < 0.4:
		if _leaving:
			queue_free()
			return
		_land()
		return
	var step := to_target.normalized() * speed * delta
	# Planeo: seno suave en Y encima del avance (M4b §3).
	step.y += sin(Time.get_ticks_msec() * 0.004) * 0.5 * delta
	global_position += step
	var flat := Vector3(to_target.x, 0.0, to_target.z)
	if flat.length_squared() > 0.01:
		_visual.rotation.y = atan2(flat.x, flat.z)


func _land() -> void:
	if _target_is_flower:
		_state = State.FEEDING
		_timer = randf_range(5.0, 8.0)
		_shadow.visible = true  # sombra solo en FEEDING: ancla el tiro fácil
	else:
		_state = State.PERCHED
		_timer = randf_range(4.0, 10.0)
		_shadow.visible = false
	_visual.position.y = 0.0
	_set_wings_open(false)


## Vuela a `spot` (XZ del destino; el aterrizaje se asienta con raycast).
func _fly_to(spot: Vector3, is_flower: bool) -> void:
	_state = State.FLY
	_target_is_flower = is_flower
	_shadow.visible = false
	_set_wings_open(true)
	var ground := _ground_at(spot)
	_target = ground + Vector3.UP * (0.05 if is_flower else 0.1)


func _check_player_scare() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null and global_position.distance_to(player.global_position) < PLAYER_SCARE_DIST:
		scare(player.global_position)


## Flechazo cerca o player encima: a la percha más lejana del susto.
func scare(from: Vector3) -> void:
	if _dead or _state == State.FLEE or _leaving:
		return
	var best := global_position + Vector3(randf_range(-8.0, 8.0), 6.0, randf_range(-8.0, 8.0))
	var best_dist := 0.0
	for perch in perches:
		var d := from.distance_to(perch)
		if d > best_dist:
			best_dist = d
			best = perch
	_state = State.FLEE
	_target_is_flower = false
	_shadow.visible = false
	_set_wings_open(true)
	_target = _ground_at(best) + Vector3.UP * 0.1


## Dispersión del asalto (D17): vuela alto fuera del mapa y desaparece.
func depart() -> void:
	if _dead:
		return
	_leaving = true
	_state = State.FLEE
	_shadow.visible = false
	_set_wings_open(true)
	var away := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	_target = global_position + away * 60.0 + Vector3.UP * 25.0


func take_arrow_hit(_damage: float, _headshot: bool, dir: Vector3, pos: Vector3) -> void:
	if _dead:
		return
	_dead = true
	AudioManager.play_3d("goblin_growl", pos, -10.0, 0.1, 2.6)  # chillido agudo
	VFX.dust_puff(get_tree().current_scene, global_position)
	var pickup := FeatherPickup.new()
	get_tree().current_scene.add_child(pickup)
	pickup.global_position = _ground_at(global_position) + Vector3.UP * 0.05
	# La pluma del golpe sale volando con la flecha (se ve el impacto).
	var tween := create_tween()
	tween.tween_property(self, "global_position", global_position + dir * 0.8, 0.12)
	tween.tween_callback(queue_free)


func _random_flower() -> Vector3:
	var flowers := get_tree().get_nodes_in_group("forage_nodes")
	if flowers.is_empty():
		return Vector3.ZERO
	var pick := flowers[randi() % flowers.size()] as Node3D
	if pick == null:
		return Vector3.ZERO
	# Al LADO de la planta, no encima (deja limpio el tiro y el [E] del player).
	return pick.global_position + Vector3(randf_range(-0.7, 0.7), 0.0, randf_range(-0.7, 0.7))


func _random_perch() -> Vector3:
	if perches.is_empty():
		return global_position + Vector3(randf_range(-6.0, 6.0), 2.0, randf_range(-6.0, 6.0))
	return perches[randi() % perches.size()]


func _ground_at(spot: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(
		Vector3(spot.x, maxf(spot.y, 2.0) + 14.0, spot.z),
		Vector3(spot.x, -6.0, spot.z), 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		return hit["position"]
	return spot


func _flap(delta: float) -> void:
	_wing_frame += delta * WING_FPS
	var up := int(_wing_frame) % 2 == 0
	for i in _wings.size():
		_wings[i].rotation.z = (0.7 if up else -0.35) * (1.0 if i == 0 else -1.0)


func _set_wings_open(open: bool) -> void:
	for i in _wings.size():
		_wings[i].rotation.z = (0.15 if open else 0.05) * (1.0 if i == 0 else -1.0)


## Cuerpo + 2 alas de quad (flip a 12 fps) + sombra (solo FEEDING).
func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var body_mat := StandardMaterial3D.new()
	body_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	body_mat.albedo_color = Color(0.45, 0.38, 0.34)
	body_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var wing_mat := StandardMaterial3D.new()
	wing_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wing_mat.albedo_color = Color(0.82, 0.8, 0.75)
	wing_mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.16, 0.14, 0.26)
	body.mesh = body_mesh
	body.position = Vector3(0.0, 0.12, 0.0)
	body.material_override = body_mat
	_visual.add_child(body)
	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.1, 0.1, 0.1)
	head.mesh = head_mesh
	head.position = Vector3(0.0, 0.22, 0.12)
	head.material_override = body_mat
	_visual.add_child(head)

	for side in [1.0, -1.0]:
		var wing := MeshInstance3D.new()
		var wing_mesh := QuadMesh.new()
		wing_mesh.size = Vector2(0.3, 0.18)
		wing.mesh = wing_mesh
		wing.position = Vector3(0.16 * side, 0.16, 0.0)
		wing.rotation.x = -PI * 0.5
		wing.material_override = wing_mat
		_visual.add_child(wing)
		_wings.append(wing)

	_shadow = MeshInstance3D.new()
	var shadow_mesh := QuadMesh.new()
	shadow_mesh.size = Vector2(0.34, 0.34)
	_shadow.mesh = shadow_mesh
	_shadow.rotation.x = -PI * 0.5
	_shadow.position = Vector3(0.0, 0.02, 0.0)
	var shadow_mat := StandardMaterial3D.new()
	shadow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shadow_mat.albedo_color = Color(0.0, 0.0, 0.0, 0.4)
	shadow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shadow.material_override = shadow_mat
	_shadow.visible = false
	add_child(_shadow)


## Las flechas lo detectan por Area3D con redirect (patrón de todo el juego).
func _build_hitbox() -> void:
	var area := Area3D.new()
	area.collision_layer = 128
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("redirect_to", self)
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.45, 0.42, 0.5)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, 0.16, 0.0)
	area.add_child(col)
	add_child(area)
