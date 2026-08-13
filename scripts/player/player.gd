class_name Player
extends CharacterBody3D
## Controller FPS con feel Counter-Strike (GDD §5.1, §11):
## - Aceleración/fricción estilo Quake: frenadas secas, counter-strafe natural.
## - Precisión ligada a velocidad: quieto = disparo perfecto (GDD §5.1).
## - Arco con draw: mantener para tensar, soltar para disparar (D5).

# --- Movimiento (afinado a mano; tocar de a un valor y probar) ---
const WALK_SPEED := 5.2
const CROUCH_SPEED := 2.6
const DRAW_SPEED_MULT := 0.55  # tensar el arco te frena, como el AWP en CS
const GROUND_ACCEL := 70.0
const FRICTION := 8.0          # proporcional por segundo → frenada en ~0.12 s
const STOP_SPEED := 1.2
const AIR_ACCEL := 40.0
const AIR_CAP := 1.1           # control de aire limitado, estilo CS
const JUMP_VELOCITY := 4.4
const GRAVITY := 13.0
const MOUSE_SENS := 0.0022

# --- Arco (D5: proyectil con caída) ---
const MAX_ARROWS := 30
const DRAW_TIME := 0.65
const MIN_DRAW := 0.22
const RENOCK_TIME := 0.35
# Balística v2 (docs/design/guia-de-tiro.md): min 14 = el tiro sin tensar es un
# globo cómico (el draw ES el arma); max 42 con g=13 da 3.3 m de caída a 30 m.
const ARROW_SPEED_MIN := 14.0
const ARROW_SPEED_MAX := 42.0
const ARROW_DAMAGE_MIN := 18.0
const ARROW_DAMAGE_MAX := 55.0

# --- Dispersión en grados (GDD §5.1 + D14 v2: tensar ES la precisión) ---
const BASE_SPREAD := 0.3
const MOVE_SPREAD := 3.4
const AIR_SPREAD := 2.4
const LOW_DRAW_SPREAD := 7.0  # sin tensar, la flecha sale a cualquier lado

# --- Diana de apuntado (D14 v2, estilo Lucky Shot) ---
const LOCK_CONE_DEG := 6.0
const LOCK_RANGE := 55.0
const LOCK_MIN_DRAW := 0.5
const DIANA_RADIUS := 0.3  # "mira dentro de la diana" en metros de mundo

const INTERACT_RANGE := 3.2  # llega a la Puerta desde el borde de la meseta
const STAND_HEIGHT := 1.8
const CROUCH_HEIGHT := 1.2

var arrows := MAX_ARROWS
var draw_charge := 0.0
var is_drawing := false

var _renock := 0.0
var _crouching := false
var _punch := 0.0
var _shake := 0.0
var _interact_target: Node = null
var _interact_prompt := ""
var _step_accum := 0.0
var _was_on_floor := true

## D1 náutico (boceto de islas): caer al agua o al camino te devuelve acá.
var respawn_point := Vector3.ZERO

## Telémetro de la escalera de pips (D14): distancia al enemigo apuntado, -1 sin blanco.
var aimed_enemy_distance := -1.0

var _locked_target: Node3D = null
var _aim_on_target := false
var _aim_marker: AimTargetMarker

var head: Node3D
var camera: Camera3D
var bow: Bow
var _capsule: CapsuleShape3D
var _collider: CollisionShape3D


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1 | 4  # mundo y enemigos

	_capsule = CapsuleShape3D.new()
	_capsule.radius = 0.4
	_capsule.height = STAND_HEIGHT
	_collider = CollisionShape3D.new()
	_collider.shape = _capsule
	_collider.position = Vector3(0.0, STAND_HEIGHT * 0.5, 0.0)
	add_child(_collider)

	head = Node3D.new()
	head.name = "Head"
	head.position = Vector3(0.0, 1.62, 0.0)
	add_child(head)

	camera = Camera3D.new()
	camera.fov = 92.0
	camera.near = 0.05
	head.add_child(camera)
	camera.add_child(RetroPostProcess.new())

	bow = Bow.new()
	bow.setup(self)
	camera.add_child(bow)

	_aim_marker = AimTargetMarker.new()
	add_child(_aim_marker)


func _unhandled_input(event: InputEvent) -> void:
	# Cualquier UI con mouse libre (pausa, debug F1, pergamino) bloquea el input.
	if not GameManager.is_gameplay() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if event is InputEventMouseMotion:
		rotate_y(-event.relative.x * MOUSE_SENS)
		head.rotation.x = clampf(head.rotation.x - event.relative.y * MOUSE_SENS, -1.55, 1.55)
		bow.add_sway(event.relative)
	elif event.is_action_pressed("interact") and is_instance_valid(_interact_target):
		_interact_target.interact(self)


