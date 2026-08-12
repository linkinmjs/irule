class_name GoblinRagdoll
extends RigidBody3D
## Una pieza del "desarme" (D9, GDD §11.2). El impulso del golpe letal se hereda
## en la pieza impactada; tras unos segundos la pieza se disuelve con dithering.
## Presupuesto: MAX_PIECES en escena; al exceder, las más viejas se disuelven antes.

const LIFE_BEFORE_DISSOLVE := 3.2
const DISSOLVE_TIME := 0.8
const MAX_PIECES := 32  # ~4 goblins desarmados a la vez (8 piezas c/u)

var _mesh_instance: MeshInstance3D
var _dissolving := false


static func spawn_from_goblin(goblin: Goblin, impulse: Vector3, hit_piece: String, exploded := false) -> void:
	var parent := goblin.get_tree().current_scene
	if parent == null:
		return
	for data in goblin.ragdoll_pieces():
		var piece := GoblinRagdoll.new()
		piece._setup(data["mesh"], data["mat"])
		parent.add_child(piece)
		piece.global_transform = data["xform"]
		piece.linear_velocity = goblin.velocity * 0.5

		var final_impulse: Vector3
		if exploded:
			final_impulse = impulse * randf_range(0.7, 1.25) \
				+ Vector3(randf_range(-1.0, 1.0), randf_range(0.4, 1.4), randf_range(-1.0, 1.0)) * 3.0
		elif data["key"] == hit_piece:
			final_impulse = impulse * 1.6
		else:
			final_impulse = impulse * 0.35 \
				+ Vector3(randf_range(-0.7, 0.7), randf_range(0.2, 0.9), randf_range(-0.7, 0.7))
		piece.apply_central_impulse(final_impulse * piece.mass)
		piece.angular_velocity = Vector3(
			randf_range(-7.0, 7.0), randf_range(-7.0, 7.0), randf_range(-7.0, 7.0))
	_enforce_cap(parent.get_tree())


static func _enforce_cap(tree: SceneTree) -> void:
	var debris := tree.get_nodes_in_group("ragdoll_debris")
	var excess := debris.size() - MAX_PIECES
	for i in excess:
		var oldest: GoblinRagdoll = debris[i]
		oldest.dissolve_now()


func _setup(mesh: Mesh, mat: Material) -> void:
	add_to_group("ragdoll_debris")
	collision_layer = 16
	collision_mask = 1 | 16
	var size := Vector3(0.2, 0.2, 0.2)
	if mesh is BoxMesh:
		size = (mesh as BoxMesh).size
	mass = clampf(size.x * size.y * size.z * 45.0, 0.6, 7.0)
	var shape := BoxShape3D.new()
	shape.size = size * 0.9
	var col := CollisionShape3D.new()
	col.shape = shape
	add_child(col)
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = mesh
	_mesh_instance.material_override = mat
	add_child(_mesh_instance)


func _ready() -> void:
	var timer := Timer.new()
	timer.wait_time = LIFE_BEFORE_DISSOLVE + randf_range(0.0, 0.6)
	timer.one_shot = true
	timer.autostart = true
	add_child(timer)
	timer.timeout.connect(dissolve_now)


func dissolve_now() -> void:
	if _dissolving:
		return
	_dissolving = true
	var tween := create_tween()
	tween.tween_method(_set_dissolve, 1.0, 0.0, DISSOLVE_TIME)
	tween.tween_callback(queue_free)


func _set_dissolve(value: float) -> void:
	if _mesh_instance != null:
		_mesh_instance.set_instance_shader_parameter("dissolve", value)
