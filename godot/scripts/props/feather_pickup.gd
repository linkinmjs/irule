class_name FeatherPickup
extends StaticBody3D
## Plumas caídas (F5): las deja un pájaro cazado. [E] recoge 1-2 (+cosecha).
## Duran 10 s en el piso — apurate antes de que el viento se las lleve.

const LIFETIME := 10.0

var _taken := false
var _visual: Node3D


func _ready() -> void:
	collision_layer = 32
	collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.7, 0.5, 0.7)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, 0.2, 0.0)
	add_child(col)
	_build_visual()
	var tween := create_tween()
	tween.tween_interval(LIFETIME - 1.5)
	tween.tween_property(_visual, "scale", Vector3(0.05, 0.05, 0.05), 1.5)
	tween.tween_callback(queue_free)


func get_interact_prompt() -> String:
	if _taken:
		return ""
	return "[E] Juntar plumas"


func interact(_player: Node) -> void:
	if _taken:
		return
	_taken = true
	collision_layer = 0
	var amount := randi_range(1, 2) + int(Progression.stats.harvest_bonus)
	WorldState.add_material(&"pluma", amount)
	EventBus.announcement.emit("+%d pluma%s" % [amount, "" if amount == 1 else "s"])
	AudioManager.play_3d("ui_click", global_position, -8.0, 0.1, 1.6)
	var tween := create_tween()
	tween.tween_property(_visual, "scale", Vector3(0.05, 0.05, 0.05), 0.2)
	tween.tween_callback(queue_free)


## Tres plumitas de quad clavadas en ángulos distintos.
func _build_visual() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.88, 0.86, 0.8)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in 3:
		var quad := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.09, 0.26)
		quad.mesh = mesh
		quad.position = Vector3(randf_range(-0.2, 0.2), 0.1, randf_range(-0.2, 0.2))
		quad.rotation = Vector3(randf_range(-0.5, 0.2), randf() * TAU, randf_range(-0.3, 0.3))
		quad.material_override = mat
		_visual.add_child(quad)
