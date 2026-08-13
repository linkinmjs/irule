class_name LevelBuilder
extends Node3D
## Outpost 01 v5 — boceto de islas (2026-08-12): AGUA alrededor, el camino de
## los enemigos serpentea en S entre la isla del ALIADO (norte) y NUESTRA isla
## (con la torre de vigilancia). El Portón al sur con su tramo de muralla que
## se hunde en el agua. Sin muros perimetrales: la niebla y el agua limitan la
## visión y el movimiento (D1 náutico: caer al agua te devuelve a la torre).
##
## Un puente elevado (y=2.5) conecta la isla con la plataforma de mantenimiento
## sobre el Portón — cruza POR ENCIMA del camino (los goblins pasan debajo).
##
## El suelo es Terrain3D; la forma viene de OutpostHeightfield (compartida con
## el generador y el navmesh); los datos viven en res://assets/terrain/outpost_01
## y se regeneran con scenes/tools/terrain_gen.tscn.
##
## Hornear a escena editable: scenes/tools/bake_runner.tscn →
## scenes/levels/outpost_01.tscn (main.gd la prefiere si existe).

const CELL := 2.0
const GRID_MIN := Vector2(-72.0, -144.0)  # (x, z) esquina — mapa v3: 140×144 m
const COLS := 70
const ROWS := 72
const ISLAND_Y := OutpostHeightfield.ISLAND_Y
const TERRAIN_DIR := "res://assets/terrain/outpost_01"

enum CellType { WATER, PATH, SLOPE, PLATEAU }

var door: TowerDoor
var spawn_center := Vector3(0.0, 0.0, -140.0)
var player_start := Vector3(4.0, 5.95, -30.0)

var _grid: Dictionary = {}  # Vector2i(ix, iz) → CellType
var _heights: Dictionary = {}


func _ready() -> void:
	_classify_grid()
	_build_terrain()
	_build_water()
	_build_gate_wall()
	_build_tower()
	_build_ally_island()
	_build_bridge()
	_build_props()
	_build_navmesh()
	_add_marker("PlayerStart", player_start)
	_add_marker("SpawnPoint", spawn_center)


# ------------------------------------------------------------------ grilla

func _cell_center(ix: int, iz: int) -> Vector2:
	return Vector2(GRID_MIN.x + (ix + 0.5) * CELL, GRID_MIN.y + (iz + 0.5) * CELL)


## Clasifica por ALTURA del heightfield. Clave: el lecho del agua NO es camino
## (el navmesh solo toma PATH: terraplén entre -0.4 y 0.7).
func _classify_grid() -> void:
	for ix in COLS:
		for iz in ROWS:
			var center := _cell_center(ix, iz)
			var h := OutpostHeightfield.height_at(center.x, center.y)
			_heights[Vector2i(ix, iz)] = h
			var cell_type: CellType
			if h <= -0.4:
				cell_type = CellType.WATER
			elif h < 0.7:
				cell_type = CellType.PATH
			elif h < ISLAND_Y - 0.45:
				cell_type = CellType.SLOPE
			else:
				cell_type = CellType.PLATEAU
			_grid[Vector2i(ix, iz)] = cell_type


func _cell_type(ix: int, iz: int) -> CellType:
	return _grid.get(Vector2i(ix, iz), CellType.WATER)


# ------------------------------------------------------------------ terreno y agua

func _build_terrain() -> void:
	var terrain := Terrain3D.new()
	terrain.name = "Terrain"
	if ResourceLoader.exists(TERRAIN_DIR + "/material.tres"):
		terrain.material = load(TERRAIN_DIR + "/material.tres")
	if ResourceLoader.exists(TERRAIN_DIR + "/assets.tres"):
		terrain.assets = load(TERRAIN_DIR + "/assets.tres")
	add_child(terrain)
	# Después de add_child: los setters solo aplican con los internos inicializados.
	terrain.region_size = Terrain3D.SIZE_64
	terrain.collision_layer = 1
	terrain.collision_mask = 0
	# Colisión completa al cargar: los goblins caminan todo el largo del camino.
	terrain.collision_mode = Terrain3DCollision.FULL_GAME
	terrain.data_directory = TERRAIN_DIR


