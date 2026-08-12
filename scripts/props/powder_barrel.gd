class_name PowderBarrel
extends StaticBody3D
## Barril de pólvora (D8, GDD §6.1): inerte hasta que le disparás.
## Explota en área, empuja ragdolls y encadena con otros barriles.

const DAMAGE := 95.0
const RADIUS := 3.4
const CHAIN_DELAY := 0.13

var _exploded := false


func _ready() -> void:
	add_to_group("barrels")
	collision_layer = 1 | 128  # sólido para goblins + destructible por flechas
	collision_mask = 0
	var used_asset := _build_visual_asset()
	if not used_asset:
		_build_visual()
	var shape := CylinderShape3D.new()
	shape.radius = 0.48 if used_asset else 0.34
	shape.height = 1.05 if used_asset else 0.8
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0.0, shape.height * 0.5, 0.0)
	add_child(col)


func _build_visual_asset() -> bool:
	var asset := AssetLib.piece("Barrel_1")
	if asset == null:
		return false
	add_child(asset)
	return true


func take_arrow_hit(_damage: float, _headshot: bool, _dir: Vector3, _pos: Vector3) -> void:
	explode()


func explode() -> void:
	if _exploded:
		return
	_exploded = true
	var scene := get_tree().current_scene
	var center := global_position + Vector3.UP * 0.4

	AudioManager.play_3d("barrel_explode", center, 4.0)
	VFX.explosion(scene, center)

	# Screenshake según distancia (GDD §11.1: reservado a explosiones).
	var player: Node = get_tree().get_first_node_in_group("player")
	if player != null and player.has_method("camera_shake"):
		var dist: float = (player as Node3D).global_position.distance_to(center)
		player.camera_shake(clampf(1.1 - dist / 14.0, 0.15, 1.0))

	# Daño a enemigos con leve falloff.
	var victims := 0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_3d := enemy as Node3D
		if enemy_3d == null:
			continue
		var dist := enemy_3d.global_position.distance_to(center)
		if dist > RADIUS:
			continue
		victims += 1
		if enemy.has_method("take_explosion"):
			enemy.take_explosion(DAMAGE * (1.0 - (dist / RADIUS) * 0.55), center)

	# Los ragdolls existentes vuelan (GDD §6.1).
	for debris in get_tree().get_nodes_in_group("ragdoll_debris"):
		var body := debris as RigidBody3D
		if body == null:
			continue
		var dist := body.global_position.distance_to(center)
		if dist > RADIUS + 1.0:
			continue
		var dir := (body.global_position - center).normalized() + Vector3.UP * 0.6
		body.apply_central_impulse(dir.normalized() * 8.0 * body.mass)

	if victims > 0:
		GameManager.do_hitstop(0.18, 0.04)

	# Reacción en cadena.
	for barrel in get_tree().get_nodes_in_group("barrels"):
		if barrel == self or not barrel is PowderBarrel:
			continue
		var other := barrel as PowderBarrel
		if other.global_position.distance_to(center) <= RADIUS:
			# process_always=false: la cadena no explota durante la pausa.
			get_tree().create_timer(CHAIN_DELAY, false).timeout.connect(func() -> void:
				if is_instance_valid(other):
					other.explode())

	queue_free()


func _build_visual() -> void:
	var body := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.3
	mesh.bottom_radius = 0.32
	mesh.height = 0.8
	body.mesh = mesh
	body.position = Vector3(0.0, 0.4, 0.0)
	body.material_override = PSXMaterials.wood_dark()
	add_child(body)
	for y in [0.18, 0.62]:
		var ring := MeshInstance3D.new()
		var ring_mesh := CylinderMesh.new()
		ring_mesh.top_radius = 0.335
		ring_mesh.bottom_radius = 0.335
		ring_mesh.height = 0.07
		ring.mesh = ring_mesh
		ring.position = Vector3(0.0, y, 0.0)
		ring.material_override = PSXMaterials.metal()
		add_child(ring)
