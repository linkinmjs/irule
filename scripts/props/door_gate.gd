class_name TowerDoor
extends StaticBody3D
## La Puerta (D7): único destructible v1 y condición de derrota.
## Reparable de día con oro (D10). Visual: portón Gate_Variant_2 del pack con
## estados por tinte/inclinación (GDD §11.3); fallback de tablones primitivos.

const MAX_HP := 600.0
const REPAIR_COST := 50
const REPAIR_AMOUNT := 180.0

const WIDTH := 4.0
const HEIGHT := 3.6
const PLANK_COUNT := 6

const STAGE_TINTS := [Color(1.0, 1.0, 1.0), Color(0.82, 0.76, 0.7), Color(0.58, 0.51, 0.44)]
const STAGE_TILTS := [0.0, 0.018, 0.045]

var hp := MAX_HP

var _gate: Node3D = null
var _gate_meshes: Array[MeshInstance3D] = []
var _gate_mats: Array[ShaderMaterial] = []
var _planks: Array[MeshInstance3D] = []
var _stage := 0
var _destroyed := false
var _dropped_debris := false


func _ready() -> void:
	add_to_group("tower_door")
	collision_layer = 1 | 32  # mundo + interactuable
	collision_mask = 0
	_build_visual()

	var shape := BoxShape3D.new()
	shape.size = Vector3(WIDTH, HEIGHT, 0.3)
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, HEIGHT * 0.5, 0.0)
	add_child(col)


## Punto que los goblins atacan (lado del camino, -Z).
func get_attack_point() -> Vector3:
	return global_position + global_basis.z * -1.2


func take_damage(amount: float) -> void:
	if _destroyed:
		return
	hp = maxf(hp - amount, 0.0)
	WorldState.door_damage_tonight += amount
	AudioManager.play_3d("door_hit", global_position + Vector3.UP * 1.5, -3.0)
	EventBus.door_damaged.emit(hp, MAX_HP)
	_update_stage()
	if hp <= 0.0:
		_destroy()


## Restaura la vida guardada (save al dormir) y sincroniza el visual + HUD.
func load_hp(value: float) -> void:
	hp = clampf(value, 1.0, MAX_HP)
	_update_stage()
	EventBus.door_damaged.emit(hp, MAX_HP)


func repair(amount: float) -> void:
	if _destroyed:
		return
	hp = minf(hp + amount, MAX_HP)
	EventBus.door_repaired.emit(hp, MAX_HP)
	_update_stage()


func get_interact_prompt() -> String:
	if _destroyed:
		return ""
	if hp >= MAX_HP:
		return "La Puerta está firme"
	if not WorldState.is_day():
		return "Solo se puede reparar de día"
	return "[E] Reparar Puerta (%d oro · +%d)" % [REPAIR_COST, int(REPAIR_AMOUNT)]


func interact(_player: Node) -> void:
	if _destroyed or hp >= MAX_HP or not WorldState.is_day():
		return
	if not WorldState.try_spend_gold(REPAIR_COST):
		EventBus.announcement.emit("No te alcanza el oro")
		AudioManager.play_ui("ui_click", -6.0)
		return
	repair(REPAIR_AMOUNT)
	AudioManager.play_3d("repair", global_position + Vector3.UP * 1.5, -4.0)


func _update_stage() -> void:
	var new_stage := 0
	var frac := hp / MAX_HP
	if frac <= 0.33:
		new_stage = 2
	elif frac <= 0.66:
		new_stage = 1
	if new_stage == _stage:
		return
	var worsened := new_stage > _stage
	_stage = new_stage
	if _stage < 2:
		_dropped_debris = false
	_apply_stage_visual(worsened)
	if worsened and _stage == 2:
		EventBus.announcement.emit("¡LA PUERTA CEDE!")
		AudioManager.play_3d("alarm_bell", global_position + Vector3.UP * 3.0, -2.0)


