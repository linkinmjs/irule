class_name GroundZone
extends Node3D
## Zona persistente en el suelo (F4, M4b §2): FUEGO (daño por segundo) o
## ESCARCHA (slow). La dejan la incendiaria y la congelante al impactar.
## Tick de 0.5 s contra el grupo "enemies" — sin Area3D (los goblins ya están
## en un grupo, la distancia plana alcanza y es más barato).

const TICK := 0.5

var effect: ArrowTypeData.ZoneEffect = ArrowTypeData.ZoneEffect.FIRE
var radius := 2.5
var duration := 5.0
var dps := 6.0
var slow := 0.45

var _life := 0.0
var _tick_in := 0.0
var _quads: Array[MeshInstance3D] = []
var _light: OmniLight3D


func _ready() -> void:
	_build_visual()


func _process(delta: float) -> void:
	_life += delta
	if _life >= duration:
		var tween := create_tween()
		tween.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), 0.3)
		tween.tween_callback(queue_free)
		set_process(false)
		return
	# Flicker PS1: los quads laten, la luz respira.
	for i in _quads.size():
		_quads[i].scale.y = 1.0 + sin(_life * 9.0 + i * 2.1) * 0.25
	if _light != null:
		_light.light_energy = 1.4 + sin(_life * 11.0) * 0.35

	_tick_in -= delta
	if _tick_in > 0.0:
		return
	_tick_in = TICK
	for enemy in get_tree().get_nodes_in_group("enemies"):
		var enemy_3d := enemy as Node3D
		if enemy_3d == null:
			continue
		var flat_dist := Vector2(enemy_3d.global_position.x - global_position.x,
			enemy_3d.global_position.z - global_position.z).length()
		if flat_dist > radius:
			continue
		if effect == ArrowTypeData.ZoneEffect.FIRE and enemy.has_method("take_trap_damage"):
			enemy.take_trap_damage(dps * TICK, false)
		elif effect == ArrowTypeData.ZoneEffect.FROST and enemy.has_method("apply_slow"):
			enemy.apply_slow(1.0 - slow, TICK + 0.3)


## Corona de quads llama/escarcha + disco tenue + luz (solo el fuego ilumina).
func _build_visual() -> void:
	var fire := effect == ArrowTypeData.ZoneEffect.FIRE
	var color := Color(1.0, 0.55, 0.15) if fire else Color(0.6, 0.82, 1.0)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 1.2
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	var disc := MeshInstance3D.new()
	var disc_mesh := CylinderMesh.new()
	disc_mesh.top_radius = radius
	disc_mesh.bottom_radius = radius
	disc_mesh.height = 0.06
	disc_mesh.radial_segments = 10
	disc.mesh = disc_mesh
	var disc_mat := StandardMaterial3D.new()
	disc_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc_mat.albedo_color = Color(color.r, color.g, color.b, 0.28)
	disc_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc.material_override = disc_mat
	disc.position.y = 0.04
	add_child(disc)

	var rng := RandomNumberGenerator.new()
	rng.seed = int(global_position.x * 57.0 + global_position.z * 131.0)
	for i in 7:
		var quad := MeshInstance3D.new()
		var mesh := QuadMesh.new()
		mesh.size = Vector2(0.28, 0.5) if fire else Vector2(0.2, 0.42)
		quad.mesh = mesh
		var angle := TAU * i / 7.0 + rng.randf() * 0.5
		var r := radius * rng.randf_range(0.3, 0.85)
		quad.position = Vector3(cos(angle) * r, 0.28, sin(angle) * r)
		quad.rotation.y = rng.randf() * TAU
		quad.material_override = mat
		add_child(quad)
		_quads.append(quad)

	if fire:
		_light = OmniLight3D.new()
		_light.light_color = color
		_light.omni_range = radius + 3.0
		_light.light_energy = 1.4
		_light.position.y = 0.7
		add_child(_light)
