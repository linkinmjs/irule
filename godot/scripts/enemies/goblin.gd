class_name Goblin
extends CharacterBody3D
## Enemigo (D9): goblin del pack (GoblinCharacter.fbx, riggeado y animado).
## Marcha por el camino hacia la Puerta; no persigue al jugador (GDD §8).
## Al morir se desarma (D9): las piezas del ragdoll nacen de las poses reales
## de los huesos. Fallback completo a muñeco de primitivas si falta el FBX.

enum State { MARCH, ATTACK, RETREAT }

const MODEL_PATH := "res://assets/models/packs/goblins/GoblinCharacter.fbx"
const MODEL_TEXTURE := "res://assets/models/packs/goblins/GoblinShaded.png"
const MODEL_SCALE := 0.5  # el rig mide ~3.1 unidades → ~1.4 m (goblin petiso)
const MODEL_YAW := PI     # el rig mira a -Z; el juego marcha hacia +Z (playtest 2026-08-12)

const ANIM_WALK := "Goblin Rig|Goblin_Walk_Melee"
const ANIM_RUN := "Goblin Rig|Goblin_Run_Melee"
const ANIM_COMBAT_IDLE := "Goblin Rig|Goblin_Melee_Idle_1"
const ANIM_ATTACKS := [
	"Goblin Rig|Goblin_Melee_Attack_1", "Goblin Rig|Goblin_Melee_Attack_2",
	"Goblin Rig|Goblin_Melee_Attack_3", "Goblin Rig|Goblin_Melee_Attack_4",
]
const ANIM_HITS := [
	"Goblin Rig|Goblin_Melee_Hit_1", "Goblin Rig|Goblin_Melee_Hit_2",
	"Goblin Rig|Goblin_Melee_Hit_3",
]

## Piezas del desarme cuando hay modelo: hueso → tamaño de caja (pre-escala).
const RAGDOLL_BONES := {
	"head": ["Head", Vector3(0.55, 0.5, 0.55)],
	"torso": ["Torso", Vector3(0.8, 0.9, 0.5)],
	"arm_l": ["UpperArm.L", Vector3(0.25, 0.8, 0.25)],
	"arm_r": ["UpperArm.R", Vector3(0.25, 0.8, 0.25)],
	"leg_l": ["Thigh.L", Vector3(0.3, 1.0, 0.3)],
	"leg_r": ["Thigh.R", Vector3(0.3, 1.0, 0.3)],
}

const BASE_HP := 90.0
const BASE_DAMAGE := 12.0
const ATTACK_INTERVAL := 1.5
const ATTACK_REACH := 2.2
const HEADSHOT_MULT := 2.5
const ANIM_FPS := 12.0  # animación cuantizada del fallback (snap PS1)
const VOICE_PITCH := 1.3

static var _psx_mats: Dictionary = {}
static var _psx_mats_elite: Dictionary = {}

var max_hp := BASE_HP
var hp := BASE_HP
var speed := 1.7
var attack_damage := BASE_DAMAGE
var bounty := 10  # oro al morir (WorldState suma +5 por headshot)
var is_elite := false

var state: State = State.MARCH
var pieces: Dictionary = {}

var _door: Node3D = null
var _spawn_position := Vector3.ZERO
var _attack_offset := Vector3.ZERO  # cola distribuida a lo ancho de la Puerta
var _agent: NavigationAgent3D
var _visual: Node3D
var _size_factor := 0.85
var _model: Node3D = null
var _model_meshes: Array[MeshInstance3D] = []
var _anim: AnimationPlayer = null
var _skeleton: Skeleton3D = null
var _loop_anim := ""
var _arm_pivots: Array[Node3D] = []
var _leg_pivots: Array[Node3D] = []
var _anim_time := 0.0
var _attack_cooldown := 0.0
var _stagger := 0.0
var _retreat_timer := 0.0
var _growl_timer := 0.0
var _stuck_time := 0.0
var _stuck_strikes := 0
var _unstuck_until_ms := 0
var _knock := Vector3.ZERO  # knockback acumulado — _on_velocity_computed pisaría velocity
var _dying := false


