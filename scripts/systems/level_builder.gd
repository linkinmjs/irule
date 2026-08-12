class_name LevelBuilder
extends Node3D
## Outpost 01 v4 — mismo lenguaje del boceto de Mauri (D11): camino curvo
## hundido (y=0) en S doble contra el macizo oeste; meseta transitable (y=2.5)
## al este; torre de 2 pisos; la Puerta al sur. Entre los brazos de la S queda
## un ISTMO de meseta con camino a ambos lados — la posición de tiro premium.
##
## v4: el suelo es Terrain3D (relieve orgánico). La forma viene de
## OutpostHeightfield (compartida con el generador y el navmesh); los datos
## viven en res://assets/terrain/outpost_01 y se regeneran con
## scenes/tools/terrain_gen.tscn.
##
## El nivel se puede HORNEAR a escena editable: scenes/tools/bake_runner.tscn
## genera scenes/levels/outpost_01.tscn (main.gd la prefiere si existe).
## Los markers PlayerStart/SpawnPoint se editan moviéndolos en el editor.

const CELL := 2.0
const GRID_MIN := Vector2(-36.0, -72.0)  # (x, z) esquina
const COLS := 35
const ROWS := 36
const PLATEAU_Y := OutpostHeightfield.PLATEAU_Y
const BASE_Y := -0.4
const TERRAIN_DIR := "res://assets/terrain/outpost_01"

enum CellType { PATH, SLOPE, PLATEAU, CLIFF }

var door: TowerDoor
var spawn_center := Vector3(-26.0, 0.0, -70.2)
var player_start := Vector3(9.0, 5.95, -13.0)

var _grid: Dictionary = {}  # Vector2i(ix, iz) → CellType
var _heights: Dictionary = {}  # Vector2i(ix, iz) → altura del terreno en el centro


func _ready() -> void:
	_classify_grid()
	_build_terrain()
	_build_parapets()
	_build_perimeter()
	_build_tower()
	_build_props()
	_build_navmesh()
	_add_marker("PlayerStart", player_start)
	_add_marker("SpawnPoint", spawn_center)


# ------------------------------------------------------------------ grilla

func _cell_center(ix: int, iz: int) -> Vector2:
	return Vector2(GRID_MIN.x + (ix + 0.5) * CELL, GRID_MIN.y + (iz + 0.5) * CELL)


## Clasifica por ALTURA del heightfield (la geometría real del suelo): camino
## en el fondo, taludes de transición, meseta este y macizo oeste.
func _classify_grid() -> void:
	for ix in COLS:
		for iz in ROWS:
			var center := _cell_center(ix, iz)
			var h := OutpostHeightfield.height_at(center.x, center.y)
			_heights[Vector2i(ix, iz)] = h
			var cell_type: CellType
			if h < 0.7:
				cell_type = CellType.PATH
			elif h < PLATEAU_Y - 0.45:
				cell_type = CellType.SLOPE
			elif center.x < OutpostHeightfield.center_x_at_z(center.y):
				cell_type = CellType.CLIFF
			else:
				cell_type = CellType.PLATEAU
			_grid[Vector2i(ix, iz)] = cell_type


func _cell_type(ix: int, iz: int) -> CellType:
	return _grid.get(Vector2i(ix, iz), CellType.CLIFF)


# ------------------------------------------------------------------ terreno

## El suelo completo es un Terrain3D; los datos (regiones .res, assets,
## material) los genera scenes/tools/terrain_gen.tscn en TERRAIN_DIR.
func _build_terrain() -> void:
	var terrain := Terrain3D.new()
	terrain.name = "Terrain"
	if ResourceLoader.exists(TERRAIN_DIR + "/material.tres"):
		terrain.material = load(TERRAIN_DIR + "/material.tres")
	if ResourceLoader.exists(TERRAIN_DIR + "/assets.tres"):
		terrain.assets = load(TERRAIN_DIR + "/assets.tres")
	add_child(terrain)
	# Después de add_child: los setters de región/colisión solo aplican con los
	# objetos internos ya inicializados (antes se pierden en silencio).
	terrain.region_size = Terrain3D.SIZE_64
	terrain.collision_layer = 1
	terrain.collision_mask = 0
	# Colisión completa al cargar: los goblins caminan todo el largo del camino,
	# lejos del radio de la colisión dinámica.
	terrain.collision_mode = Terrain3DCollision.FULL_GAME
	terrain.data_directory = TERRAIN_DIR


