class_name SpikeTrap
extends Area3D
## Pinchos (D8, GDD §6.1): daño leve por pisada; se desgastan y se hunden.

const DAMAGE := 9.0
const MAX_USES := 25

var uses := MAX_USES

var _spikes: Array[MeshInstance3D] = []
var _asset_visual: Node3D = null
var _spent := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 4  # solo enemigos
	monitoring = true
	body_entered.connect(_on_body_entered)

	var shape := BoxShape3D.new()
	shape.size = Vector3(1.8, 0.5, 1.3)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, 0.25, 0.0)
	add_child(col)
	_build_visual()


func _on_body_entered(body: Node3D) -> void:
	if _spent or not body.has_method("take_trap_damage"):
		return
	body.take_trap_damage(DAMAGE)
	AudioManager.play_3d("spikes", global_position, -6.0)
	uses -= 1
	if uses <= 0:
		_wear_out()


func _wear_out() -> void:
	_spent = true
	set_deferred("monitoring", false)
	var tween := create_tween()
	if _asset_visual != null:
		tween.tween_property(_asset_visual, "position:y", -0.55, 0.5)
		return
	for spike in _spikes:
		tween.parallel().tween_property(spike, "position:y", spike.position.y - 0.2, 0.5)


func _build_visual() -> void:
	_asset_visual = AssetLib.piece("Spikes_2")
	if _asset_visual != null:
		add_child(_asset_visual)
		return
	var base := MeshInstance3D.new()
	var base_mesh := BoxMesh.new()
	base_mesh.size = Vector3(1.8, 0.08, 1.3)
	base.mesh = base_mesh
	base.position = Vector3(0.0, 0.04, 0.0)
	base.material_override = PSXMaterials.metal()
	add_child(base)
	var metal := PSXMaterials.metal()
	for ix in 5:
		for iz in 4:
			var spike := MeshInstance3D.new()
			var mesh := PrismMesh.new()
			mesh.size = Vector3(0.13, 0.26, 0.13)
			spike.mesh = mesh
			spike.position = Vector3(
				-0.72 + ix * 0.36 + randf_range(-0.03, 0.03),
				0.21,
				-0.48 + iz * 0.32 + randf_range(-0.03, 0.03)
			)
			spike.material_override = metal
			add_child(spike)
			_spikes.append(spike)
