class_name PSXMaterials
extends RefCounted
## Fábrica de materiales placeholder con el shader PSX (shaders/psx_lit.gdshader).
## Cada material usa una NoiseTexture2D procedural de 64px — cuando lleguen las texturas
## reales (assets-list.md) se reemplaza la textura manteniendo el mismo shader.

const SHADER := preload("res://shaders/psx_lit.gdshader")

static var _cache: Dictionary = {}


static func stone() -> ShaderMaterial:
	return _noise_mat("stone", Color(0.36, 0.37, 0.42), Color(0.5, 0.51, 0.56), 0.12)


static func stone_dark() -> ShaderMaterial:
	return _noise_mat("stone_dark", Color(0.2, 0.21, 0.26), Color(0.31, 0.32, 0.38), 0.1)


static func stone_floor() -> ShaderMaterial:
	return _noise_mat("stone_floor", Color(0.27, 0.27, 0.31), Color(0.4, 0.4, 0.45), 0.2)


static func dirt() -> ShaderMaterial:
	return _noise_mat("dirt", Color(0.24, 0.2, 0.15), Color(0.36, 0.3, 0.22), 0.18)


static func wood() -> ShaderMaterial:
	return _noise_mat("wood", Color(0.33, 0.23, 0.14), Color(0.47, 0.34, 0.2), 0.16)


static func wood_dark() -> ShaderMaterial:
	return _noise_mat("wood_dark", Color(0.22, 0.15, 0.09), Color(0.33, 0.23, 0.14), 0.14)


static func metal() -> ShaderMaterial:
	return _noise_mat("metal", Color(0.3, 0.32, 0.36), Color(0.42, 0.45, 0.5), 0.3)


static func goblin_skin() -> ShaderMaterial:
	return _noise_mat("goblin_skin", Color(0.3, 0.42, 0.18), Color(0.47, 0.58, 0.26), 0.25)


static func goblin_elite() -> ShaderMaterial:
	return _noise_mat("goblin_elite", Color(0.45, 0.2, 0.12), Color(0.6, 0.3, 0.16), 0.25)


static func cloth() -> ShaderMaterial:
	return _noise_mat("cloth", Color(0.4, 0.31, 0.22), Color(0.5, 0.4, 0.29), 0.15)


static func cloth_red() -> ShaderMaterial:
	return _noise_mat("cloth_red", Color(0.38, 0.14, 0.12), Color(0.5, 0.2, 0.16), 0.15)


static func straw() -> ShaderMaterial:
	return _noise_mat("straw", Color(0.5, 0.42, 0.2), Color(0.62, 0.53, 0.28), 0.35)


static func flame() -> ShaderMaterial:
	var mat := _noise_mat("flame", Color(0.9, 0.45, 0.1), Color(1.0, 0.8, 0.3), 0.5)
	return mat


## Variante de un material base con las UV escaladas (para muros/pisos grandes,
## así la textura de 64px no se estira). `key` debe ser uno de los nombres base.
static func scaled(key: String, scale: Vector2) -> ShaderMaterial:
	var cache_key := "%s_%sx%s" % [key, scale.x, scale.y]
	if _cache.has(cache_key):
		return _cache[cache_key]
	var variant: ShaderMaterial = _base_by_key(key).duplicate()
	variant.set_shader_parameter("uv_scale", scale)
	_cache[cache_key] = variant
	return variant


static func _base_by_key(key: String) -> ShaderMaterial:
	match key:
		"stone": return stone()
		"stone_dark": return stone_dark()
		"stone_floor": return stone_floor()
		"dirt": return dirt()
		"wood": return wood()
		"wood_dark": return wood_dark()
		"metal": return metal()
		"goblin_skin": return goblin_skin()
		"goblin_elite": return goblin_elite()
		"cloth": return cloth()
		"cloth_red": return cloth_red()
		"straw": return straw()
		"flame": return flame()
	push_warning("PSXMaterials: clave desconocida '%s', usando stone()" % key)
	return stone()


static func _noise_mat(key: String, dark: Color, light: Color, frequency: float) -> ShaderMaterial:
	if _cache.has(key):
		return _cache[key]
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = frequency
	noise.seed = key.hash() % 100000
	var gradient := Gradient.new()
	gradient.set_color(0, dark)
	gradient.set_color(1, light)
	var tex := NoiseTexture2D.new()
	tex.width = 64
	tex.height = 64
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = gradient
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("albedo_tex", tex)
	_cache[key] = mat
	return mat