## Muro bajo (1.05 m) en los bordes de meseta donde el talud cae fuerte:
## anti-caída sin tapar el tiro en picado (salto 0.75 < 1.05 — D1 sin muros
## invisibles). Con taludes ya no hay borde neto meseta→camino: el criterio es
## el desnivel contra la celda vecina.
func _build_parapets() -> void:
	var offsets: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	var count := 0
	for ix in COLS:
		for iz in ROWS:
			if _cell_type(ix, iz) != CellType.PLATEAU:
				continue
			var own_h: float = _heights[Vector2i(ix, iz)]
			var center := _cell_center(ix, iz)
			for off in offsets:
				var nx: int = ix + off.x
				var nz: int = iz + off.y
				if nx < 0 or nx >= COLS or nz < 0 or nz >= ROWS:
					continue
				var drop: float = own_h - _heights.get(Vector2i(nx, nz), own_h)
				if drop < 1.0:
					continue
				var horizontal: bool = off.y == 0
				var size := Vector3(0.3, 1.05, CELL) if horizontal else Vector3(CELL, 1.05, 0.3)
				var pos := Vector3(center.x, own_h + 0.525, center.y)
				if horizontal:
					pos.x += off.x * (CELL * 0.5 - 0.15)
				else:
					pos.z += off.y * (CELL * 0.5 - 0.15)
				_solid_box("Parapet%d" % count, size, pos, "stone")
				count += 1


func _build_perimeter() -> void:
	var top := 8.0
	var wall_height := top - BASE_Y
	var wall_y := BASE_Y + wall_height * 0.5
	# Oeste y este.
	_solid_box("PerimW", Vector3(1.0, wall_height, 76.0), Vector3(-36.5, wall_y, -36.0), "stone_dark")
	_solid_box("PerimE", Vector3(1.0, wall_height, 76.0), Vector3(34.5, wall_y, -36.0), "stone_dark")
	# Norte con boca de spawn (hueco x ∈ [-28.5, -23.5]).
	_solid_box("PerimN_W", Vector3(8.5, wall_height, 1.0), Vector3(-32.75, wall_y, -72.5), "stone_dark")
	_solid_box("PerimN_E", Vector3(58.5, wall_height, 1.0), Vector3(5.75, wall_y, -72.5), "stone_dark")
	_solid_box("PerimN_Lintel", Vector3(5.0, top - 3.0, 1.0), Vector3(-26.0, 3.0 + (top - 3.0) * 0.5, -72.5), "stone_dark")
	var mouth := MeshInstance3D.new()
	mouth.name = "SpawnMouth"
	var mouth_mesh := BoxMesh.new()
	mouth_mesh.size = Vector3(4.6, 3.0, 0.2)
	mouth.mesh = mouth_mesh
	mouth.position = Vector3(-26.0, 1.48, -72.05)
	var black := StandardMaterial3D.new()
	black.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	black.albedo_color = Color(0.01, 0.01, 0.02)
	mouth.material_override = black
	add_child(mouth)

	# Sur con el hueco de la Puerta (x ∈ [-2, 2]).
	_solid_box("Facade_W", Vector3(35.0, wall_height, 1.0), Vector3(-19.5, wall_y, 0.5), "stone")
	_solid_box("Facade_E", Vector3(33.0, wall_height, 1.0), Vector3(18.5, wall_y, 0.5), "stone")
	_solid_box("Facade_Lintel", Vector3(4.0, top - 3.6, 1.0), Vector3(0.0, 3.6 + (top - 3.6) * 0.5, 0.5), "stone")

	door = TowerDoor.new()
	door.name = "TowerDoor"
	add_child(door)
	door.position = Vector3(0.0, 0.0, -0.2)


# ------------------------------------------------------------------ torre (2 pisos)

