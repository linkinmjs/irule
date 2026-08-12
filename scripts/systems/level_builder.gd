class_name LevelBuilder
extends Node3D
## Outpost 01 v3 — nivel ampliado (70×72 m, el doble del v2), mismo lenguaje del
## boceto de Mauri (D11): camino curvo hundido (y=0) en S doble contra el macizo
## oeste; superficie superior transitable (y=2.5) al este; torre de 2 pisos;
## la Puerta al sur. Entre los dos brazos de la S queda un ISTMO de meseta con
## camino a ambos lados — la posición de tiro premium.
##
## El nivel se puede HORNEAR a escena editable: scripts/tools/bake_level.gd
## genera scenes/levels/outpost_01.tscn (main.gd la prefiere si existe).
## Los markers PlayerStart/SpawnPoint se editan moviéndolos en el editor.

const CELL := 2.0
const GRID_MIN := Vector2(-36.0, -72.0)  # (x, z) esquina
const COLS := 35
const ROWS := 36
const PATH_HALF_WIDTH := 3.2
const PLATEAU_Y := 2.5
const CLIFF_Y := 6.0
const BASE_Y := -0.4

## Centerline del camino, de norte (spawn) a sur (Puerta). (x, z) — z monotónico.
const WAYPOINTS := [
	Vector2(-26.0, -69.0),
	Vector2(-24.0, -61.0),
	Vector2(-18.0, -54.0),
	Vector2(-10.0, -48.0),
	Vector2(-5.0, -41.0),
	Vector2(-9.0, -34.0),
	Vector2(-16.0, -28.0),
	Vector2(-14.0, -20.0),
	Vector2(-7.0, -15.0),
	Vector2(0.0, -11.0),
	Vector2(3.0, -7.0),
	Vector2(0.0, -1.0),
]

enum CellType { PATH, PLATEAU, CLIFF }

var door: TowerDoor
var spawn_center := Vector3(-26.0, 0.0, -70.2)
var player_start := Vector3(9.0, 5.95, -13.0)

var _grid: Dictionary = {}  # Vector2i(ix, iz) → CellType


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


## Macizo SIEMPRE al oeste de la centerline: la meseta este queda conexa y los
## recodos de la S generan el istmo con camino de ambos lados.
func _classify_grid() -> void:
	for ix in COLS:
		for iz in ROWS:
			var center := _cell_center(ix, iz)
			var cell_type: CellType
			if _path_distance(center) <= PATH_HALF_WIDTH:
				cell_type = CellType.PATH
			elif center.x < _center_x_at_z(center.y):
				cell_type = CellType.CLIFF
			else:
				cell_type = CellType.PLATEAU
			_grid[Vector2i(ix, iz)] = cell_type


