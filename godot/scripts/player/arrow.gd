class_name Arrow
extends Node3D
## Proyectil con caída (D5). Raycast por frame contra el trayecto → sin tunneling.
## Al impactar deja el visual clavado en el objetivo (los zombies la llevan puesta).

# Balística v2 (docs/design/guia-de-tiro.md): unificada con la gravedad del
# player. Default para shooters sin stats (AllyArcher); el player pasa la suya
# desde ArcherStats (los tipos de flecha la multiplican — M4b).
const GRAVITY := 13.0
const LIFETIME := 8.0
const STICK_TIME := 12.0
# world | enemies | debris | interactables | head_hitbox | destructibles
const HIT_MASK := 1 | 4 | 16 | 32 | 64 | 128

var velocity := Vector3.ZERO
var damage := 20.0

var _shooter: Node3D
var _life := 0.0
var _visual: Node3D
var _charge := 1.0
var _perfect := false
var _start_pos := Vector3.ZERO
var _gravity := GRAVITY
var _headshot_bonus := 1.0
var _type: ArrowTypeData = null  # null == normal (los NPC no pasan tipo)


func setup(shooter: Node3D, from: Vector3, initial_velocity: Vector3, dmg: float,
		charge := 1.0, perfect := false, gravity := GRAVITY, headshot_bonus := 1.0,
		type_id: StringName = &"normal") -> void:
	_shooter = shooter
	global_position = from
	_start_pos = from
	velocity = initial_velocity
	damage = dmg
	_charge = charge
	_perfect = perfect
	_gravity = gravity
	_headshot_bonus = headshot_bonus
	_type = Catalog.arrow_type(type_id)
	_orient()


func _ready() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var shaft := MeshInstance3D.new()
	var shaft_mesh := BoxMesh.new()
	shaft_mesh.size = Vector3(0.02, 0.02, 0.55)
	shaft.mesh = shaft_mesh
	shaft.material_override = PSXMaterials.wood()
	_visual.add_child(shaft)
	var tip := MeshInstance3D.new()
	var tip_mesh := BoxMesh.new()
	tip_mesh.size = Vector3(0.03, 0.03, 0.06)
	tip.position = Vector3(0.0, 0.0, -0.29)
	tip.mesh = tip_mesh
	tip.material_override = PSXMaterials.metal()
	_visual.add_child(tip)
	var fletch := MeshInstance3D.new()
	var fletch_mesh := BoxMesh.new()
	fletch_mesh.size = Vector3(0.05, 0.05, 0.08)
	fletch.position = Vector3(0.0, 0.0, 0.24)
	fletch.mesh = fletch_mesh
	# El fletch lleva el color del tipo (lectura 1:1 material → flecha, M4b §2).
	if _type != null and _type.id != &"normal":
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = _type.tint
		fletch.material_override = mat
	else:
		fletch.material_override = PSXMaterials.cloth_red()
	_visual.add_child(fletch)