func _build_tower() -> void:
	# Planta 5×5 sobre la meseta: x ∈ [6.5, 11.5], z ∈ [-15.5, -10.5].
	var wall_height := 6.85 - PLATEAU_Y
	var wall_y := PLATEAU_Y + wall_height * 0.5
	_solid_box("TowerN", Vector3(5.0, wall_height, 0.4), Vector3(9.0, wall_y, -15.3), "stone")
	_solid_box("TowerS", Vector3(5.0, wall_height, 0.4), Vector3(9.0, wall_y, -10.7), "stone")
	_solid_box("TowerE", Vector3(0.4, wall_height, 4.2), Vector3(11.3, wall_y, -13.0), "stone")
	_solid_box("TowerW_S", Vector3(0.4, wall_height, 1.7), Vector3(6.7, wall_y, -14.65), "stone")
	_solid_box("TowerW_N", Vector3(0.4, wall_height, 1.7), Vector3(6.7, wall_y, -11.35), "stone")
	var lintel_h := 6.85 - (PLATEAU_Y + 2.2)
	_solid_box("TowerW_Lintel", Vector3(0.4, lintel_h, 1.6), Vector3(6.7, PLATEAU_Y + 2.2 + lintel_h * 0.5, -13.0), "stone")

	# Losa del balcón con hueco de escalera (franja este x ∈ [9.9, 11.1]).
	_solid_box("TowerDeck", Vector3(3.0, 0.4, 4.2), Vector3(8.4, 5.6, -13.0), "stone_floor")

	# Escalera interior pegada al muro este, de sur (y 2.5) a norte (y 5.8).
	for i in 8:
		var step_h := (i + 1) * 0.4125
		_solid_box("TowerStep%d" % i, Vector3(1.2, step_h, 0.425),
			Vector3(10.5, PLATEAU_Y + step_h * 0.5, -11.7 - (i + 0.5) * 0.425), "stone_dark", false)
	var ramp := StaticBody3D.new()
	ramp.name = "TowerStairRamp"
	ramp.collision_layer = 1
	ramp.collision_mask = 0
	var ramp_shape := BoxShape3D.new()
	ramp_shape.size = Vector3(1.3, 0.3, 4.9)
	var ramp_col := CollisionShape3D.new()
	ramp_col.shape = ramp_shape
	ramp.add_child(ramp_col)
	add_child(ramp)
	ramp.position = Vector3(10.5, PLATEAU_Y + 1.65, -13.4)
	ramp.rotation.x = atan2(3.3, 3.4)

	var bed := Bed.new()
	bed.name = "Bed"
	add_child(bed)
	bed.position = Vector3(8.0, PLATEAU_Y, -14.4)

	var crate := ArrowCrate.new()
	crate.name = "ArrowCrate"
	add_child(crate)
	crate.position = Vector3(7.4, PLATEAU_Y, -11.4)

	var crate_deck := ArrowCrate.new()
	crate_deck.name = "ArrowCrateDeck"
	add_child(crate_deck)
	crate_deck.position = Vector3(7.3, 5.8, -11.5)

	_torch(Vector3(6.95, PLATEAU_Y + 2.1, -14.2), PI * 0.5)
	_deco("Banner_1", Vector3(6.3, PLATEAU_Y + 0.9, -13.0), -PI * 0.5)
	_brazier(Vector3(8.0, 5.8, -11.3))


# ------------------------------------------------------------------ props

func _build_props() -> void:
	var dummy := TrainingDummy.new()
	dummy.name = "TrainingDummy"
	add_child(dummy)
	dummy.position = _ground(4.0, -18.0)

	# Trampas en el camino (D8; anclajes elegibles llegan en M4).
	var spike_positions := [_ground(-10.0, -48.0), _ground(0.0, -11.0)]
	for i in spike_positions.size():
		var spikes := SpikeTrap.new()
		spikes.name = "SpikeTrap%d" % i
		add_child(spikes)
		spikes.position = spike_positions[i]

	var barrel_positions := [
		_ground(-24.3, -60.5), _ground(-17.5, -52.3),
		_ground(-9.5, -33.5), _ground(2.2, -7.5),
	]
	for i in barrel_positions.size():
		var barrel := PowderBarrel.new()
		barrel.name = "Barrel%d" % i
		add_child(barrel)
		barrel.position = barrel_positions[i]

	# Antorchas del camino, plantadas en el talud del macizo (oeste).
	for i in range(1, OutpostHeightfield.WAYPOINTS.size() - 1):
		var wp: Vector2 = OutpostHeightfield.WAYPOINTS[i]
		_torch(_ground(wp.x - 4.2, wp.y, 1.7), -PI * 0.5)

	# Deco del pack sobre la meseta y el istmo (falla silencioso sin GLB).
	_deco("Gargoyle_Var_1", _ground(4.5, -2.2), PI)
	_deco("Obelisk", _ground(2.5, -26.0), 0.0)
	_deco("Obelisk", _ground(0.0, -44.0), 0.6)
	_deco("Spike_Fence_Variant_1", _ground(-10.5, -29.0), 0.4)
	_deco("Spike_Fence_Variant_1", _ground(-2.0, -52.0), -0.5)
	_deco("Lamp_Post", _ground(6.0, -8.0), 0.0)
	_deco("Lamp_Post", _ground(-2.0, -35.0), 0.0)
	_deco("Gravestone_2", _ground(9.5, -24.0), 0.5)
	_deco("Gravestone_2", _ground(11.0, -22.6), -0.3)
	_deco("Gravestone_2", _ground(0.0, -57.0), 0.9)
	_deco("Tower", _ground(13.5, -17.5), 0.0)
	_deco("Stone_Ball_Spiked", _ground(4.6, -6.2), 0.0)
	_brazier(_ground(0.0, -20.0))
	_brazier(_ground(5.2, -13.0))
	_brazier(_ground(3.0, -1.8))
	_brazier(_ground(-11.5, -26.0))
	_brazier(_ground(-8.0, -56.0))