func _apply_stage_visual(worsened: bool) -> void:
	if _gate != null:
		for mat in _gate_mats:
			mat.set_shader_parameter("tint", STAGE_TINTS[_stage])
		_gate.rotation.z = STAGE_TILTS[_stage]
		if _stage == 2 and worsened and not _dropped_debris:
			_dropped_debris = true
			_drop_wood_debris(2)
		return
	# Fallback de tablones primitivos.
	for i in _planks.size():
		var plank := _planks[i]
		match _stage:
			0:
				plank.visible = true
				plank.rotation.z = 0.0
			1:
				plank.visible = true
				plank.rotation.z = 0.045 * (1 if i % 2 == 0 else -1) * float(i % 3)
			2:
				var dropped := i == 1 or i == 4
				if dropped and plank.visible and worsened:
					VFX.drop_debris(get_tree().current_scene, plank.mesh, plank.material_override,
						plank.global_transform, Vector3(randf_range(-0.5, 0.5), 0.6, -1.5))
				plank.visible = not dropped
				if not dropped:
					plank.rotation.z = 0.07 * (1 if i % 2 == 0 else -1)


func _destroy() -> void:
	_destroyed = true
	AudioManager.play_3d("door_break", global_position + Vector3.UP * 1.5, 2.0)
	if _gate != null:
		var tween := create_tween()
		tween.tween_method(_set_gate_dissolve, 1.0, 0.0, 0.6)
		tween.tween_callback(_gate.hide)
		_drop_wood_debris(5)
	else:
		for plank in _planks:
			if plank.visible:
				plank.visible = false
				VFX.drop_debris(get_tree().current_scene, plank.mesh, plank.material_override,
					plank.global_transform, Vector3(randf_range(-1.0, 1.0), randf_range(0.5, 1.5), 2.0))
	VFX.dust_puff(get_tree().current_scene, global_position + Vector3.UP * 1.2)
	set_deferred("collision_layer", 0)
	EventBus.door_destroyed.emit()


func _set_gate_dissolve(value: float) -> void:
	for mesh_instance in _gate_meshes:
		mesh_instance.set_instance_shader_parameter("dissolve", value)


func _drop_wood_debris(count: int) -> void:
	for i in count:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(randf_range(0.3, 0.6), randf_range(0.15, 0.3), 0.12)
		var xform := global_transform.translated_local(
			Vector3(randf_range(-1.4, 1.4), randf_range(0.8, 2.6), 0.0))
		VFX.drop_debris(get_tree().current_scene, mesh, PSXMaterials.wood(),
			xform, Vector3(randf_range(-0.8, 0.8), randf_range(0.4, 1.2), randf_range(-1.8, -0.6)))


func _build_visual() -> void:
	_gate = AssetLib.piece("Gate_Variant_2", true)
	if _gate != null:
		add_child(_gate)
		for mesh_instance in AssetLib.meshes_in(_gate):
			_gate_meshes.append(mesh_instance)
			if mesh_instance.mesh == null:
				continue
			for s in mesh_instance.mesh.get_surface_count():
				var mat := mesh_instance.get_surface_override_material(s)
				if mat is ShaderMaterial:
					_gate_mats.append(mat)
		return
	# Fallback: tablones primitivos.
	var wood := PSXMaterials.wood()
	var wood_dark := PSXMaterials.wood_dark()
	var plank_width := WIDTH / PLANK_COUNT
	for i in PLANK_COUNT:
		var plank := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(plank_width - 0.04, HEIGHT - 0.1, 0.18)
		plank.mesh = mesh
		plank.position = Vector3(-WIDTH * 0.5 + plank_width * (i + 0.5), HEIGHT * 0.5, 0.0)
		plank.material_override = wood
		add_child(plank)
		_planks.append(plank)
	for y in [1.0, 2.6]:
		var beam := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(WIDTH - 0.1, 0.3, 0.24)
		beam.mesh = mesh
		beam.position = Vector3(0.0, y, 0.06)
		beam.material_override = wood_dark
		add_child(beam)