func _physics_process(delta: float) -> void:
	_life += delta
	if _life > LIFETIME:
		queue_free()
		return

	velocity.y -= _gravity * delta
	var from := global_position
	var to := from + velocity * delta

	var query := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK)
	query.collide_with_areas = true
	# Solo los shooters con cuerpo físico se excluyen (el AllyArcher es Node3D).
	if _shooter is CollisionObject3D:
		query.exclude = [(_shooter as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty():
		global_position = to
		_orient()
		return
	_resolve(hit)


func _resolve(hit: Dictionary) -> void:
	var collider: Object = hit["collider"]
	var target: Node = collider as Node
	var headshot := false

	if collider is Area3D and collider.has_meta("redirect_to"):
		target = collider.get_meta("redirect_to")
		headshot = bool(collider.get_meta("is_head", false))

	global_position = hit["position"]
	_orient()

	if target != null and target.has_method("take_arrow_hit"):
		# El bonus de headshot del arquero (talentos de OJO) es EXTRA al
		# multiplicador propio del objetivo.
		var final_damage := damage * (_headshot_bonus if headshot else 1.0)
		target.take_arrow_hit(final_damage, headshot, velocity.normalized(), hit["position"])
		_grant_xp(target, headshot, hit["position"])
		_stick_to(target)
	else:
		AudioManager.play_3d("arrow_hit_world", hit["position"], -8.0)
		# Memoria del tiro (D14): solo los impactos al mundo — corregí desde ahí.
		VFX.impact_marker(get_tree().current_scene, hit["position"], hit.get("normal", Vector3.UP))
		_stick_to(target if target is Node3D else get_tree().current_scene)
	_apply_special_effects(hit["position"])
	_notify_allies_near(hit["position"], target)
	queue_free()


## Efectos de las flechas especiales al impactar (F4, M4b §2): AoE de la
## explosiva y zonas de fuego/escarcha. El punto se proyecta al suelo para que
## la zona quede a los pies aunque la flecha pegue en un cuerpo.
func _apply_special_effects(hit_pos: Vector3) -> void:
	if _type == null:
		return
	if _type.aoe_radius > 0.0:
		AudioManager.play_3d("barrel_explode", hit_pos, 2.0)
		VFX.dust_puff(get_tree().current_scene, hit_pos)
		for enemy in get_tree().get_nodes_in_group("enemies"):
			var enemy_3d := enemy as Node3D
			if enemy_3d == null:
				continue
			if enemy_3d.global_position.distance_to(hit_pos) <= _type.aoe_radius \
					and enemy.has_method("take_explosion"):
				enemy.take_explosion(_type.aoe_damage, hit_pos)
	if _type.zone != ArrowTypeData.ZoneEffect.NONE:
		var ground := hit_pos
		var query := PhysicsRayQueryParameters3D.create(
			hit_pos + Vector3.UP * 0.5, hit_pos + Vector3.DOWN * 6.0, 1)
		var floor_hit := get_world_3d().direct_space_state.intersect_ray(query)
		if not floor_hit.is_empty():
			ground = floor_hit["position"]
		var zone := GroundZone.new()
		zone.effect = _type.zone
		zone.radius = _type.zone_radius
		zone.duration = _type.zone_duration
		zone.dps = _type.zone_dps
		zone.slow = _type.zone_slow
		get_tree().current_scene.add_child(zone)
		zone.global_position = ground + Vector3.UP * 0.05


## Queja amplia del aliado (pedido 2026-08-13): un flechazo del player que cae
## cerca suyo — en su isla o contra su torre — también cuenta como agresión.
## Y los pájaros (F5) huyen del impacto: el tiro errado espanta la caza.
func _notify_allies_near(hit_pos: Vector3, direct_target: Node) -> void:
	if not _shooter is Player:
		return
	for ally in get_tree().get_nodes_in_group("allies"):
		if ally == direct_target or not ally is Node3D:
			continue  # el impacto directo ya se quejó por take_arrow_hit
		if (ally as Node3D).global_position.distance_to(hit_pos) < 7.0 \
				and ally.has_method("take_arrow_hit"):
			ally.take_arrow_hit(0.0, false, velocity.normalized(), hit_pos)
	for bird in get_tree().get_nodes_in_group("birds"):
		if bird == direct_target or not bird is Node3D:
			continue
		if (bird as Node3D).global_position.distance_to(hit_pos) < Bird.ARROW_SCARE_DIST \
				and bird.has_method("scare"):
			bird.scare(hit_pos)


## XP por acierto (D15): blanco (dummy < goblin) × potencia del draw ×
## distancia × calidad (headshot / tiro perfecto). Solo flechas del player.
func _grant_xp(target: Node, headshot: bool, hit_pos: Vector3) -> void:
	if not _shooter is Player:
		return
	var base := 0.0
	if target.is_in_group("enemies"):
		base = 4.0
	elif target.is_in_group("practice_targets"):
		base = 1.5
	if base <= 0.0:
		return
	var dist := _start_pos.distance_to(hit_pos)
	var xp := (base + dist / 8.0) * (0.5 + 0.5 * _charge)
	if headshot:
		xp *= 2.0
	if _perfect:
		xp *= 1.5
	WorldState.add_xp(maxi(roundi(xp), 1))


func _orient() -> void:
	if velocity.length_squared() > 0.01:
		var dir := velocity.normalized()
		# En tiro casi vertical, UP es colineal con la dirección y look_at falla.
		look_at(global_position + dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.BACK)


## Clona el visual y lo cuelga del objetivo: la flecha viaja con el zombie (GDD §11.2).
func _stick_to(node: Node) -> void:
	if node == null or not node is Node3D or not is_instance_valid(node):
		return
	var stuck := Node3D.new()
	var visual_copy := _visual.duplicate()
	stuck.add_child(visual_copy)
	(node as Node3D).add_child(stuck)
	stuck.global_transform = global_transform
	stuck.global_position -= velocity.normalized() * 0.22
	var timer := Timer.new()
	timer.wait_time = STICK_TIME
	timer.one_shot = true
	timer.autostart = true
	stuck.add_child(timer)
	timer.timeout.connect(stuck.queue_free)