func _physics_process(delta: float) -> void:
	if not GameManager.is_gameplay() or Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		if is_drawing:
			_cancel_draw()  # el release del mouse se consume en pausa/UI: no dejar el arco trabado
		return
	_update_crouch(delta)
	_movement(delta)
	_update_draw(delta)
	_update_interact_ray()
	_update_aim_telemetry()
	_update_camera_feel(delta)
	_update_footsteps(delta)
	# Kill-zone: todo lo transitable legal está a y ≥ 2.3 (islas, puente,
	# plataforma). Agua y camino devuelven a la torre — D1 sin muros invisibles.
	if respawn_point != Vector3.ZERO and global_position.y < 0.9:
		global_position = respawn_point
		velocity = Vector3.ZERO
		EventBus.announcement.emit("El agua está helada — mejor no salir de la isla")


# ------------------------------------------------------------------ movimiento

func _movement(delta: float) -> void:
	var input_2d := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var wish := global_transform.basis * Vector3(input_2d.x, 0.0, input_2d.y)
	wish.y = 0.0
	wish = wish.normalized() if wish.length_squared() > 0.001 else Vector3.ZERO

	var max_speed := CROUCH_SPEED if _crouching else WALK_SPEED
	if is_drawing:
		max_speed *= DRAW_SPEED_MULT

	if is_on_floor():
		_apply_friction(delta)
		_accelerate(wish, max_speed, GROUND_ACCEL, delta)
		if Input.is_action_just_pressed("jump") and not _crouching:
			velocity.y = JUMP_VELOCITY
	else:
		_air_accelerate(wish, delta)
		velocity.y -= GRAVITY * delta

	move_and_slide()


func _apply_friction(delta: float) -> void:
	var hvel := Vector3(velocity.x, 0.0, velocity.z)
	var speed := hvel.length()
	if speed < 0.01:
		velocity.x = 0.0
		velocity.z = 0.0
		return
	var control := maxf(speed, STOP_SPEED)
	var drop := control * FRICTION * delta
	var scale_factor := maxf(speed - drop, 0.0) / speed
	velocity.x *= scale_factor
	velocity.z *= scale_factor


func _accelerate(wish: Vector3, max_speed: float, accel: float, delta: float) -> void:
	if wish == Vector3.ZERO:
		return
	var current := velocity.dot(wish)
	var add := max_speed - current
	if add <= 0.0:
		return
	velocity += wish * minf(accel * delta, add)


func _air_accelerate(wish: Vector3, delta: float) -> void:
	if wish == Vector3.ZERO:
		return
	var current := velocity.dot(wish)
	var add := AIR_CAP - current
	if add <= 0.0:
		return
	velocity += wish * minf(AIR_ACCEL * delta, add)


func _update_crouch(delta: float) -> void:
	var want := Input.is_action_pressed("crouch")
	if not want and _crouching and not _can_stand():
		want = true
	if want == _crouching:
		return
	_crouching = want
	var target_height := CROUCH_HEIGHT if _crouching else STAND_HEIGHT
	_capsule.height = target_height
	_collider.position.y = target_height * 0.5
	var head_y := 1.05 if _crouching else 1.62
	var tween := create_tween()
	tween.tween_property(head, "position:y", head_y, 0.12)


func _can_stand() -> bool:
	# Rayos en cruz sobre el radio de la cápsula: un solo rayo central no ve
	# salientes descentrados y Jolt escupe al jugador al pararse dentro.
	var space := get_world_3d().direct_space_state
	for offset in [Vector3.ZERO, Vector3(0.3, 0, 0), Vector3(-0.3, 0, 0), Vector3(0, 0, 0.3), Vector3(0, 0, -0.3)]:
		var from: Vector3 = global_position + offset + Vector3(0.0, CROUCH_HEIGHT, 0.0)
		var to: Vector3 = global_position + offset + Vector3(0.0, STAND_HEIGHT + 0.05, 0.0)
		if not space.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1)).is_empty():
			return false
	return true


# ------------------------------------------------------------------ disparo

func _update_draw(delta: float) -> void:
	_renock = maxf(_renock - delta, 0.0)

	if Input.is_action_just_pressed("shoot"):
		if arrows <= 0:
			AudioManager.play_ui("ui_click", -4.0)
		elif _renock <= 0.0 and not is_drawing:
			is_drawing = true
			draw_charge = 0.0
			AudioManager.play_ui("bow_draw", -10.0)
			bow.on_draw_start()

	if not is_drawing:
		return
	draw_charge = minf(draw_charge + delta / DRAW_TIME, 1.0)
	bow.set_draw(draw_charge)
	if Input.is_action_just_released("shoot"):
		if draw_charge >= MIN_DRAW:
			_shoot()
		else:
			_cancel_draw()


