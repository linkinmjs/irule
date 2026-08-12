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
const ARROW_SPEED_MIN := 16.0
const ARROW_SPEED_MAX := 42.0
const ARROW_DAMAGE_MIN := 18.0
const ARROW_DAMAGE_MAX := 55.0

# --- Dispersión en grados (GDD §5.1: quieto = perfecto) ---
const BASE_SPREAD := 0.3
const MOVE_SPREAD := 3.4
const AIR_SPREAD := 2.4
const LOW_DRAW_SPREAD := 2.2

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
	_update_camera_feel(delta)
	_update_footsteps(delta)


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

	var dir := _aim_dir_with_spread()
	var arrow := Arrow.new()
	get_tree().current_scene.add_child(arrow)
	arrow.setup(
		self,
		camera.global_position + dir * 0.45 + camera.global_basis.x * 0.06,
		dir * lerpf(ARROW_SPEED_MIN, ARROW_SPEED_MAX, draw_charge),
		lerpf(ARROW_DAMAGE_MIN, ARROW_DAMAGE_MAX, draw_charge)
	)

	AudioManager.play_ui("bow_shoot", -2.0)
	_punch = -0.02 - draw_charge * 0.022  # view punch sutil (GDD §11.1)
	bow.on_shoot()
	_renock = RENOCK_TIME
	draw_charge = 0.0


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