func configure(round_number: int, elite: bool) -> void:
	is_elite = elite
	var round_mult := 1.0 + (round_number - 1) * 0.18
	max_hp = BASE_HP * round_mult * (2.4 if elite else 1.0)
	hp = max_hp
	# v3: camino ~190 m — más tranco para que el primer contacto no tarde tanto.
	speed = (1.7 if elite else randf_range(1.85, 2.35))
	attack_damage = (22.0 if elite else BASE_DAMAGE)
	bounty = (25 if elite else 10)


## Llamar después de posicionar al goblin en el mundo (guarda el punto de retirada).
func set_target(door: Node3D) -> void:
	_door = door
	_spawn_position = global_position
	_attack_offset = Vector3(randf_range(-1.5, 1.5), 0.0, randf_range(0.0, 0.8))


func _ready() -> void:
	add_to_group("enemies")
	collision_layer = 4
	collision_mask = 1 | 4
	_growl_timer = randf_range(2.0, 6.0)
	_size_factor = 0.98 if is_elite else 0.85
	# Con la Puerta destruida no hay colisión en el hueco: los que marchan se
	# plantan a "saquear" en vez de atravesar y escaparse del mapa.
	EventBus.door_destroyed.connect(_on_door_destroyed)

	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.3
	capsule.height = 1.2
	var col := CollisionShape3D.new()
	col.shape = capsule
	col.position = Vector3(0.0, 0.6, 0.0)
	add_child(col)

	_build_body()
	_build_head_hitbox()
	_build_eyes()

	_agent = NavigationAgent3D.new()
	# Avoidance suave: radio chico y pocos vecinos — en el embudo del camino,
	# un RVO agresivo los planchaba contra las paredes (playtest 2026-08-12).
	_agent.radius = 0.35
	_agent.neighbor_distance = 4.0
	_agent.max_neighbors = 6
	_agent.time_horizon_agents = 1.2
	_agent.path_desired_distance = 0.6
	_agent.target_desired_distance = 1.4
	_agent.avoidance_enabled = true
	_agent.max_speed = speed
	add_child(_agent)
	_agent.velocity_computed.connect(_on_velocity_computed)


func _physics_process(delta: float) -> void:
	if _dying:
		return
	# Los goblins no nadan: fuera del terraplén se hunden (evita que la multitud
	# empujada al agua rodee la muralla en ruinas; y empujarlos al agua con
	# explosiones es táctica legítima — cuenta el kill).
	if global_position.y < -0.35:
		_drown()
		return
	_stagger = maxf(_stagger - delta, 0.0)
	_growl_timer -= delta
	if _growl_timer <= 0.0 and state != State.RETREAT:
		_growl_timer = randf_range(3.5, 8.0)
		AudioManager.play_3d("goblin_growl", global_position, -6.0, 0.18, VOICE_PITCH)

	match state:
		State.MARCH:
			_march(delta)
		State.ATTACK:
			_attack(delta)
		State.RETREAT:
			_retreat(delta)


func _march(delta: float) -> void:
	if _door == null:
		return
	var attack_point: Vector3 = _door.get_attack_point() + _attack_offset \
		if _door.has_method("get_attack_point") else _door.global_position
	if global_position.distance_to(attack_point) < ATTACK_REACH:
		state = State.ATTACK
		_play_loop(ANIM_COMBAT_IDLE, 1.0)
		return
	# En la cola final el RVO se apaga: apretujados contra la Puerta, el
	# avoidance empujaba goblins al agua (move_and_slide los separa igual).
	_agent.avoidance_enabled = global_position.distance_to(attack_point) > 6.0
	_navigate_towards(attack_point, delta)


func _attack(delta: float) -> void:
	velocity.x = _knock.x
	velocity.z = _knock.z
	_knock = _knock.lerp(Vector3.ZERO, minf(delta * 8.0, 1.0))
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	move_and_slide()
	_attack_cooldown -= delta
	if _attack_cooldown > 0.0:
		return
	_attack_cooldown = ATTACK_INTERVAL * randf_range(0.9, 1.15)
	_do_lunge()


