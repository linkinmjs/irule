class_name Bow
extends Node3D
## Viewmodel del arco: sway por mouse, bob por velocidad, animación de draw y kick.
## Usa el arco compuesto del pack de armas (FBX en escala cm → MODEL_SCALE);
## fallback a primitivas si falta. Las manos llegan con el pack de arms.

const MODEL_PATH := "res://assets/models/packs/weapons/bows/compositebow_01.fbx"
const MODEL_TEXTURE := "res://assets/models/packs/weapons/bows/compositebow_tex.png"
## Alto objetivo del arco en mano (m). La escala se AUTOCALCULA midiendo el AABB
## real del modelo y el pivot se recentra (el FBX venía con pivot desplazado:
## escalarlo a ciegas lo mandaba arriba de la cámara — playtest 2026-08-12).
const MODEL_TARGET_HEIGHT := 1.0
## Orientación del modelo, compuesta por pasos (los eulers a ciegas ya nos
## costaron dos iteraciones): la base deja el arco acostado DE FRENTE a la
## cámara (playtest 2026-08-13); el roll de 90° alrededor del eje de visión
## lo para. Si quedara torcido, ajustar solo ROLL_FIX.
const ROLL_FIX := PI * 0.5


static func _model_basis() -> Basis:
	var base := Basis.from_euler(Vector3(-PI * 0.5, PI * 0.5, 0.0))
	return Basis(Vector3(0.0, 0.0, 1.0), ROLL_FIX) * base

const REST_POS := Vector3(0.34, -0.3, -0.62)
const DRAW_POS := Vector3(0.2, -0.26, -0.5)
const SWAY_AMOUNT := 0.0009
const SWAY_RECOVER := 9.0
const BOB_FREQ := 9.0
const BOB_AMOUNT := 0.014

var _player: Player
var _sway := Vector2.ZERO
var _bob_time := 0.0
var _draw := 0.0
var _kick := 0.0
var _nocked_arrow: Node3D


func setup(player: Player) -> void:
	_player = player


func _ready() -> void:
	position = REST_POS
	_build_viewmodel()


func _process(delta: float) -> void:
	_sway = _sway.lerp(Vector2.ZERO, minf(delta * SWAY_RECOVER, 1.0))
	_kick = lerpf(_kick, 0.0, minf(delta * 9.0, 1.0))

	var hspeed := 0.0
	if _player != null:
		hspeed = Vector3(_player.velocity.x, 0.0, _player.velocity.z).length()
	var speed_frac := clampf(hspeed / Player.WALK_SPEED, 0.0, 1.0)
	if speed_frac > 0.05 and _player.is_on_floor():
		_bob_time += delta * BOB_FREQ * maxf(speed_frac, 0.4)

	var bob := Vector3(
		sin(_bob_time) * BOB_AMOUNT * speed_frac,
		-absf(cos(_bob_time)) * BOB_AMOUNT * 0.8 * speed_frac,
		0.0
	)
	var base := REST_POS.lerp(DRAW_POS, _draw)
	position = base + bob + Vector3(_sway.x, _sway.y, _kick)
	rotation.z = _sway.x * 2.0
	rotation.x = _sway.y * 1.5

	if _nocked_arrow != null:
		_nocked_arrow.position.z = -0.12 + _draw * 0.2
		_nocked_arrow.visible = _player == null or _player.has_ammo()


func add_sway(mouse_relative: Vector2) -> void:
	_sway.x = clampf(_sway.x - mouse_relative.x * SWAY_AMOUNT, -0.03, 0.03)
	_sway.y = clampf(_sway.y + mouse_relative.y * SWAY_AMOUNT, -0.03, 0.03)


func set_draw(charge: float) -> void:
	_draw = charge


func on_draw_start() -> void:
	_draw = 0.0


func on_shoot() -> void:
	_draw = 0.0
	_kick = 0.09


func _build_viewmodel() -> void:
	if _try_build_model():
		_build_nocked_arrow()
		return
	_build_primitive_bow()
	_build_nocked_arrow()