## Espejo de agua PS1: plano con ruido que se desplaza (WaterPlane lo anima).
## Sin colisión — el "borde del mundo" es la niebla + el kill-zone del player.
func _build_water() -> void:
	var water := WaterPlane.new()
	water.name = "Water"
	add_child(water)
	water.position = Vector3(0.0, OutpostHeightfield.WATER_LEVEL, -72.0)


# ------------------------------------------------------------------ muralla del Portón

## Solo el tramo sur alrededor del Portón (x -16..4, hueco x -8..-4); los
## extremos se hunden en el agua — la muralla es una ruina parcial, como el
## boceto. El resto del perímetro es agua y niebla.
func _build_gate_wall() -> void:
	var top := 8.0
	var base := -1.6
	var wall_height := top - base
	var wall_y := base + wall_height * 0.5
	_solid_box("GateWall_W", Vector3(8.0, wall_height, 1.0), Vector3(-18.0, wall_y, 0.5), "stone")
	_solid_box("GateWall_E", Vector3(8.0, wall_height, 1.0), Vector3(-6.0, wall_y, 0.5), "stone")
	_solid_box("GateWall_Lintel", Vector3(4.0, top - 3.6, 1.0), Vector3(-12.0, 3.6 + (top - 3.6) * 0.5, 0.5), "stone")

	door = TowerDoor.new()
	door.name = "TowerDoor"
	add_child(door)
	door.position = Vector3(-12.0, 0.0, -0.2)

	# Plataforma de mantenimiento sobre el Portón (y=2.5): desde acá se repara
	# y se tira en picado por la machicolación (los goblins pegan debajo).
	_solid_box("GatePlatform", Vector3(6.0, 0.3, 2.4), Vector3(-12.0, 2.35, -1.9), "stone_floor")
	_solid_box("GatePlatformRail", Vector3(6.0, 0.5, 0.15), Vector3(-12.0, 2.75, -3.05), "stone_dark")


# ------------------------------------------------------------------ torre de vigilancia (nuestra isla)

func _build_tower() -> void:
	# Planta 5×5 en el centro de la isla: x ∈ [1.5, 6.5], z ∈ [-32.5, -27.5].
	var wall_height := 6.85 - ISLAND_Y
	var wall_y := ISLAND_Y + wall_height * 0.5
	_solid_box("TowerN", Vector3(5.0, wall_height, 0.4), Vector3(4.0, wall_y, -32.3), "stone")
	_solid_box("TowerS", Vector3(5.0, wall_height, 0.4), Vector3(4.0, wall_y, -27.7), "stone")
	_solid_box("TowerE", Vector3(0.4, wall_height, 4.2), Vector3(6.3, wall_y, -30.0), "stone")
	_solid_box("TowerW_S", Vector3(0.4, wall_height, 1.7), Vector3(1.7, wall_y, -31.65), "stone")
	_solid_box("TowerW_N", Vector3(0.4, wall_height, 1.7), Vector3(1.7, wall_y, -28.35), "stone")
	var lintel_h := 6.85 - (ISLAND_Y + 2.2)
	_solid_box("TowerW_Lintel", Vector3(0.4, lintel_h, 1.6), Vector3(1.7, ISLAND_Y + 2.2 + lintel_h * 0.5, -30.0), "stone")

	# Losa del balcón con hueco de escalera (franja este x ∈ [4.9, 6.1]).
	_solid_box("TowerDeck", Vector3(3.0, 0.4, 4.2), Vector3(3.4, 5.6, -30.0), "stone_floor")

	# Escalera interior pegada al muro este, de sur (y 2.5) a norte (y 5.8).
	for i in 8:
		var step_h := (i + 1) * 0.4125
		_solid_box("TowerStep%d" % i, Vector3(1.2, step_h, 0.425),
			Vector3(5.5, ISLAND_Y + step_h * 0.5, -28.7 - (i + 0.5) * 0.425), "stone_dark", false)
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
	ramp.position = Vector3(5.5, ISLAND_Y + 1.65, -30.4)
	ramp.rotation.x = atan2(3.3, 3.4)

	var bed := Bed.new()
	bed.name = "Bed"
	add_child(bed)
	bed.position = Vector3(3.0, ISLAND_Y, -31.4)

	var crate := ArrowCrate.new()
	crate.name = "ArrowCrate"
	add_child(crate)
	crate.position = Vector3(2.4, ISLAND_Y, -28.4)

	var crate_deck := ArrowCrate.new()
	crate_deck.name = "ArrowCrateDeck"
	add_child(crate_deck)
	crate_deck.position = Vector3(2.3, 5.8, -28.5)

	_torch(Vector3(1.95, ISLAND_Y + 2.1, -31.2), PI * 0.5)
	_deco("Banner_1", Vector3(1.3, ISLAND_Y + 0.9, -30.0), -PI * 0.5)
	_brazier(Vector3(3.0, 5.8, -28.3))