func _do_lunge() -> void:
	_play_once(ANIM_ATTACKS[randi() % ANIM_ATTACKS.size()], 1.25)
	var tween := create_tween()
	tween.tween_property(_visual, "position:z", 0.15, 0.1)
	tween.tween_callback(_hit_door)
	tween.tween_property(_visual, "position:z", 0.0, 0.22)


func _hit_door() -> void:
	if _dying or _door == null or not is_instance_valid(_door):
		return
	if _door.has_method("take_damage"):
		_door.take_damage(attack_damage)
	AudioManager.play_3d("goblin_attack", global_position, -4.0)


func _retreat(delta: float) -> void:
	_retreat_timer -= delta
	if _retreat_timer <= 0.0 or global_position.distance_to(_spawn_position) < 1.6:
		_dissolve_out()
		return
	_navigate_towards(_spawn_position, delta)


func _navigate_towards(target: Vector3, delta: float) -> void:
	_agent.target_position = target
	var next := _agent.get_next_path_position()
	var dir := next - global_position
	dir.y = 0.0
	dir = dir.normalized() if dir.length_squared() > 0.001 else Vector3.ZERO
	var current_speed := speed * (0.35 if _stagger > 0.0 else 1.0)
	var desired := dir * current_speed

	# Anti-atasco escalado: 1º-2º strike, bypass del avoidance + empujón;
	# 3º strike, RESCATE — snap al punto navegable más cercano (invisible en
	# la práctica y garantiza progreso; playtest 2026-08-13: algunos quedaban
	# clavados contra taludes/esquinas).
	var real_hspeed := Vector2(velocity.x, velocity.z).length()
	if desired.length() > 0.3 and real_hspeed < 0.25 and _stagger <= 0.0:
		_stuck_time += delta
		if _stuck_time > 0.7:
			_stuck_time = 0.0
			_stuck_strikes += 1
			if _stuck_strikes >= 3:
				_stuck_strikes = 0
				var nav_map := get_world_3d().navigation_map
				global_position = NavigationServer3D.map_get_closest_point(nav_map, global_position) \
					+ Vector3.UP * 0.15
			else:
				_unstuck_until_ms = Time.get_ticks_msec() + 700
				_knock += Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * 0.9
	else:
		_stuck_time = maxf(_stuck_time - delta * 2.0, 0.0)
		if real_hspeed > 0.6:
			_stuck_strikes = 0

	var bypass_avoidance := Time.get_ticks_msec() < _unstuck_until_ms
	if _agent.avoidance_enabled and not bypass_avoidance:
		_agent.set_velocity(desired)
	else:
		_on_velocity_computed(desired)
	if dir != Vector3.ZERO:
		var target_yaw := atan2(-dir.x, -dir.z) + PI
		rotation.y = lerp_angle(rotation.y, target_yaw, minf(delta * 6.0, 1.0))
	_animate_march(delta, current_speed)


func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if _dying:
		return
	velocity.x = safe_velocity.x + _knock.x
	velocity.z = safe_velocity.z + _knock.z
	if not is_on_floor():
		velocity.y -= 9.8 * get_physics_process_delta_time()
	else:
		velocity.y = 0.0
	move_and_slide()
	_knock = _knock.lerp(Vector3.ZERO, minf(get_physics_process_delta_time() * 8.0, 1.0))


func _animate_march(delta: float, current_speed: float) -> void:
	if _model != null:
		var target_anim := ANIM_RUN if speed > 2.05 else ANIM_WALK
		_play_loop(target_anim, current_speed / 1.7)
		return
	# Fallback primitivas: bob + brazos con tiempo cuantizado a 12 fps (snap PS1).
	_anim_time += delta * maxf(current_speed, 0.3) * 2.6
	var t := floorf(_anim_time * ANIM_FPS) / ANIM_FPS
	var swing := sin(t * 3.6)
	_visual.position.y = absf(swing) * 0.05
	_visual.rotation.z = swing * 0.07
	for i in _arm_pivots.size():
		_arm_pivots[i].rotation.x = -1.25 + swing * 0.18 * (1.0 if i == 0 else -1.0)
	for i in _leg_pivots.size():
		_leg_pivots[i].rotation.x = swing * 0.55 * (1.0 if i == 0 else -1.0)


