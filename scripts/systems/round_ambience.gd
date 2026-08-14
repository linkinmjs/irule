class_name RoundAmbience
extends Node3D
## Ambiente por RONDA (D17, reemplaza al ciclo día/noche): cada ronda fija un
## preset de hora/color (amanecer, mediodía, atardecer…) y un clima (despejado,
## neblina, bruma roja) — la transición es un fundido suave de ~4 s al iniciar.
## Sin shadowmaps (PS1); la niebla la pinta el post (grupo retro_post).

## preset → [sun_energy, sun_color, moon_energy, fog_color, ambient_energy,
##            fog_distance, fog_fade, sun_pitch_deg]
const PRESETS := {
	&"amanecer": [0.9, Color(1.0, 0.85, 0.65), 0.0, Color(0.46, 0.42, 0.42), 0.45, 44.0, 27.0, -25.0],
	&"mediodia": [1.1, Color(1.0, 0.93, 0.76), 0.0, Color(0.5, 0.52, 0.52), 0.52, 46.0, 28.0, -70.0],
	&"atardecer": [0.55, Color(1.0, 0.55, 0.3), 0.05, Color(0.33, 0.24, 0.22), 0.28, 40.0, 26.0, -15.0],
	&"anochecer": [0.05, Color(0.7, 0.5, 0.45), 0.5, Color(0.11, 0.13, 0.2), 0.24, 30.0, 20.0, -10.0],
	&"luna": [0.0, Color(0.5, 0.5, 0.6), 0.65, Color(0.09, 0.11, 0.17), 0.27, 26.0, 16.0, -48.0],
	&"noche_cerrada": [0.0, Color(0.5, 0.5, 0.6), 0.45, Color(0.07, 0.09, 0.14), 0.2, 22.0, 14.0, -48.0],
}

var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _env: Environment

var _current: Array = []
var _target: Array = []


func _ready() -> void:
	_sun = DirectionalLight3D.new()
	_sun.shadow_enabled = false
	_sun.rotation_degrees = Vector3(-45.0, -35.0, 0.0)
	add_child(_sun)

	_moon = DirectionalLight3D.new()
	_moon.light_color = Color(0.72, 0.78, 0.95)
	_moon.rotation_degrees = Vector3(-48.0, 155.0, 0.0)
	_moon.shadow_enabled = false
	add_child(_moon)

	_env = Environment.new()
	_env.background_mode = Environment.BG_COLOR
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	_env.ambient_light_color = Color(0.55, 0.6, 0.7)
	_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_env.fog_enabled = false  # la niebla es del post (RetroPostProcess)
	var world_env := WorldEnvironment.new()
	world_env.environment = _env
	add_child(world_env)

	WorldState.round_started.connect(_on_round_started)
	# Ambiente inicial del intermedio pre-ronda-1.
	_target = _compose(&"mediodia", &"despejado")
	_current = _target.duplicate()
	_apply(_current)


func _on_round_started(_n: int) -> void:
	var info := WorldState.current_round
	_target = _compose(info.get("ambience", &"mediodia"), info.get("weather", &"despejado"))


func _process(delta: float) -> void:
	if _current.is_empty() or _target.is_empty():
		return
	var w := 1.0 - exp(-delta * 0.8)  # fundido de ~4 s
	for i in _current.size():
		if _current[i] is Color:
			_current[i] = (_current[i] as Color).lerp(_target[i], w)
		else:
			_current[i] = lerpf(_current[i], _target[i], w)
	_apply(_current)


## Preset base + modificadores del clima (D17: el clima toca niebla y tinte).
func _compose(ambience: StringName, weather: StringName) -> Array:
	var values: Array = (PRESETS.get(ambience, PRESETS[&"mediodia"]) as Array).duplicate()
	match weather:
		&"despejado":
			values[5] *= 1.2
		&"neblina":
			values[5] *= 0.55
			values[6] *= 0.7
		&"bruma_roja":
			values[3] = (values[3] as Color).lerp(Color(0.4, 0.13, 0.1), 0.45)
			values[5] *= 0.75
	return values


func _apply(values: Array) -> void:
	_sun.light_energy = values[0]
	_sun.light_color = values[1]
	_sun.visible = _sun.light_energy > 0.01
	_moon.light_energy = values[2]
	_moon.visible = _moon.light_energy > 0.01
	var fog_color: Color = values[3]
	_env.background_color = fog_color
	_env.ambient_light_energy = values[4]
	_sun.rotation_degrees = Vector3(values[7], -35.0, 0.0)
	var post: Node = get_tree().get_first_node_in_group("retro_post")
	if post != null and post.has_method("set_fog"):
		post.set_fog(fog_color, values[5], values[6])
