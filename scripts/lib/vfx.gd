class_name VFX
extends RefCounted
## Efectos puntuales construidos por código. Estética PS1: partículas chunky,
## flashes cortos, nada de glow moderno.


static func explosion(parent: Node, pos: Vector3) -> void:
	# Flash de luz.
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.62, 0.25)
	light.light_energy = 7.0
	light.omni_range = 9.0
	parent.add_child(light)
	light.global_position = pos + Vector3.UP * 0.6
	var tween := light.create_tween()
	tween.tween_property(light, "light_energy", 0.0, 0.35)
	tween.tween_callback(light.queue_free)

	_burst(parent, pos, Color(1.0, 0.55, 0.15), Color(0.25, 0.23, 0.2), 30, 7.0, 1.0)


static func dust_puff(parent: Node, pos: Vector3) -> void:
	_burst(parent, pos, Color(0.5, 0.47, 0.42), Color(0.3, 0.28, 0.26), 10, 2.0, 0.6)


## Suelta un escombro físico (tablones de la Puerta, etc.) que se disuelve solo.
static func drop_debris(parent: Node, mesh: Mesh, mat: Material, xform: Transform3D, impulse: Vector3) -> void:
	var body := RigidBody3D.new()
	body.collision_layer = 16
	body.collision_mask = 1 | 16
	var size := Vector3(0.3, 0.3, 0.3)
	if mesh is BoxMesh:
		size = (mesh as BoxMesh).size
	body.mass = clampf(size.x * size.y * size.z * 40.0, 0.6, 6.0)
	var shape := BoxShape3D.new()
	shape.size = size * 0.9
	var col := CollisionShape3D.new()
	col.shape = shape
	body.add_child(col)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	body.add_child(mi)
	parent.add_child(body)
	body.global_transform = xform
	body.apply_central_impulse(impulse * body.mass)
	body.angular_velocity = Vector3(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0), randf_range(-4.0, 4.0))
	var timer := Timer.new()
	timer.wait_time = 3.0 + randf_range(0.0, 0.8)
	timer.one_shot = true
	timer.autostart = true
	body.add_child(timer)
	timer.timeout.connect(func() -> void:
		var tween := body.create_tween()
		tween.tween_method(func(v: float) -> void:
			mi.set_instance_shader_parameter("dissolve", v), 1.0, 0.0, 0.7)
		tween.tween_callback(body.queue_free))


static func _burst(parent: Node, pos: Vector3, from_color: Color, to_color: Color,
		amount: int, speed: float, lifetime: float) -> void:
	var particles := GPUParticles3D.new()
	particles.one_shot = true
	particles.amount = amount
	particles.lifetime = lifetime
	particles.explosiveness = 1.0

	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.0, 1.0, 0.0)
	mat.spread = 180.0
	mat.initial_velocity_min = speed * 0.4
	mat.initial_velocity_max = speed
	mat.gravity = Vector3(0.0, -3.0, 0.0)
	mat.damping_min = 2.0
	mat.damping_max = 4.0
	mat.scale_min = 0.6
	mat.scale_max = 1.4
	var gradient := Gradient.new()
	gradient.set_color(0, from_color)
	gradient.set_color(1, Color(to_color.r, to_color.g, to_color.b, 0.0))
	var ramp := GradientTexture1D.new()
	ramp.gradient = gradient
	mat.color_ramp = ramp
	particles.process_material = mat

	var quad := QuadMesh.new()
	quad.size = Vector2(0.28, 0.28)
	var quad_mat := StandardMaterial3D.new()
	quad_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	quad_mat.vertex_color_use_as_albedo = true
	quad_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	quad.material = quad_mat
	particles.draw_pass_1 = quad

	parent.add_child(particles)
	particles.global_position = pos
	particles.emitting = true

	var timer := Timer.new()
	timer.wait_time = lifetime + 1.0
	timer.one_shot = true
	timer.autostart = true
	particles.add_child(timer)
	timer.timeout.connect(particles.queue_free)