func _try_build_model() -> bool:
	if not ResourceLoader.exists(MODEL_PATH):
		return false
	var packed: PackedScene = load(MODEL_PATH)
	if packed == null:
		return false
	var model := packed.instantiate() as Node3D
	add_child(model)

	# Medir el AABB real combinado (en espacio local del modelo) → escala
	# exacta al alto objetivo, y recentrado del pivot al origen del wrapper.
	var combined := AABB()
	var first := true
	for mi in AssetLib.meshes_in(model):
		if mi.mesh == null:
			continue
		var inv := model.global_transform.affine_inverse()
		var ab: AABB = (inv * mi.global_transform) * mi.get_aabb()
		combined = ab if first else combined.merge(ab)
		first = false
	if first:
		model.queue_free()
		return false
	var max_dim := maxf(combined.size.x, maxf(combined.size.y, combined.size.z))
	if max_dim < 0.0001:
		model.queue_free()
		return false
	var auto_scale := MODEL_TARGET_HEIGHT / max_dim
	var oriented := _model_basis()
	model.transform = Transform3D(
		oriented.scaled(Vector3.ONE * auto_scale),
		-(oriented * (combined.get_center() * auto_scale)))
	# La textura se asigna a mano (el png fue renombrado y el FBX no la enlaza).
	var albedo: Texture2D = load(MODEL_TEXTURE) if ResourceLoader.exists(MODEL_TEXTURE) else null
	for mi in AssetLib.meshes_in(model):
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var psx := ShaderMaterial.new()
			psx.shader = PSXMaterials.SHADER
			if albedo != null:
				psx.set_shader_parameter("albedo_tex", albedo)
			else:
				psx.set_shader_parameter("albedo_tex",
					PSXMaterials.wood_dark().get_shader_parameter("albedo_tex"))
			mi.set_surface_override_material(s, psx)
	return true


func _build_primitive_bow() -> void:
	var wood := PSXMaterials.wood_dark()
	# Cuerpo del arco (riser) + palas. El arco curva ALEJÁNDOSE del arquero
	# (-Z) y las puntas vuelven hacia él: la cuerda queda del lado de la cámara
	# (+Z). (Fix playtest 2026-08-11: estaba invertido.)
	_add_box(Vector3(0.03, 0.22, 0.04), Vector3.ZERO, wood)
	var upper := _add_box(Vector3(0.025, 0.3, 0.03), Vector3(0.0, 0.24, -0.02), wood)
	upper.rotation.x = 0.35
	var lower := _add_box(Vector3(0.025, 0.3, 0.03), Vector3(0.0, -0.24, -0.02), wood)
	lower.rotation.x = -0.35
	# Cuerda tensada entre las puntas, del lado del arquero.
	var string_mat := PSXMaterials.cloth()
	var s1 := _add_box(Vector3(0.006, 0.34, 0.006), Vector3(0.0, 0.19, 0.06), string_mat)
	s1.rotation.x = -0.3
	var s2 := _add_box(Vector3(0.006, 0.34, 0.006), Vector3(0.0, -0.19, 0.06), string_mat)
	s2.rotation.x = 0.3


func _build_nocked_arrow() -> void:
	_nocked_arrow = Node3D.new()
	add_child(_nocked_arrow)
	_nocked_arrow.position = Vector3(0.0, 0.0, -0.12)
	var shaft := MeshInstance3D.new()
	var shaft_mesh := BoxMesh.new()
	shaft_mesh.size = Vector3(0.014, 0.014, 0.5)
	shaft.mesh = shaft_mesh
	shaft.material_override = PSXMaterials.wood()
	_nocked_arrow.add_child(shaft)
	var tip := MeshInstance3D.new()
	var tip_mesh := BoxMesh.new()
	tip_mesh.size = Vector3(0.02, 0.02, 0.05)
	tip.mesh = tip_mesh
	tip.position = Vector3(0.0, 0.0, -0.27)
	tip.material_override = PSXMaterials.metal()
	_nocked_arrow.add_child(tip)


func _add_box(size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	add_child(mi)
	return mi