# ------------------------------------------------------------------ animación (modelo)

func _play_loop(anim_name: String, anim_speed := 1.0) -> void:
	if _anim == null:
		return
	_loop_anim = anim_name
	_anim.speed_scale = anim_speed
	if _anim.current_animation != anim_name:
		_anim.play(anim_name)


func _play_once(anim_name: String, anim_speed := 1.0) -> void:
	if _anim == null or not _anim.has_animation(anim_name):
		return
	_anim.speed_scale = anim_speed
	_anim.play(anim_name)


func _on_anim_finished(_anim_name: StringName) -> void:
	if _anim != null and _loop_anim != "" and not _dying:
		_play_loop(_loop_anim, 1.0)  # restaura speed_scale (los one-shot lo dejan en 1.25+)


# ------------------------------------------------------------------ daño

func take_arrow_hit(damage: float, headshot: bool, dir: Vector3, _pos: Vector3) -> void:
	if _dying:
		return
	var final_damage := damage * (HEADSHOT_MULT if headshot else 1.0)
	hp -= final_damage
	var lethal := hp <= 0.0
	EventBus.arrow_hit.emit(lethal, headshot)
	AudioManager.play_3d("headshot" if headshot else "arrow_hit_flesh", global_position, -4.0)
	if lethal:
		_die(headshot, dir * 6.5, "head" if headshot else "torso")
		return
	# Stagger visible: cada flecha se siente aunque no mate (GDD §11.2).
	_stagger = 0.3
	_knock += Vector3(dir.x, 0.0, dir.z) * 1.8
	if _model != null:
		_play_once(ANIM_HITS[randi() % ANIM_HITS.size()], 1.3)
	else:
		var tween := create_tween()
		tween.tween_property(_visual, "rotation:x", -0.16, 0.06)
		tween.tween_property(_visual, "rotation:x", 0.0, 0.18)


func take_trap_damage(damage: float) -> void:
	if _dying:
		return
	hp -= damage
	_stagger = 0.45
	if hp <= 0.0:
		_die(false, Vector3.UP * 3.0, "torso")


func take_explosion(damage: float, from: Vector3) -> void:
	if _dying:
		return
	hp -= damage
	var dir := (global_position - from).normalized() + Vector3.UP * 0.7
	if hp <= 0.0:
		_die(false, dir.normalized() * 11.0, "torso", true)
	else:
		_stagger = 0.6
		_knock += dir.normalized() * 4.0


## Punto de la cabeza en mundo (la diana de apuntado y el tiro perfecto lo usan).
func head_position() -> Vector3:
	return global_position + Vector3.UP * 1.48 * _size_factor


func retreat() -> void:
	if _dying or state == State.RETREAT:
		return
	state = State.RETREAT
	_retreat_timer = 12.0


func _on_door_destroyed() -> void:
	if _dying or state == State.RETREAT:
		return
	state = State.ATTACK
	_play_loop(ANIM_COMBAT_IDLE, 1.0)


func _die(headshot: bool, impulse: Vector3, hit_piece: String, exploded := false) -> void:
	_dying = true
	EventBus.enemy_killed.emit(self, headshot)
	AudioManager.play_3d("goblin_death", global_position, -3.0, 0.15, VOICE_PITCH)
	if headshot:
		AudioManager.play_ui("kill_bell", -14.0)
		GameManager.do_hitstop(0.12, 0.05)
	GoblinRagdoll.spawn_from_goblin(self, impulse, hit_piece, exploded)
	queue_free()


