class_name ForageNode
extends StaticBody3D
## Flora recolectable (F3, M4b §3): flor roja (ígnea) u hongo azul (escarcha).
## [E] da +1 material (+1 con el talento `cosecha`) y la planta se va con un
## tween — respawnea la tanda al iniciar cada ronda (ForageSystem).

var kind: StringName = &"flor"  # &"flor" | &"hongo"

var _harvested := false
var _snapped := false
var _visual: Node3D


func _ready() -> void:
	add_to_group("forage_nodes")
	collision_layer = 32  # interactuable; no bloquea el paso
	collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.7, 0.9, 0.7)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, 0.4, 0.0)
	add_child(col)
	_build_visual()


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
	if _harvested:
		return ""
	return "[E] Recoger %s" % ("flor" if kind == &"flor" else "hongo")


func interact(_player: Node) -> void:
	if _harvested:
		return
	_harvested = true
	collision_layer = 0
	var amount := 1 + int(Progression.stats.harvest_bonus)
	WorldState.add_material(kind, amount)
	EventBus.announcement.emit("+%d %s" % [amount, "flor" if kind == &"flor" else "hongo"])
	AudioManager.play_3d("ui_click", global_position, -8.0, 0.1, 1.4)
	var tween := create_tween()
	tween.tween_property(_visual, "scale", Vector3(0.05, 0.05, 0.05), 0.25)
	tween.tween_callback(queue_free)


## Cruz de 2 quads PS1 (M4b §3): lectura de color 1:1 material → flecha.
func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	_visual.rotation.y = randf() * TAU
	var color := Color(0.9, 0.3, 0.25) if kind == &"flor" else Color(0.4, 0.55, 0.95)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var stem_mat := StandardMaterial3D.new()
	stem_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	stem_mat.albedo_color = Color(0.32, 0.45, 0.24)
	stem_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in 2:
		var quad := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.34, 0.3)
		quad.mesh = mesh
		quad.position = Vector3(0.0, 0.42, 0.0)
		quad.rotation.y = PI * 0.5 * i
		quad.material_override = mat
		_visual.add_child(quad)
		var stem := MeshInstance3D.new()
		var stem_mesh := QuadMesh.new()
		stem_mesh.size = Vector2(0.06, 0.3)
		stem.mesh = stem_mesh
		stem.position = Vector3(0.0, 0.15, 0.0)
		stem.rotation.y = PI * 0.5 * i
		stem.material_override = stem_mat
		_visual.add_child(stem)
