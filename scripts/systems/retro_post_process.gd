class_name RetroPostProcess
extends MeshInstance3D
## Quad de pantalla completa con el post-proceso PS1 (shaders/psx_post.gdshader).
## Vive como hijo de la cámara del player. RoundAmbience lo encuentra por el
## grupo "retro_post" y le actualiza la niebla según la hora.

const SHADER := preload("res://shaders/psx_post.gdshader")

var _mat: ShaderMaterial


func _ready() -> void:
	add_to_group("retro_post")
	var quad := QuadMesh.new()
	quad.size = Vector2(2.0, 2.0)
	mesh = quad
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter("fog_color", Color(0.42, 0.45, 0.5))
	_mat.set_shader_parameter("noise_color", Color(0.5, 0.53, 0.58))
	_mat.set_shader_parameter("fog_distance", 55.0)
	_mat.set_shader_parameter("fog_fade_range", 35.0)
	material_override = _mat
	# El vertex shader lo estira a pantalla completa: desactivar el culling.
	# OJO: un AABB de ±1e9 rompía el frustum culling de forma intermitente
	# (el "filtro que desaparece al girar" — playtest 2026-08-12): extremos
	# moderados + sin occlusion + sin sombra.
	custom_aabb = AABB(Vector3(-2000.0, -2000.0, -2000.0), Vector3(4000.0, 4000.0, 4000.0))
	ignore_occlusion_culling = true
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	position = Vector3(0.0, 0.0, -0.5)


func set_fog(color: Color, distance: float, fade: float) -> void:
	if _mat == null:
		return
	_mat.set_shader_parameter("fog_color", color)
	_mat.set_shader_parameter("noise_color", color.lightened(0.12))
	_mat.set_shader_parameter("fog_distance", distance)
	_mat.set_shader_parameter("fog_fade_range", fade)
