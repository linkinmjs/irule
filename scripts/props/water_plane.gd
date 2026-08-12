class_name WaterPlane
extends MeshInstance3D
## Espejo de agua PS1: plano con ruido azulado que se desplaza lento.
## Sin colisión: el kill-zone del player (y < 0.9) hace de barrera (D1 náutico).

var _mat: StandardMaterial3D


func _ready() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(220.0, 220.0)
	plane.subdivide_width = 24
	plane.subdivide_depth = 24
	mesh = plane

	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = 7040
	noise.frequency = 0.05
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.03, 0.07, 0.11))
	gradient.set_color(1, Color(0.08, 0.16, 0.2))
	var tex := NoiseTexture2D.new()
	tex.width = 128
	tex.height = 128
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = gradient

	_mat = StandardMaterial3D.new()
	_mat.albedo_texture = tex
	_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.88)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_mat.roughness = 1.0
	_mat.uv1_scale = Vector3(18.0, 18.0, 1.0)
	material_override = _mat


func _process(delta: float) -> void:
	# Corriente lenta + vaivén: agua "viva" sin shader nuevo (el post la cuantiza).
	var t := Time.get_ticks_msec() / 1000.0
	_mat.uv1_offset.x += delta * 0.012
	_mat.uv1_offset.y = sin(t * 0.35) * 0.05