func _path_distance(p: Vector2) -> float:
	var best := INF
	for i in WAYPOINTS.size() - 1:
		var a: Vector2 = WAYPOINTS[i]
		var b: Vector2 = WAYPOINTS[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


## x de la centerline a un z dado (los waypoints son monotónicos en z).
func _center_x_at_z(z: float) -> float:
	if z <= WAYPOINTS[0].y:
		return WAYPOINTS[0].x
	for i in WAYPOINTS.size() - 1:
		var a: Vector2 = WAYPOINTS[i]
		var b: Vector2 = WAYPOINTS[i + 1]
		if z >= a.y and z <= b.y:
			var t := (z - a.y) / maxf(b.y - a.y, 0.001)
			return lerpf(a.x, b.x, t)
	return WAYPOINTS[WAYPOINTS.size() - 1].x


func _cell_type(ix: int, iz: int) -> CellType:
	return _grid.get(Vector2i(ix, iz), CellType.CLIFF)


# ------------------------------------------------------------------ terreno

func _build_terrain() -> void:
	# Merge por filas: runs consecutivos del mismo tipo → un solo box.
	for iz in ROWS:
		var run_start := 0
		while run_start < COLS:
			var run_type := _cell_type(run_start, iz)
			var run_end := run_start
			while run_end + 1 < COLS and _cell_type(run_end + 1, iz) == run_type:
				run_end += 1
			_terrain_box(run_start, run_end, iz, run_type)
			run_start = run_end + 1


func _terrain_box(ix0: int, ix1: int, iz: int, cell_type: CellType) -> void:
	var top := 0.0
	var mat := "dirt"
	match cell_type:
		CellType.PLATEAU:
			top = PLATEAU_Y
			mat = "stone_floor"
		CellType.CLIFF:
			top = CLIFF_Y
			mat = "stone_dark"
	var width := (ix1 - ix0 + 1) * CELL
	var height := top - BASE_Y
	var center := Vector3(
		GRID_MIN.x + ix0 * CELL + width * 0.5,
		BASE_Y + height * 0.5,
		GRID_MIN.y + (iz + 0.5) * CELL
	)
	_solid_box("T_%d_%d" % [ix0, iz], Vector3(width, height, CELL), center, mat)


## Muro bajo (1.05 m) en cada borde meseta→camino: anti-caída sin tapar el tiro
## en picado (salto 0.75 < 1.05 — D1 sin muros invisibles).
func _build_parapets() -> void:
	var offsets: Array[Vector2i] = [Vector2i(0, -1), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(1, 0)]
	var count := 0
	for ix in COLS:
		for iz in ROWS:
			if _cell_type(ix, iz) != CellType.PLATEAU:
				continue
			var center := _cell_center(ix, iz)
			for off in offsets:
				var nx: int = ix + off.x
				var nz: int = iz + off.y
				if nx < 0 or nx >= COLS or nz < 0 or nz >= ROWS:
					continue
				if _cell_type(nx, nz) != CellType.PATH:
					continue
				var horizontal: bool = off.y == 0
				var size := Vector3(0.3, 1.05, CELL) if horizontal else Vector3(CELL, 1.05, 0.3)
				var pos := Vector3(center.x, PLATEAU_Y + 0.525, center.y)
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
	dummy.position = Vector3(4.0, PLATEAU_Y, -18.0)

	# Trampas en el camino (D8; anclajes elegibles llegan en M4).
	var spike_positions := [Vector3(-10.0, 0.0, -48.0), Vector3(0.0, 0.0, -11.0)]
	for i in spike_positions.size():
		var spikes := SpikeTrap.new()
		spikes.name = "SpikeTrap%d" % i
		add_child(spikes)
		spikes.position = spike_positions[i]

	var barrel_positions := [
		Vector3(-24.3, 0.0, -60.5), Vector3(-17.5, 0.0, -52.3),
		Vector3(-9.5, 0.0, -33.5), Vector3(2.2, 0.0, -7.5),
	]
	for i in barrel_positions.size():
		var barrel := PowderBarrel.new()
		barrel.name = "Barrel%d" % i
		add_child(barrel)
		barrel.position = barrel_positions[i]

	# Antorchas del camino, pegadas al lado del macizo (oeste).
	for i in range(1, WAYPOINTS.size() - 1):
		var wp: Vector2 = WAYPOINTS[i]
		_torch(Vector3(wp.x - 2.6, 2.6, wp.y), -PI * 0.5)

	# Deco del pack sobre la meseta y el istmo (falla silencioso sin GLB).
	_deco("Gargoyle_Var_1", Vector3(4.5, PLATEAU_Y, -2.2), PI)
	_deco("Obelisk", Vector3(2.5, PLATEAU_Y, -26.0), 0.0)
	_deco("Obelisk", Vector3(0.0, PLATEAU_Y, -44.0), 0.6)
	_deco("Spike_Fence_Variant_1", Vector3(-10.5, PLATEAU_Y, -29.0), 0.4)
	_deco("Spike_Fence_Variant_1", Vector3(-2.0, PLATEAU_Y, -52.0), -0.5)
	_deco("Lamp_Post", Vector3(6.0, PLATEAU_Y, -8.0), 0.0)
	_deco("Lamp_Post", Vector3(-2.0, PLATEAU_Y, -35.0), 0.0)
	_deco("Gravestone_2", Vector3(9.5, PLATEAU_Y, -24.0), 0.5)
	_deco("Gravestone_2", Vector3(11.0, PLATEAU_Y, -22.6), -0.3)
	_deco("Gravestone_2", Vector3(0.0, PLATEAU_Y, -57.0), 0.9)
	_deco("Tower", Vector3(13.5, PLATEAU_Y, -17.5), 0.0)
	_deco("Stone_Ball_Spiked", Vector3(4.6, PLATEAU_Y, -6.2), 0.0)
	_brazier(Vector3(0.0, PLATEAU_Y, -20.0))
	_brazier(Vector3(5.2, PLATEAU_Y, -13.0))
	_brazier(Vector3(3.0, PLATEAU_Y, -1.8))
	_brazier(Vector3(-11.5, PLATEAU_Y, -26.0))
	_brazier(Vector3(-8.0, PLATEAU_Y, -56.0))


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
	vertices.append(Vector3(x, 0.05, z))
	index[key] = i
	return i


# ------------------------------------------------------------------ helpers

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
