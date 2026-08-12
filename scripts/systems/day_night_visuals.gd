class_name DayNightVisuals
extends Node3D
## Luz y atmósfera según la hora (GDD §10.1): antorchas cálidas sobre luz fría,
## niebla que tapa el fondo del corredor (identidad visual + gameplay).
## Interpola keyframes por hora interna de WorldState (8.0 → 27.0).

# h, sun_energy, sun_color, moon_energy, sky, fog_color, fog_density, ambient_energy, fog_distance, fog_fade
# (fog_density quedó para el fallback del Environment; la niebla activa es la del
# post-proceso — fog_distance/fog_fade en metros.)
const KEYFRAMES := [
	[8.0, 0.95, Color(1.0, 0.95, 0.82), 0.0, Color(0.34, 0.4, 0.48), Color(0.42, 0.45, 0.5), 0.014, 0.4, 58.0, 36.0],
	[17.0, 0.85, Color(1.0, 0.9, 0.75), 0.0, Color(0.32, 0.36, 0.44), Color(0.4, 0.42, 0.47), 0.016, 0.35, 52.0, 34.0],
	[19.8, 0.55, Color(1.0, 0.55, 0.3), 0.05, Color(0.35, 0.22, 0.18), Color(0.33, 0.24, 0.22), 0.024, 0.28, 40.0, 26.0],
	[21.0, 0.05, Color(0.7, 0.5, 0.45), 0.28, Color(0.05, 0.06, 0.11), Color(0.07, 0.08, 0.13), 0.038, 0.14, 26.0, 18.0],
	[22.5, 0.0, Color(0.5, 0.5, 0.6), 0.38, Color(0.025, 0.03, 0.06), Color(0.045, 0.055, 0.095), 0.047, 0.1, 21.0, 14.0],
	[27.0, 0.0, Color(0.5, 0.5, 0.6), 0.38, Color(0.025, 0.03, 0.06), Color(0.045, 0.055, 0.095), 0.05, 0.1, 20.0, 13.0],
]

var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _env: Environment


func _ready() -> void:
	# Sin shadowmaps: PS1 no los tenía, y con el vertex snapping generaban
	# shimmering ("ruido de luz" — feedback de playtest 2026-08-11).
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = false
	add_child(_sun)

	_moon = DirectionalLight3D.new()
	_moon.light_color = Color(0.6, 0.68, 0.9)
	_moon.rotation_degrees = Vector3(-48.0, 155.0, 0.0)
	_moon.shadow_enabled = false
	add_child(_moon)

	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.55, 0.6, 0.7)
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	# La niebla del juego es el post-proceso (RetroPostProcess); si se lo quita,
	# reactivar este fog exponencial como respaldo.
	_env.fog_enabled = false
	_env.fog_sky_affect = 1.0
	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)
	_apply(WorldState.hour)


func _process(_delta: float) -> void:
	_apply(WorldState.hour)


func _apply(hour: float) -> void:
	var a: Array = KEYFRAMES[0]
	var b: Array = KEYFRAMES[KEYFRAMES.size() - 1]
	for i in KEYFRAMES.size() - 1:
		if hour >= KEYFRAMES[i][0] and hour <= KEYFRAMES[i + 1][0]:
			a = KEYFRAMES[i]
			b = KEYFRAMES[i + 1]
			break
	var span: float = maxf(b[0] - a[0], 0.001)
	var t: float = clampf((hour - a[0]) / span, 0.0, 1.0)

	_sun.light_energy = lerpf(a[1], b[1], t)
	_sun.light_color = (a[2] as Color).lerp(b[2], t)
	_sun.visible = _sun.light_energy > 0.01
	_moon.light_energy = lerpf(a[3], b[3], t)
	_moon.visible = _moon.light_energy > 0.01
	var fog_color := (a[5] as Color).lerp(b[5], t)
	_env.background_color = fog_color  # el fondo se funde con la niebla del post
	_env.fog_light_color = fog_color
	_env.fog_density = lerpf(a[6], b[6], t)
	_env.ambient_light_energy = lerpf(a[7], b[7], t)

	var post: Node = get_tree().get_first_node_in_group("retro_post")
	if post != null and post.has_method("set_fog"):
		post.set_fog(fog_color, lerpf(a[8], b[8], t), lerpf(a[9], b[9], t))

	# El sol recorre el cielo en pasos discretos (cada 10 min de juego): sin
	# micro-movimiento por frame, la iluminación queda estable (menos ruido).
	var stepped_hour := floorf(hour * 6.0) / 6.0
	var day_frac: float = clampf((stepped_hour - 8.0) / 12.0, 0.0, 1.0)
	_sun.rotation_degrees = Vector3(lerpf(-25.0, -155.0, day_frac), -35.0, 0.0)
