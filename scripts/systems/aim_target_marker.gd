class_name AimTargetMarker
extends MeshInstance3D
## La diana flotante (D14 v2, estilo "Lucky Shot"): aparece SOBRE el objetivo
## apuntado cuando tensás lo suficiente, elevada exactamente lo que la flecha
## va a caer — apuntarle A LA DIANA pone la flecha en la cabeza. Con la mira
## dentro de la diana se enciende dorada (+tic): soltar ahí = tiro perfecto.
## La caída de la flecha, visualizada: cuanto más lejos, más alto el blanco.

const SIZE := 0.6
const HOT_COLOR := Color(1.0, 0.85, 0.35)
const COLD_COLOR := Color(1.0, 1.0, 1.0)

var _mat: StandardMaterial3D
var _hot := false


func _ready() -> void:
	top_level = true
	visible = false
	var quad := QuadMesh.new()
	quad.size = Vector2(SIZE, SIZE)
	mesh = quad
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_mat.albedo_texture = _make_target_texture()
	_mat.no_depth_test = true  # la diana se ve siempre (es UI del mundo)
	_mat.render_priority = 10
	material_override = _mat


func _process(_delta: float) -> void:
	if visible and _hot:
		var t := Time.get_ticks_msec() / 1000.0
		scale = Vector3.ONE * (1.0 + sin(t * 12.0) * 0.06)


func update_marker(pos: Vector3, hot: bool) -> void:
	visible = true
	global_position = pos
	if hot and not _hot:
		AudioManager.play_ui("hitmarker", -10.0, 0.02, 1.6)  # tic de "soltá ahora"
	_hot = hot
	_mat.albedo_color = HOT_COLOR if hot else COLD_COLOR
	if not hot:
		scale = Vector3.ONE


func hide_marker() -> void:
	visible = false
	_hot = false
	scale = Vector3.ONE


## Diana clásica roja/blanca de 32×32, generada por código (nearest = chunky PS1).
func _make_target_texture() -> ImageTexture:
	var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
	var red := Color(0.85, 0.2, 0.15)
	var bone := Color(0.95, 0.92, 0.85)
	for y in 32:
		for x in 32:
			var d := Vector2(x - 15.5, y - 15.5).length()
			var color := Color(0, 0, 0, 0)
			if d < 3.0:
				color = red
			elif d < 6.5:
				color = bone
			elif d < 10.0:
				color = red
			elif d < 13.5:
				color = bone
			elif d < 15.5:
				color = red
			img.set_pixel(x, y, color)
	return ImageTexture.create_from_image(img)