func _shoot() -> void:
	is_drawing = false
	arrows -= 1
	EventBus.arrows_changed.emit(arrows, MAX_ARROWS)

	var speed := lerpf(ARROW_SPEED_MIN, ARROW_SPEED_MAX, draw_charge)
	var spawn_pos := camera.global_position - camera.global_basis.z * 0.45 + camera.global_basis.x * 0.06
	var dir: Vector3
	var perfect := false
	# Tiro perfecto (D14 v2): soltar con la mira en la diana = solución
	# balística exacta a la cabeza FUTURA (con lead). Ganado, no regalado.
	if _aim_on_target and _locked_target != null and is_instance_valid(_locked_target):
		var predicted := _predicted_head_position(_locked_target, spawn_pos, speed)
		var solution := _ballistic_dir(spawn_pos, predicted, speed)
		if solution != Vector3.ZERO:
			dir = solution
			perfect = true
	if not perfect:
		dir = _aim_dir_with_spread()

	var arrow := Arrow.new()
	get_tree().current_scene.add_child(arrow)
	arrow.setup(self, spawn_pos, dir * speed,
		lerpf(ARROW_DAMAGE_MIN, ARROW_DAMAGE_MAX, draw_charge), draw_charge, perfect)

	AudioManager.play_ui("bow_shoot", -2.0)
	_punch = -0.02 - draw_charge * 0.022  # view punch sutil (GDD §11.1)
	bow.on_shoot()
	_renock = RENOCK_TIME
	draw_charge = 0.0
	_aim_marker.hide_marker()


func _cancel_draw() -> void:
	is_drawing = false
	draw_charge = 0.0
	bow.set_draw(0.0)


func _aim_dir_with_spread() -> Vector3:
	var base := -camera.global_basis.z
	var spread := deg_to_rad(current_spread_deg())
	if spread <= 0.0001:
		return base
	var axis := base.cross(Vector3.UP).normalized()
	if axis.length_squared() < 0.5:
		axis = Vector3.RIGHT
	axis = axis.rotated(base, randf() * TAU)
	return base.rotated(axis, randf() * spread).normalized()


func current_spread_deg() -> float:
	var hspeed := Vector3(velocity.x, 0.0, velocity.z).length()
	var speed_frac := clampf(hspeed / WALK_SPEED, 0.0, 1.0)
	var spread := BASE_SPREAD + speed_frac * MOVE_SPREAD
	if not is_on_floor():
		spread += AIR_SPREAD
	if is_drawing:
		spread += (1.0 - draw_charge) * LOW_DRAW_SPREAD
	return spread


## Píxeles de apertura del crosshair (HUD lo consulta cada frame).
func get_crosshair_spread() -> float:
	return 2.0 + current_spread_deg() * 5.0


func refill_arrows() -> void:
	arrows = MAX_ARROWS
	EventBus.arrows_changed.emit(arrows, MAX_ARROWS)


# ------------------------------------------------------------------ feedback

const STEP_DISTANCE := 2.2

## Pasos por distancia recorrida (pack PSX footsteps — assets/audio/footsteps).
func _update_footsteps(_delta: float) -> void:
	if not is_on_floor():
		_was_on_floor = false
		return
	if not _was_on_floor:
		_was_on_floor = true
		AudioManager.play_footstep(-9.0)  # aterrizaje
		_step_accum = 0.0
		return
	var hspeed := Vector3(velocity.x, 0.0, velocity.z).length()
	if hspeed < 0.5:
		return
	_step_accum += hspeed * get_physics_process_delta_time()
	var stride := STEP_DISTANCE * (0.75 if _crouching else 1.0)
	if _step_accum >= stride:
		_step_accum = 0.0
		AudioManager.play_footstep(-18.0 if _crouching else -13.0)


func camera_shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func _update_camera_feel(delta: float) -> void:
	_punch = lerpf(_punch, 0.0, minf(delta * 10.0, 1.0))
	_shake = lerpf(_shake, 0.0, minf(delta * 6.0, 1.0))
	camera.rotation.x = _punch
	if _shake > 0.001:
		camera.h_offset = randf_range(-_shake, _shake) * 0.06
		camera.v_offset = randf_range(-_shake, _shake) * 0.06
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


## Telémetro (pips) + diana Lucky Shot: solo tensando.
func _update_aim_telemetry() -> void:
	if not is_drawing:
		aimed_enemy_distance = -1.0
		_locked_target = null
		_aim_on_target = false
		_aim_marker.hide_marker()
		return
	var from := camera.global_position
	var to := from - camera.global_basis.z * 60.0
	var query := PhysicsRayQueryParameters3D.create(from, to, 4 | 64)  # enemigos + cabezas
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	aimed_enemy_distance = from.distance_to(hit["position"]) if not hit.is_empty() else -1.0
	_update_aim_marker()


