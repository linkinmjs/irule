class_name Bed
extends StaticBody3D
## La cama: único modo de terminar el día (GDD §4.1, §5.3).

func _ready() -> void:
	collision_layer = 1 | 32
	collision_mask = 0
	_build_visual()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.1, 0.6, 2.1)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, 0.3, 0.0)
	add_child(col)


func get_interact_prompt() -> String:
	if GameManager.can_sleep():
		return "[E] Dormir hasta el amanecer"
	return "Los muertos todavía caminan…"


func interact(_player: Node) -> void:
	if GameManager.can_sleep():
		GameManager.request_sleep()
	else:
		AudioManager.play_ui("ui_click", -8.0)


func _build_visual() -> void:
	var asset := AssetLib.piece("Bed_1")
	if asset != null:
		add_child(asset)
		return
	var frame := MeshInstance3D.new()
	var frame_mesh := BoxMesh.new()
	frame_mesh.size = Vector3(1.0, 0.28, 2.0)
	frame.mesh = frame_mesh
	frame.position = Vector3(0.0, 0.14, 0.0)
	frame.material_override = PSXMaterials.wood_dark()
	add_child(frame)
	var mattress := MeshInstance3D.new()
	var mattress_mesh := BoxMesh.new()
	mattress_mesh.size = Vector3(0.9, 0.16, 1.85)
	mattress.mesh = mattress_mesh
	mattress.position = Vector3(0.0, 0.36, 0.0)
	mattress.material_override = PSXMaterials.straw()
	add_child(mattress)
	var pillow := MeshInstance3D.new()
	var pillow_mesh := BoxMesh.new()
	pillow_mesh.size = Vector3(0.5, 0.12, 0.32)
	pillow.mesh = pillow_mesh
	pillow.position = Vector3(0.0, 0.5, -0.7)
	pillow.material_override = PSXMaterials.cloth()
	add_child(pillow)
	var headboard := MeshInstance3D.new()
	var hb_mesh := BoxMesh.new()
	hb_mesh.size = Vector3(1.0, 0.7, 0.08)
	headboard.mesh = hb_mesh
	headboard.position = Vector3(0.0, 0.5, -1.0)
	headboard.material_override = PSXMaterials.wood_dark()
	add_child(headboard)