# ------------------------------------------------------------------ isla aliada

## Torre compacta del aliado (bloque macizo + parapeto) con el arquero arriba.
## "Nuestro aliado dispara desde acá" — preview del sistema de torres de M5.
func _build_ally_island() -> void:
	var c := OutpostHeightfield.ALLY_ISLAND
	_solid_box("AllyTowerBody", Vector3(4.0, 3.8, 4.0), Vector3(c.x, ISLAND_Y + 1.9, c.y), "stone")
	_solid_box("AllyTowerDeck", Vector3(4.4, 0.3, 4.4), Vector3(c.x, ISLAND_Y + 3.95, c.y), "stone_floor")
	for side in [-1.0, 1.0]:
		_solid_box("AllyRailX%d" % int(side), Vector3(4.4, 0.6, 0.2),
			Vector3(c.x, ISLAND_Y + 4.4, c.y + side * 2.1), "stone_dark")
		_solid_box("AllyRailZ%d" % int(side), Vector3(0.2, 0.6, 4.4),
			Vector3(c.x + side * 2.1, ISLAND_Y + 4.4, c.y), "stone_dark")

	var ally := AllyArcher.new()
	ally.name = "AllyArcher"
	add_child(ally)
	ally.position = Vector3(c.x, ISLAND_Y + 4.1, c.y)

	_deco("Banner_1", Vector3(c.x - 2.15, ISLAND_Y + 1.2, c.y), PI * 0.5)
	_brazier(Vector3(c.x + 1.4, ISLAND_Y + 4.1, c.y + 1.4))
	_deco("Gravestone_2", _ground(c.x - 3.5, c.y + 3.0), 0.7)
	_deco("Tower", _ground(c.x - 2.5, c.y - 3.5), 0.0)


# ------------------------------------------------------------------ puente

