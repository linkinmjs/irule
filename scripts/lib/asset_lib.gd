class_name AssetLib
extends RefCounted
## Extrae piezas individuales de los GLB importados (assets-list.md), corrige
## orientación (varias vienen Z-up) y escala por pieza, las asienta en y=0 y
## re-materializa todo al shader PSX del proyecto (wobble/banding/dissolve
## coherentes). Si una pieza no está, devuelve null → el caller usa su
## fallback de primitivas, así el juego nunca se rompe por un asset.

const DRACULA := "res://assets/quest-defense-assets/Medieval_Dracula_Assets.glb"
const TRAPS := "res://assets/quest-defense-assets/Traps.glb"

## pieza → [glb, rot_x en grados (corrige Z-up), escala uniforme]
## Escalas calibradas con el dump de AABB globales (scripts/tools/dump_scene_tree.gd).
const PIECES := {
	"Gate_Variant_2": [DRACULA, 0.0, 0.55],        # portón 7.1×6.5 → 3.9×3.6 (la Puerta)
	"Gate_Variant_3": [DRACULA, 0.0, 0.6],         # arco en ruinas (nacimiento del camino)
	"Door": [DRACULA, 0.0, 1.0],                   # puerta simple 1.7×3.6
	"Torch_1": [DRACULA, -90.0, 0.32],             # antorcha de pared
	"Brazier_1": [DRACULA, -90.0, 0.5],            # brasero de piso
	"Bed_1": [DRACULA, -90.0, 0.35],               # cama
	"Barrel_1": [DRACULA, -90.0, 0.42],            # barril (pólvora)
	"Box_3": [DRACULA, 0.0, 0.5],                  # cajón (flechas)
	"Gravestone_2": [DRACULA, -90.0, 0.35],        # deco camino
	"Obelisk": [DRACULA, -90.0, 0.5],              # deco recodo
	"Tower": [DRACULA, 90.0, 0.45],                # aguja deco (su eje viene al revés que el resto)
	"Spike_Fence_Variant_1": [DRACULA, 0.0, 0.5],  # barricada deco
	"Column_1": [DRACULA, -90.0, 0.6],             # columna
	"Banner_1": [DRACULA, -90.0, 0.4],             # estandarte de la torre
	"Gargoyle_Var_1": [DRACULA, -90.0, 0.4],       # gárgolas flanqueando la Puerta
	"Lamp_Post": [DRACULA, -90.0, 0.45],           # farol de la meseta
	"Spikes_2": [TRAPS, 0.0, 0.6],                 # trampa de pinchos
	"Stone_Ball_Spiked": [TRAPS, 0.0, 0.4],        # deco
}

static var _roots: Dictionary = {}
static var _psx_cache: Dictionary = {}


## Libera las instancias cacheadas (GameManager lo llama al salir del juego —
## sin esto quedan como leaks reportados al cierre y ensucian el conteo de
## orphan nodes al cazar leaks reales).
static func clear() -> void:
	for root in _roots.values():
		if root != null and is_instance_valid(root):
			root.free()
	_roots.clear()
	_psx_cache.clear()


## Devuelve un wrapper Node3D con la pieza corregida y asentada (base en y=0),
## o null si el GLB/pieza no existe. `unique_materials` da materiales propios
## (para tintar sin afectar otras piezas — la Puerta lo usa).
static func piece(piece_name: String, unique_materials := false) -> Node3D:
	if not PIECES.has(piece_name):
		push_warning("AssetLib: pieza no registrada '%s'" % piece_name)
		return null
	var config: Array = PIECES[piece_name]
	var source := _get_root(config[0])
	if source == null:
		return null
	var original := source.find_child(piece_name, true, false)
	if original == null or not original is MeshInstance3D:
		push_warning("AssetLib: no encontré '%s' en %s" % [piece_name, config[0]])
		return null

	var copy := original.duplicate() as MeshInstance3D
	copy.transform = Transform3D.IDENTITY
	copy.rotation.x = deg_to_rad(config[1])
	copy.scale = Vector3.ONE * config[2]

	var wrapper := Node3D.new()
	wrapper.name = piece_name
	wrapper.add_child(copy)

	# Asentar: el AABB transformado define el offset para que la base toque y=0.
	var aabb: AABB = copy.transform * copy.get_aabb()
	copy.position.y = -aabb.position.y
	wrapper.set_meta("height", aabb.size.y)
	wrapper.set_meta("width", maxf(aabb.size.x, aabb.size.z))

	for mesh_instance in meshes_in(copy):
		_psxify(mesh_instance, unique_materials)
	return wrapper


## Todos los MeshInstance3D bajo un nodo (incluido él mismo).
static func meshes_in(node: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if node is MeshInstance3D:
		result.append(node)
	for child in node.get_children():
		result.append_array(meshes_in(child))
	return result


## Envuelve cada material del GLB en el shader PSX conservando su textura.
static func _psxify(mesh_instance: MeshInstance3D, unique := false) -> void:
	if mesh_instance.mesh == null:
		return
	for i in mesh_instance.mesh.get_surface_count():
		var source_mat := mesh_instance.get_active_material(i)
		if source_mat == null:
			continue
		var key := source_mat.get_instance_id()
		if not unique and _psx_cache.has(key):
			mesh_instance.set_surface_override_material(i, _psx_cache[key])
			continue
		var psx := ShaderMaterial.new()
		psx.shader = PSXMaterials.SHADER
		var albedo: Texture2D = null
		var source_color := Color.WHITE
		if source_mat is BaseMaterial3D:
			albedo = (source_mat as BaseMaterial3D).albedo_texture
			source_color = (source_mat as BaseMaterial3D).albedo_color
		if albedo != null:
			# La textura ya trae el color. NO aplicar el albedo_color del material:
			# en este pack el factor viene negro cuando hay textura (assets negros).
			psx.set_shader_parameter("albedo_tex", albedo)
		else:
			psx.set_shader_parameter("albedo_tex",
				PSXMaterials.stone().get_shader_parameter("albedo_tex"))
			# Sin textura, el color del material es la única información de color.
			if source_color.get_luminance() > 0.03:
				psx.set_shader_parameter("tint", source_color)
		if not unique:
			_psx_cache[key] = psx
		mesh_instance.set_surface_override_material(i, psx)


static func _get_root(path: String) -> Node3D:
	if _roots.has(path):
		return _roots[path]
	if not ResourceLoader.exists(path):
		push_warning("AssetLib: no existe %s (¿falta importar?)" % path)
		_roots[path] = null
		return null
	var packed: PackedScene = load(path)
	if packed == null:
		_roots[path] = null
		return null
	var root := packed.instantiate() as Node3D
	_roots[path] = root
	return root
