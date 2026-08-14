class_name WizardVisitor
extends StaticBody3D
## El mago Calcu (D17): visitante de las rondas especiales (cada 5). Aparece en
## la isla durante la PREP, conversa con [E] línea por línea y al final deja un
## regalo — después se disuelve y no vuelve hasta la próxima visita.
## Modelo: assets/models/packs/calcu (calcuu.fbx); fallback de primitivas.

const MODEL_PATH := "res://assets/models/packs/calcu/calcuu.fbx"
const MODEL_TEXTURE := "res://assets/models/packs/calcu/calcu-texture.png"
const TARGET_HEIGHT := 1.9  # el FBX viene en escala desconocida: auto-fit por AABB

const LINES := [
	"Calcu: Ah, el arquero del Portón. Las islas hablan de vos.",
	"Calcu: Crucé la bruma para verte. Lo que empuja a los goblins… también me busca a mí.",
	"Calcu: Tomá. No es caridad — es inversión. Los muertos no pagan deudas.",
]

var visit_round := 0  # ronda en la que apareció (semilla del regalo)

var _line_index := 0
var _leaving := false
var _snapped := false
var _visual: Node3D
var _model_meshes: Array[MeshInstance3D] = []


func _ready() -> void:
	collision_layer = 1 | 32  # mundo + interactuable
	collision_mask = 0
	_build_visual()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.45
	shape.height = 1.9
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, 0.95, 0.0)
	add_child(col)


## Asentar sobre el terreno en el primer frame físico (spawn con y alto).
func _physics_process(_delta: float) -> void:
	if _snapped:
		set_physics_process(false)
		return
	_snapped = true
	var query := PhysicsRayQueryParameters3D.create(
		global_position + Vector3.UP * 6.0, global_position + Vector3.DOWN * 30.0, 1)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit["position"]


func get_interact_prompt() -> String:
	if _leaving:
		return ""
	return "[E] Hablar con el mago"


func interact(player: Node) -> void:
	if _leaving:
		return
	# Mirar a quien le habla.
	if player is Node3D:
		var flat := (player as Node3D).global_position - global_position
		flat.y = 0.0
		if flat.length_squared() > 0.01:
			_visual.rotation.y = atan2(flat.x, flat.z)
	if _line_index < LINES.size():
		EventBus.announcement.emit(LINES[_line_index])
		AudioManager.play_ui("ui_click", -10.0)
		_line_index += 1
	if _line_index >= LINES.size():
		_give_gift()
		_leave()


## Regalo determinista por ronda de visita: oro, flechas o un punto de talento.
func _give_gift() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9000 + visit_round * 97
	match rng.randi() % 3:
		0:
			var gold := 60 + visit_round * 8
			WorldState.add_gold(gold)
			EventBus.announcement.emit("El mago te deja %d de oro" % gold)
		1:
			WorldState.add_ammo(&"normal", 20)
			EventBus.announcement.emit("El mago rellena tu carcaj (+20 flechas)")
		2:
			Progression.grant_points(1)
			EventBus.announcement.emit("El mago te enseña un truco (+1 punto de talento — [T])")


func _leave() -> void:
	_leaving = true
	collision_layer = 1  # deja de ser interactuable mientras se despide
	var tween := create_tween()
	tween.tween_interval(2.5)
	tween.tween_callback(func() -> void:
		AudioManager.play_3d("ui_click", global_position, -8.0, 0.1, 0.6))
	tween.tween_method(_set_dissolve, 1.0, 0.0, 1.2)
	tween.tween_callback(queue_free)


func _set_dissolve(value: float) -> void:
	for mi in _model_meshes:
		mi.set_instance_shader_parameter("dissolve", value)


func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	if _try_build_model():
		return
	# Fallback: mago de primitivas (túnica violeta, sombrero en punta).
	var robe := PSXMaterials.cloth()
	_piece(Vector3(0.55, 1.15, 0.42), Vector3(0.0, 0.62, 0.0), robe)
	_piece(Vector3(0.3, 0.3, 0.3), Vector3(0.0, 1.4, 0.0), robe)
	_piece(Vector3(0.42, 0.08, 0.42), Vector3(0.0, 1.58, 0.0), robe)
	_piece(Vector3(0.2, 0.35, 0.2), Vector3(0.0, 1.78, 0.0), robe)
	_piece(Vector3(0.07, 1.5, 0.07), Vector3(0.38, 0.78, 0.05), PSXMaterials.wood_dark())


func _try_build_model() -> bool:
	if not ResourceLoader.exists(MODEL_PATH):
		return false
	var packed: PackedScene = load(MODEL_PATH)
	if packed == null:
		return false
	var model := packed.instantiate() as Node3D
	_visual.add_child(model)
	_model_meshes = AssetLib.meshes_in(model)
	# Auto-fit por AABB (lección del arco: nunca confiar en la escala del FBX).
	var aabb := AABB()
	var first := true
	for mi in _model_meshes:
		if mi.mesh == null:
			continue
		var mesh_aabb: AABB = mi.global_transform * mi.mesh.get_aabb() if mi.is_inside_tree() \
			else mi.transform * mi.mesh.get_aabb()
		aabb = mesh_aabb if first else aabb.merge(mesh_aabb)
		first = false
	if not first and aabb.size.y > 0.01:
		var s := TARGET_HEIGHT / aabb.size.y
		model.scale = Vector3.ONE * s
		model.position.y = -aabb.position.y * s
	var mat := ShaderMaterial.new()
	mat.shader = PSXMaterials.SHADER
	if ResourceLoader.exists(MODEL_TEXTURE):
		mat.set_shader_parameter("albedo_tex", load(MODEL_TEXTURE))
	for mi in _model_meshes:
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			mi.set_surface_override_material(s, mat)
	return true


func _piece(size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = mat
	_visual.add_child(mi)
	_model_meshes.append(mi)