# ------------------------------------------------------------------ navegación

func _build_navmesh() -> void:
	var region := NavigationRegion3D.new()
	region.name = "PathNav"
	var mesh := NavigationMesh.new()
	var vert_index: Dictionary = {}
	var vertices := PackedVector3Array()
	for ix in COLS:
		for iz in ROWS:
			if _cell_type(ix, iz) != CellType.PATH:
				continue
			var x0 := GRID_MIN.x + ix * CELL
			var z0 := GRID_MIN.y + iz * CELL
			var poly := PackedInt32Array([
				_vert(vert_index, vertices, x0, z0),
				_vert(vert_index, vertices, x0, z0 + CELL),
				_vert(vert_index, vertices, x0 + CELL, z0 + CELL),
				_vert(vert_index, vertices, x0 + CELL, z0),
			])
			mesh.add_polygon(poly)
	mesh.vertices = vertices
	region.navigation_mesh = mesh
	add_child(region)


func _vert(index: Dictionary, vertices: PackedVector3Array, x: float, z: float) -> int:
	var key := Vector2i(roundi(x * 2.0), roundi(z * 2.0))
	if index.has(key):
		return index[key]
	var i := vertices.size()
	vertices.append(Vector3(x, OutpostHeightfield.height_at(x, z) + 0.1, z))
	index[key] = i
	return i


# ------------------------------------------------------------------ helpers

## Punto apoyado sobre el terreno (opcionalmente elevado `lift` m).
func _ground(x: float, z: float, lift := 0.0) -> Vector3:
	return Vector3(x, OutpostHeightfield.height_at(x, z) + lift, z)


func _solid_box(box_name: String, size: Vector3, center: Vector3, mat_key: String, with_collision := true) -> void:
	var mi := MeshInstance3D.new()
	mi.name = box_name
	var mesh := BoxMesh.new()
	mesh.size = size
	# Subdividir cada ~2 m: el warp affine sobre triángulos gigantes genera
	# bandas estiradas — PS1 real subdividía por esto mismo.
	mesh.subdivide_width = clampi(int(size.x / 2.0), 0, 20)
	mesh.subdivide_height = clampi(int(size.y / 2.0), 0, 20)
	mesh.subdivide_depth = clampi(int(size.z / 2.0), 0, 20)
	mi.mesh = mesh
	mi.material_override = _mat_for(mat_key, size)
	if with_collision:
		var body := StaticBody3D.new()
		body.name = box_name + "Body"
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := BoxShape3D.new()
		shape.size = size
		var col := CollisionShape3D.new()
		col.shape = shape
		body.add_child(col)
		body.add_child(mi)
		add_child(body)
		body.position = center
	else:
		add_child(mi)
		mi.position = center


func _mat_for(key: String, size: Vector3) -> ShaderMaterial:
	var uv: Vector2
	if size.y < 0.6:
		uv = Vector2(size.x, size.z) * 0.5
	else:
		uv = Vector2(maxf(size.x, size.z), size.y) * 0.5
	uv = Vector2(maxf(uv.x, 1.0), maxf(uv.y, 1.0))
	return PSXMaterials.scaled(key, uv)


func _torch(pos: Vector3, yaw: float) -> void:
	var torch := TorchLight.new()
	add_child(torch)
	torch.position = pos
	torch.rotation.y = yaw


func _brazier(pos: Vector3) -> void:
	var brazier := TorchLight.new()
	brazier.piece_name = "Brazier_1"
	add_child(brazier)
	brazier.position = pos


func _deco(piece_name: String, pos: Vector3, yaw: float) -> void:
	var piece := AssetLib.piece(piece_name)
	if piece == null:
		return
	add_child(piece)
	piece.position = pos
	piece.rotation.y = yaw


func _add_marker(marker_name: String, pos: Vector3) -> void:
	var marker := Marker3D.new()
	marker.name = marker_name
	add_child(marker)
	marker.position = pos
