extends Node
## Genera los datos de Terrain3D de Outpost 01 desde OutpostHeightfield y los
## guarda en res://assets/terrain/outpost_01 (regiones .res + assets/material).
##
## Correr (necesita el proyecto cargado, por eso es una escena):
##   godot --path . --headless res://scenes/tools/terrain_gen.tscn
##
## Re-correr PISA el relieve dentro del área generada (retoques manuales de
## esculpido incluidos). assets.tres y material.tres solo se crean si faltan,
## así los ajustes de texturas/material sobreviven a un re-gen.

const DATA_DIR := "res://assets/terrain/outpost_01"
## Área mínima a cubrir: la grilla del nivel (x -36..34, z -72..0) con margen
## hasta pasar las murallas. El área real se expande a múltiplos de región
## porque import_images ancla cada rebanada al ORIGEN de su región — la
## posición de import debe estar alineada a la grilla de regiones.
const WORLD_MIN := Vector2(-80.0, -152.0)
const WORLD_MAX := Vector2(76.0, 8.0)

## Slots de textura: 0/1 los usa el auto-shader (plano/empinado), 2 se pinta
## en el control map sobre la meseta.
const TEX_DIRT := 0
const TEX_STONE_DARK := 1
const TEX_STONE_FLOOR := 2


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DATA_DIR)
	var terrain := Terrain3D.new()
	terrain.material = _load_or_make_material()
	terrain.assets = _load_or_make_assets()
	add_child(terrain)
	# Después de add_child: el setter solo propaga a los datos ya inicializados.
	terrain.region_size = Terrain3D.SIZE_64
	terrain.data_directory = DATA_DIR

	# Expandir el área a múltiplos de región (ver nota en WORLD_MIN).
	var rs: int = terrain.region_size
	var x0 := floori(WORLD_MIN.x / rs) * rs
	var z0 := floori(WORLD_MIN.y / rs) * rs
	var w := ceili((WORLD_MAX.x - x0) / rs) * rs
	var d := ceili((WORLD_MAX.y - z0) / rs) * rs

	var height_img := Image.create(w, d, false, Image.FORMAT_RF)
	var control_img := Image.create(w, d, false, Image.FORMAT_RF)
	var auto_bits := Terrain3DUtil.enc_auto(true)
	var plateau_bits := Terrain3DUtil.enc_base(TEX_STONE_FLOOR) \
		| Terrain3DUtil.enc_overlay(TEX_DIRT) | Terrain3DUtil.enc_blend(0) \
		| Terrain3DUtil.enc_auto(false)
	var h_min := INF
	var h_max := -INF
	for py in d:
		for px in w:
			var x := float(x0 + px)
			var z := float(z0 + py)
			var h := OutpostHeightfield.height_at(x, z)
			h_min = minf(h_min, h)
			h_max = maxf(h_max, h)
			height_img.set_pixel(px, py, Color(h, 0.0, 0.0))
			var bits := plateau_bits if _is_plateau_floor(x, z, h) else auto_bits
			control_img.set_pixel(px, py, Color(Terrain3DUtil.as_float(bits), 0.0, 0.0))

	terrain.data.import_images([height_img, control_img, null],
		Vector3(x0, 0.0, z0), 0.0, 1.0)
	# Recalcular los rangos de altura por región: el frustum culling de los
	# chunks usa estas cajas — desactualizadas, chunks visibles se descartan
	# intermitentemente ("cuadrado gris parpadeante en el piso", 2026-08-13).
	terrain.data.calc_height_range(true)
	terrain.data.save_directory(DATA_DIR)

	# Chequeos de humo: alturas conocidas tras el import.
	print("TERRAIN_GEN region_size=%d regiones=%s" % [rs, terrain.data.get_region_locations()])
	print("TERRAIN_GEN alturas [%.2f, %.2f] -> %s" % [h_min, h_max, DATA_DIR])
	print("TERRAIN_GEN torre(2,-20)=%.2f (esperado 2.5)  spawn(0,-70)=%.2f (esperado 0)  agua(20,-40)=%.2f (esperado ~-1.5)  aliado(-8,-57)=%.2f (esperado 2.5)" % [
		terrain.data.get_height(Vector3(2.0, 0.0, -20.0)),
		terrain.data.get_height(Vector3(0.0, 0.0, -70.0)),
		terrain.data.get_height(Vector3(20.0, 0.0, -40.0)),
		terrain.data.get_height(Vector3(-8.0, 0.0, -57.0)),
	])
	get_tree().quit()


## El piso de las islas se pinta stone_floor; camino, taludes y lecho del agua
## quedan en auto-shader (dirt plano / stone_dark empinado).
func _is_plateau_floor(_x: float, _z: float, h: float) -> bool:
	return h >= OutpostHeightfield.ISLAND_Y - 0.45 and h <= OutpostHeightfield.ISLAND_Y + 0.9


func _load_or_make_material() -> Terrain3DMaterial:
	var path := DATA_DIR + "/material.tres"
	if ResourceLoader.exists(path):
		return load(path)
	var mat := Terrain3DMaterial.new()
	mat.auto_shader = true
	ResourceSaver.save(mat, path)
	return mat


func _load_or_make_assets() -> Terrain3DAssets:
	var path := DATA_DIR + "/assets.tres"
	if ResourceLoader.exists(path):
		return load(path)
	var assets := Terrain3DAssets.new()
	# Paleta v2 cálida (2026-08-12): tierra rojiza, roca parda, PASTO en las
	# islas (el gris uniforme apagaba el mapa; el pasto prepara el farming).
	assets.set_texture(TEX_DIRT, _texture_asset(TEX_DIRT, "dirt",
		Color(0.33, 0.24, 0.15), Color(0.46, 0.35, 0.22), 0.18))
	assets.set_texture(TEX_STONE_DARK, _texture_asset(TEX_STONE_DARK, "stone_dark",
		Color(0.27, 0.24, 0.22), Color(0.38, 0.34, 0.31), 0.1))
	assets.set_texture(TEX_STONE_FLOOR, _texture_asset(TEX_STONE_FLOOR, "grass",
		Color(0.19, 0.29, 0.13), Color(0.33, 0.43, 0.2), 0.22))
	ResourceSaver.save(assets, path)
	return assets


func _texture_asset(id: int, tex_name: String, color_a: Color, color_b: Color, freq: float) -> Terrain3DTextureAsset:
	var ta := Terrain3DTextureAsset.new()
	ta.name = tex_name
	ta.id = id
	ta.albedo_texture = _noise_albedo(color_a, color_b, freq, id)
	ta.uv_scale = 0.5  # ~1 tile cada 2 m, como la densidad de los boxes PSX
	return ta


## Textura seamless 64×64 desde FastNoiseLite mapeada al ramp de color, con la
## altura fake en el alfa (Terrain3D la usa para el blend por altura).
func _noise_albedo(color_a: Color, color_b: Color, freq: float, seed_offset: int) -> Texture2D:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_PERLIN
	n.seed = 94959 + seed_offset
	n.frequency = freq
	var gray := n.get_seamless_image(64, 64)
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var v := gray.get_pixel(x, y).r
			var c := color_a.lerp(color_b, v)
			c.a = 0.35 + 0.3 * v
			img.set_pixel(x, y, c)
	img.generate_mipmaps()
	var tex := PortableCompressedTexture2D.new()
	# Sin esto, fuera del editor el buffer se descarta y el .tres queda vacío.
	tex.keep_compressed_buffer = true
	tex.create_from_image(img, PortableCompressedTexture2D.COMPRESSION_MODE_LOSSLESS)
	return tex