## Pasarela elevada (top y=2.5) de nuestra isla a la plataforma del Portón.
## Cruza sobre el camino: clearance ~2.2 m, los goblins pasan por debajo.
func _build_bridge() -> void:
	var from := Vector2(1.5, -16.5)   # borde sur de la isla
	var to := Vector2(-10.5, -3.4)    # borde norte de la plataforma
	var mid := (from + to) * 0.5
	var span := from.distance_to(to)
	var yaw := atan2(to.x - from.x, to.y - from.y)

	var bridge := StaticBody3D.new()
	bridge.name = "Bridge"
	bridge.collision_layer = 1
	bridge.collision_mask = 0
	add_child(bridge)
	bridge.position = Vector3(mid.x, 2.35, mid.y)
	bridge.rotation.y = yaw

	var deck_shape := BoxShape3D.new()
	deck_shape.size = Vector3(1.6, 0.3, span + 0.6)
	var deck_col := CollisionShape3D.new()
	deck_col.shape = deck_shape
	bridge.add_child(deck_col)
	var deck := MeshInstance3D.new()
	var deck_mesh := BoxMesh.new()
	deck_mesh.size = deck_shape.size
	deck_mesh.subdivide_depth = clampi(int(span / 2.0), 0, 20)
	deck.mesh = deck_mesh
	deck.material_override = PSXMaterials.scaled("wood", Vector2(span * 0.5, 1.0))
	bridge.add_child(deck)

	# Barandas bajas (deco: caer al agua = kill-zone igual) y pilotes al lecho.
	for side in [-1.0, 1.0]:
		var rail := MeshInstance3D.new()
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(0.09, 0.45, span + 0.6)
		rail_mesh.subdivide_depth = clampi(int(span / 2.0), 0, 20)
		rail.mesh = rail_mesh
		rail.position = Vector3(side * 0.75, 0.35, 0.0)
		rail.material_override = PSXMaterials.wood_dark()
		bridge.add_child(rail)
		for t in [-0.32, 0.0, 0.32]:
			var pile := MeshInstance3D.new()
			var pile_mesh := BoxMesh.new()
			pile_mesh.size = Vector3(0.22, 4.2, 0.22)
			pile.mesh = pile_mesh
			pile.position = Vector3(side * 0.6, -2.1, span * t)
			pile.material_override = PSXMaterials.wood_dark()
			bridge.add_child(pile)


# ------------------------------------------------------------------ props

func _build_props() -> void:
	var dummy := TrainingDummy.new()
	dummy.name = "TrainingDummy"
	add_child(dummy)
	dummy.position = _ground(9.0, -31.5)

	# Trampas en el camino (D8; anclajes elegibles llegan en M4).
	var spike_positions := [_ground(-27.5, -63.0), _ground(-3.5, -101.0)]
	for i in spike_positions.size():
		var spikes := SpikeTrap.new()
		spikes.name = "SpikeTrap%d" % i
		add_child(spikes)
		spikes.position = spike_positions[i]

	var barrel_positions := [_ground(-24.3, -75.0), _ground(-19.8, -36.5)]
	for i in barrel_positions.size():
		var barrel := PowderBarrel.new()
		barrel.name = "Barrel%d" % i
		add_child(barrel)
		barrel.position = barrel_positions[i]

	# Antorchas del camino: postes en el borde oeste del terraplén.
	for i in range(1, OutpostHeightfield.WAYPOINTS.size() - 1):
		var wp: Vector2 = OutpostHeightfield.WAYPOINTS[i]
		_torch(_ground(wp.x - 2.6, wp.y, 1.7), -PI * 0.5)

	# Arco en ruinas en el nacimiento del camino: de ahí emergen, entre la niebla.
	_deco("Gate_Variant_3", _ground(0.0, -139.3), 0.0)

	# Deco de las islas y la explanada (falla silencioso sin GLB).
	_deco("Gargoyle_Var_1", _ground(-8.5, -2.2), PI)
	_deco("Obelisk", _ground(10.0, -36.0), 0.6)
	_deco("Lamp_Post", _ground(-2.0, -24.0), 0.0)
	_deco("Gravestone_2", _ground(11.0, -25.5), 0.5)
	_deco("Stone_Ball_Spiked", _ground(8.0, -35.8), 0.0)
	_deco("Spike_Fence_Variant_1", _ground(-16.5, -4.5), 0.3)
	_deco("Spike_Fence_Variant_1", _ground(-7.5, -5.0), -0.4)
	_brazier(_ground(9.5, -27.0))
	_brazier(_ground(0.0, -33.5))
	_brazier(_ground(-16.8, -1.5))


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
