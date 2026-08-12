class_name TrainingDummy
extends StaticBody3D
## Muñeco de práctica (M1): valida el gunfeel sin enemigos. No muere; se tambalea.

var _wobble_tween: Tween


func _ready() -> void:
	collision_layer = 128
	collision_mask = 0
	_build_visual()
	var shape := CapsuleShape3D.new()
	shape.radius = 0.3
	shape.height = 1.3
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, 0.85, 0.0)
	add_child(col)

	var head_area := Area3D.new()
	head_area.collision_layer = 64
	head_area.collision_mask = 0
	head_area.monitoring = false
	head_area.set_meta("redirect_to", self)
	head_area.set_meta("is_head", true)
	var head_shape := BoxShape3D.new()
	head_shape.size = Vector3(0.32, 0.32, 0.32)
	var head_col := CollisionShape3D.new()
	head_col.shape = head_shape
	head_col.position = Vector3(0.0, 1.62, 0.0)
	head_area.add_child(head_col)
	add_child(head_area)


func take_arrow_hit(_damage: float, headshot: bool, dir: Vector3, _pos: Vector3) -> void:
	EventBus.arrow_hit.emit(false, headshot)
	AudioManager.play_3d("headshot" if headshot else "arrow_hit_flesh", global_position, -6.0)
	if _wobble_tween != null and _wobble_tween.is_running():
		_wobble_tween.kill()
	var lean := Vector3(dir.x, 0.0, dir.z).normalized() * 0.12
	_wobble_tween = create_tween()
	_wobble_tween.tween_property(self, "rotation:x", lean.z, 0.06)
	_wobble_tween.parallel().tween_property(self, "rotation:z", -lean.x, 0.06)
	_wobble_tween.tween_property(self, "rotation:x", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	_wobble_tween.parallel().tween_property(self, "rotation:z", 0.0, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _build_visual() -> void:
	var pole := MeshInstance3D.new()
	var pole_mesh := BoxMesh.new()
	pole_mesh.size = Vector3(0.1, 1.7, 0.1)
	pole.mesh = pole_mesh
	pole.position = Vector3(0.0, 0.85, 0.0)
	pole.material_override = PSXMaterials.wood_dark()
	add_child(pole)
	var cross := MeshInstance3D.new()
	var cross_mesh := BoxMesh.new()
	cross_mesh.size = Vector3(1.0, 0.09, 0.09)
	cross.mesh = cross_mesh
	cross.position = Vector3(0.0, 1.25, 0.0)
	cross.material_override = PSXMaterials.wood_dark()
	add_child(cross)
	var torso := MeshInstance3D.new()
	var torso_mesh := BoxMesh.new()
	torso_mesh.size = Vector3(0.5, 0.7, 0.3)
	torso.mesh = torso_mesh
	torso.position = Vector3(0.0, 1.05, 0.0)
	torso.material_override = PSXMaterials.cloth()
	add_child(torso)
	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.28, 0.28, 0.28)
	head.mesh = head_mesh
	head.position = Vector3(0.0, 1.62, 0.0)
	head.material_override = PSXMaterials.straw()
	add_child(head)
