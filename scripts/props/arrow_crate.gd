class_name ArrowCrate
extends StaticBody3D
## Cajón de flechas: repone el carcaj. Gratis en la maqueta; en M4 se conecta
## a la economía (GDD §6: munición finita que se compra/produce).

func _ready() -> void:
	collision_layer = 1 | 32
	collision_mask = 0
	_build_visual()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.85, 0.8, 0.85)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, 0.4, 0.0)
	add_child(col)


func get_interact_prompt() -> String:
	return "[E] Reponer flechas"


func interact(player: Node) -> void:
	if player.has_method("refill_arrows"):
		player.refill_arrows()
		AudioManager.play_ui("repair", -8.0)


func _build_visual() -> void:
	var arrows_base_y := 0.75
	var asset := AssetLib.piece("Box_3")
	if asset != null:
		add_child(asset)
		arrows_base_y = float(asset.get_meta("height", 1.0)) + 0.2
	else:
		var box := MeshInstance3D.new()
		var box_mesh := BoxMesh.new()
		box_mesh.size = Vector3(0.8, 0.55, 0.8)
		box.mesh = box_mesh
		box.position = Vector3(0.0, 0.275, 0.0)
		box.material_override = PSXMaterials.wood()
		add_child(box)
	# Flechas asomando: la lectura de "acá se recarga" no depende del asset.
	for i in 7:
		var shaft := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.02, 0.6, 0.02)
		shaft.mesh = mesh
		shaft.position = Vector3(randf_range(-0.25, 0.25), arrows_base_y, randf_range(-0.25, 0.25))
		shaft.rotation = Vector3(randf_range(-0.12, 0.12), 0.0, randf_range(-0.12, 0.12))
		shaft.material_override = PSXMaterials.wood_dark()
		add_child(shaft)
