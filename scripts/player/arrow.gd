class_name Arrow
extends Node3D
## Proyectil con caída (D5). Raycast por frame contra el trayecto → sin tunneling.
## Al impactar deja el visual clavado en el objetivo (los zombies la llevan puesta).

# Balística v2 (docs/design/guia-de-tiro.md): unificada con la gravedad del
# player (antes 9.8, caía MENOS que el mundo → floaty). Knob "arquero puro": 15.
const GRAVITY := 13.0
const LIFETIME := 8.0
const STICK_TIME := 12.0
# world | enemies | debris | interactables | head_hitbox | destructibles
const HIT_MASK := 1 | 4 | 16 | 32 | 64 | 128

var velocity := Vector3.ZERO
var damage := 20.0

var _shooter: Node3D
var _life := 0.0
var _visual: Node3D


func setup(shooter: Node3D, from: Vector3, initial_velocity: Vector3, dmg: float) -> void:
	_shooter = shooter
	global_position = from
	velocity = initial_velocity
	damage = dmg
	_orient()


func _ready() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var shaft := MeshInstance3D.new()
	var shaft_mesh := BoxMesh.new()
	shaft_mesh.size = Vector3(0.02, 0.02, 0.55)
	shaft.mesh = shaft_mesh
	shaft.material_override = PSXMaterials.wood()
	_visual.add_child(shaft)
	var tip := MeshInstance3D.new()
	var tip_mesh := BoxMesh.new()
	tip_mesh.size = Vector3(0.03, 0.03, 0.06)
	tip.position = Vector3(0.0, 0.0, -0.29)
	tip.mesh = tip_mesh
	tip.material_override = PSXMaterials.metal()
	_visual.add_child(tip)
	var fletch := MeshInstance3D.new()
	var fletch_mesh := BoxMesh.new()
	fletch_mesh.size = Vector3(0.05, 0.05, 0.08)
	fletch.position = Vector3(0.0, 0.0, 0.24)
	fletch.mesh = fletch_mesh
	fletch.material_override = PSXMaterials.cloth_red()
	_visual.add_child(fletch)


func _physics_process(delta: float) -> void:
	_life += delta
	if _life > LIFETIME:
		queue_free()
		return

	velocity.y -= GRAVITY * delta
	var from := global_position
	var to := from + velocity * delta

	var query := PhysicsRayQueryParameters3D.create(from, to, HIT_MASK)
	query.collide_with_areas = true
	# Solo los shooters con cuerpo físico se excluyen (el AllyArcher es Node3D).
	if _shooter is CollisionObject3D:
		query.exclude = [(_shooter as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	if hit.is_empty():
		global_position = to
		_orient()
		return
	_resolve(hit)


func _resolve(hit: Dictionary) -> void:
	var collider: Object = hit["collider"]
	var target: Node = collider as Node
	var headshot := false

	if collider is Area3D and collider.has_meta("redirect_to"):
		target = collider.get_meta("redirect_to")
		headshot = bool(collider.get_meta("is_head", false))

	global_position = hit["position"]
	_orient()

	if target != null and target.has_method("take_arrow_hit"):
		target.take_arrow_hit(damage, headshot, velocity.normalized(), hit["position"])
		_stick_to(target)
	else:
		AudioManager.play_3d("arrow_hit_world", hit["position"], -8.0)
		# Memoria del tiro (D14): solo los impactos al mundo — corregí desde ahí.
		VFX.impact_marker(get_tree().current_scene, hit["position"], hit.get("normal", Vector3.UP))
		_stick_to(target if target is Node3D else get_tree().current_scene)
	queue_free()


func _orient() -> void:
	if velocity.length_squared() > 0.01:
		var dir := velocity.normalized()
		# En tiro casi vertical, UP es colineal con la dirección y look_at falla.
		look_at(global_position + dir, Vector3.UP if absf(dir.y) < 0.99 else Vector3.BACK)


## Clona el visual y lo cuelga del objetivo: la flecha viaja con el zombie (GDD §11.2).
func _stick_to(node: Node) -> void:
	if node == null or not node is Node3D or not is_instance_valid(node):
		return
	var stuck := Node3D.new()
	var visual_copy := _visual.duplicate()
	stuck.add_child(visual_copy)
	(node as Node3D).add_child(stuck)
	stuck.global_transform = global_transform
	stuck.global_position -= velocity.normalized() * 0.22
	var timer := Timer.new()
	timer.wait_time = STICK_TIME
	timer.one_shot = true
	timer.autostart = true
	stuck.add_child(timer)
	timer.timeout.connect(stuck.queue_free)