## Piezas para el desarme (D9). Con modelo: cajas nacidas de la POSE REAL de los
## huesos (el desarme sale del gesto en que murió). Fallback: los meshes primitivos.
func ragdoll_pieces() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _skeleton != null:
		var skin_mat := _goblin_material(is_elite)
		for key in RAGDOLL_BONES:
			var bone_name: String = RAGDOLL_BONES[key][0]
			var bone_size: Vector3 = RAGDOLL_BONES[key][1]
			var idx := _skeleton.find_bone(bone_name)
			if idx < 0:
				continue
			var xform: Transform3D = _skeleton.global_transform * _skeleton.get_bone_global_pose(idx)
			var mesh := BoxMesh.new()
			mesh.size = bone_size * MODEL_SCALE * _size_factor
			result.append({"key": key, "mesh": mesh, "mat": skin_mat,
				"xform": Transform3D(xform.basis.orthonormalized(), xform.origin)})
		return result
	for key in pieces:
		var mi: MeshInstance3D = pieces[key]
		result.append({"key": key, "mesh": mi.mesh, "mat": mi.material_override,
			"xform": mi.global_transform})
	return result


func _drown() -> void:
	_dying = true
	EventBus.enemy_killed.emit(self, false)
	AudioManager.play_3d("goblin_death", global_position, -8.0, 0.2, 0.8)
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 0.9, 0.5)
	tween.parallel().tween_method(_set_dissolve, 1.0, 0.0, 0.5)
	tween.tween_callback(queue_free)


func _dissolve_out() -> void:
	_dying = true
	var tween := create_tween()
	tween.tween_method(_set_dissolve, 1.0, 0.0, 0.7)
	tween.tween_callback(queue_free)


func _set_dissolve(value: float) -> void:
	if _model != null:
		for mi in _model_meshes:
			mi.set_instance_shader_parameter("dissolve", value)
		return
	for piece_name in pieces:
		var mi: MeshInstance3D = pieces[piece_name]
		mi.set_instance_shader_parameter("dissolve", value)


# ------------------------------------------------------------------ construcción

func _build_body() -> void:
	_visual = Node3D.new()
	_visual.name = "Visual"
	add_child(_visual)
	if _try_build_model():
		return
	_build_primitive_body()


func _try_build_model() -> bool:
	if not ResourceLoader.exists(MODEL_PATH):
		return false
	var packed: PackedScene = load(MODEL_PATH)
	if packed == null:
		return false
	_model = packed.instantiate() as Node3D
	_visual.add_child(_model)
	# Sin rotación manual: las animaciones del FBX traen la orientación en sus
	# tracks (el rest pose engaña — parece Z-up, pero la anim endereza el rig).
	# Si el modelo mirara de costado/espaldas, ajustar MODEL_YAW.
	_model.rotation.y = MODEL_YAW
	_model.scale = Vector3.ONE * (MODEL_SCALE * _size_factor)

	_skeleton = null
	var skeletons := _model.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		_skeleton = skeletons.front()
	var players := _model.find_children("*", "AnimationPlayer", true, false)
	if not players.is_empty():
		_anim = players.front()
		_anim.animation_finished.connect(_on_anim_finished)
		for loop_name in [ANIM_WALK, ANIM_RUN, ANIM_COMBAT_IDLE]:
			if _anim.has_animation(loop_name):
				_anim.get_animation(loop_name).loop_mode = Animation.LOOP_LINEAR
		_play_loop(ANIM_WALK)

	_model_meshes = AssetLib.meshes_in(_model)
	var mat := _goblin_material(is_elite)
	for mi in _model_meshes:
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			mi.set_surface_override_material(s, mat)
	return true


## Material PSX del goblin (compartido por variante; el élite va tintado rojizo).
static func _goblin_material(elite: bool) -> ShaderMaterial:
	var cache := _psx_mats_elite if elite else _psx_mats
	if cache.has("mat"):
		return cache["mat"]
	var mat := ShaderMaterial.new()
	mat.shader = PSXMaterials.SHADER
	if ResourceLoader.exists(MODEL_TEXTURE):
		mat.set_shader_parameter("albedo_tex", load(MODEL_TEXTURE))
	else:
		mat.set_shader_parameter("albedo_tex",
			PSXMaterials.goblin_skin().get_shader_parameter("albedo_tex"))
	if elite:
		mat.set_shader_parameter("tint", Color(1.0, 0.5, 0.42))
	cache["mat"] = mat
	return mat