## La diana (D14 v2): sobre el punto FUTURO del objetivo (lead por tiempo de
## vuelo — con goblins en movimiento la posición actual nunca acierta), elevada
## EXACTAMENTE lo que la flecha cae con el draw actual. Anticipación + caída en
## un solo punto: apuntarle a la diana pone la flecha en la cabeza.
func _update_aim_marker() -> void:
	_locked_target = null
	_aim_on_target = false
	if draw_charge < LOCK_MIN_DRAW:
		_aim_marker.hide_marker()
		return
	_locked_target = _find_target_in_cone()
	if _locked_target == null:
		_aim_marker.hide_marker()
		return
	var from := camera.global_position
	var speed := lerpf(ARROW_SPEED_MIN, ARROW_SPEED_MAX, draw_charge)
	var predicted := _predicted_head_position(_locked_target, from, speed)
	var dist := from.distance_to(predicted)
	var drop := Arrow.GRAVITY * dist * dist / (2.0 * speed * speed)
	var marker_pos := predicted + Vector3.UP * (0.35 + drop)
	# "Mira dentro de la diana": distancia del rayo de mira al centro, en mundo.
	var forward := -camera.global_basis.z
	var ray_dist := ((marker_pos - from).cross(forward)).length()
	_aim_on_target = ray_dist < DIANA_RADIUS
	_aim_marker.update_marker(marker_pos, _aim_on_target)


## Cabeza del objetivo cuando la flecha LLEGUE (no donde está ahora): lead por
## iteración de punto fijo — t = dist/velocidad, dos pasadas convergen de sobra.
func _predicted_head_position(target: Node3D, from: Vector3, speed: float) -> Vector3:
	var head: Vector3 = target.head_position()
	var target_vel := Vector3.ZERO
	if target is CharacterBody3D:
		target_vel = (target as CharacterBody3D).velocity
		target_vel.y = 0.0  # el bob vertical mete ruido; el lead útil es horizontal
	if target_vel.length_squared() < 0.04:
		return head
	var predicted := head
	for i in 2:
		var t := from.distance_to(predicted) / maxf(speed, 1.0)
		predicted = head + target_vel * t
	return predicted


func _find_target_in_cone() -> Node3D:
	var from := camera.global_position
	var forward := -camera.global_basis.z
	var best: Node3D = null
	var best_angle := deg_to_rad(LOCK_CONE_DEG)
	var candidates := get_tree().get_nodes_in_group("enemies") \
		+ get_tree().get_nodes_in_group("practice_targets")
	for candidate in candidates:
		if not candidate is Node3D or not candidate.has_method("head_position"):
			continue
		var head: Vector3 = candidate.head_position()
		var offset: Vector3 = head - from
		var dist := offset.length()
		if dist > LOCK_RANGE or dist < 2.0:
			continue
		var angle := forward.angle_to(offset)
		if angle >= best_angle:
			continue
		# Línea de visión: el mundo no debe tapar la cabeza.
		var los := PhysicsRayQueryParameters3D.create(from, head, 1)
		if get_world_3d().direct_space_state.intersect_ray(los).is_empty():
			best_angle = angle
			best = candidate
	return best


## Ángulo de lanzamiento exacto para llegar a `to` con velocidad `speed`
## (trayectoria baja). ZERO si está fuera de alcance.
func _ballistic_dir(from: Vector3, to: Vector3, speed: float) -> Vector3:
	var delta := to - from
	var dy := delta.y
	var flat := Vector2(delta.x, delta.z)
	var dx := flat.length()
	if dx < 0.01:
		return Vector3.ZERO
	var g: float = Arrow.GRAVITY
	var v2 := speed * speed
	var disc := v2 * v2 - g * (g * dx * dx + 2.0 * dy * v2)
	if disc < 0.0:
		return Vector3.ZERO
	var theta := atan((v2 - sqrt(disc)) / (g * dx))
	var dir_flat := Vector3(flat.x, 0.0, flat.y).normalized()
	return (dir_flat * cos(theta) + Vector3.UP * sin(theta)).normalized()


# ------------------------------------------------------------------ interacción

func _update_interact_ray() -> void:
	var from := camera.global_position
	var to := from - camera.global_basis.z * INTERACT_RANGE
	var query := PhysicsRayQueryParameters3D.create(from, to, 32)
	query.collide_with_areas = true
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	var target: Node = null
	if not hit.is_empty():
		var collider: Object = hit["collider"]
		if collider is Node and collider.has_method("get_interact_prompt"):
			target = collider
	_interact_target = target
	# El texto se re-evalúa siempre: los prompts cambian con la fase del día (cama, puerta).
	var prompt := ""
	if _interact_target != null:
		prompt = _interact_target.get_interact_prompt()
	if prompt != _interact_prompt:
		_interact_prompt = prompt
		EventBus.interact_prompt_changed.emit(prompt)