func _build_primitive_body() -> void:
	var skin := PSXMaterials.goblin_elite() if is_elite else PSXMaterials.goblin_skin()
	var cloth := PSXMaterials.cloth()
	var f := _size_factor

	pieces["torso"] = _piece(_visual, Vector3(0.5, 0.55, 0.28) * f, Vector3(0.0, 1.0, 0.0) * f, cloth)
	pieces["head"] = _piece(_visual, Vector3(0.34, 0.32, 0.34) * f, Vector3(0.0, 1.48, 0.0) * f, skin)
	var ear_l := _piece(_visual, Vector3(0.2, 0.07, 0.05) * f, Vector3(-0.25, 1.52, 0.0) * f, skin)
	ear_l.rotation.z = 0.25
	var ear_r := _piece(_visual, Vector3(0.2, 0.07, 0.05) * f, Vector3(0.25, 1.52, 0.0) * f, skin)
	ear_r.rotation.z = -0.25
	pieces["ear_l"] = ear_l
	pieces["ear_r"] = ear_r

	for side in [-1.0, 1.0]:
		var arm_pivot := Node3D.new()
		arm_pivot.position = Vector3(0.33 * side, 1.24, 0.0) * f
		_visual.add_child(arm_pivot)
		arm_pivot.rotation.x = -1.25
		_arm_pivots.append(arm_pivot)
		var arm_name := "arm_l" if side < 0.0 else "arm_r"
		pieces[arm_name] = _piece(arm_pivot, Vector3(0.13, 0.5, 0.13) * f, Vector3(0.0, -0.25, 0.0) * f, skin)

		var leg_pivot := Node3D.new()
		leg_pivot.position = Vector3(0.13 * side, 0.72, 0.0) * f
		_visual.add_child(leg_pivot)
		_leg_pivots.append(leg_pivot)
		var leg_name := "leg_l" if side < 0.0 else "leg_r"
		pieces[leg_name] = _piece(leg_pivot, Vector3(0.16, 0.7, 0.16) * f, Vector3(0.0, -0.35, 0.0) * f, cloth)


func _piece(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	parent.add_child(mi)
	return mi


static var _eye_textures: Dictionary = {}


## Ojos brillantes (capa 3 de visibilidad nocturna, playtest 2026-08-13):
## billboard unshaded a la altura de la cabeza — dos puntos que se ven venir
## entre la niebla aunque el cuerpo aún no se distinga. Élite = rojos.
func _build_eyes() -> void:
	var eyes := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(0.24, 0.1)
	eyes.mesh = quad
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.albedo_texture = _eye_texture(is_elite)
	eyes.material_override = mat
	eyes.position = Vector3(0.0, 1.5 * _size_factor, 0.0)
	add_child(eyes)


static func _eye_texture(elite: bool) -> ImageTexture:
	var key := "elite" if elite else "normal"
	if _eye_textures.has(key):
		return _eye_textures[key]
	var color := Color(1.0, 0.32, 0.2) if elite else Color(1.0, 0.85, 0.3)
	var img := Image.create(16, 8, false, Image.FORMAT_RGBA8)
	for center_x in [4, 12]:
		for y in range(2, 6):
			for x in range(center_x - 1, center_x + 2):
				img.set_pixel(x, y, color)
	var tex := ImageTexture.create_from_image(img)
	_eye_textures[key] = tex
	return tex


func _build_head_hitbox() -> void:
	var area := Area3D.new()
	area.collision_layer = 64
	area.collision_mask = 0
	area.monitoring = false
	area.set_meta("redirect_to", self)
	area.set_meta("is_head", true)
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.4, 0.38, 0.4) * _size_factor
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, 1.48, 0.0) * _size_factor
	area.add_child(col)
	add_child(area)
