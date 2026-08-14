class_name OutpostHeightfield
extends RefCounted
## Campo de alturas de Outpost 01 v2 — boceto de islas (2026-08-12):
## AGUA alrededor (lecho y=-1.5, espejo visual y=-0.5), el camino de los
## enemigos es un TERRAPLÉN (y=0) en S que serpentea entre dos islas:
## la isla del jugador (y=2.5, con la torre de vigilancia) y la isla del
## aliado al norte. El Portón al sur, con su explanada a y=0.
##
## La MISMA función la usan el generador de Terrain3D
## (scenes/tools/terrain_gen.tscn), el navmesh y el apoyo de props en
## LevelBuilder — el terreno horneado y el gameplay no pueden desincronizarse.

const WATER_BED := -1.5   ## lecho bajo el agua
const WATER_LEVEL := -0.5 ## espejo de agua visual (WaterPlane)
const PATH_Y := 0.0
const ISLAND_Y := 2.5
const PLATEAU_Y := ISLAND_Y  # alias para el código existente
const PATH_HALF_WIDTH := 3.2
const BANK := 3.4         ## talud terraplén → agua
const MAX_Y := 3.6

## Mapa v3 (2026-08-12): ×2 en superficie (140×144 m), isla del jugador más
## grande (r14 — con lugar para el farming de flores y pájaros del rediseño).
const PLAYER_ISLAND := Vector2(4.0, -30.0)
const PLAYER_ISLAND_R := 14.0
const ALLY_ISLAND := Vector2(-16.0, -114.0)
const ALLY_ISLAND_R := 9.0

## Centerline del camino, de norte (spawn en la niebla) a sur (Portón).
## (x, z) — z monotónico. Bordea la isla aliada por el este y la del jugador
## por el oeste, con brecha de agua no saltable (D1 náutico).
const WAYPOINTS := [
	Vector2(0.0, -140.0),
	Vector2(6.0, -126.0),
	Vector2(2.0, -114.0),
	Vector2(-4.0, -100.0),
	Vector2(-14.0, -88.0),
	Vector2(-24.0, -76.0),
	Vector2(-28.0, -62.0),
	Vector2(-24.0, -50.0),
	Vector2(-20.0, -36.0),
	Vector2(-17.0, -22.0),
	Vector2(-14.0, -10.0),
	Vector2(-12.0, -2.0),
]

static var _detail_noise: FastNoiseLite


static func height_at(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d := path_distance(p)
	# Terraplén del camino que cae al lecho del agua.
	var h := lerpf(PATH_Y, WATER_BED,
		smoothstep(PATH_HALF_WIDTH - 0.6, PATH_HALF_WIDTH + BANK, d))
	# Ondulación fina: casi nula sobre el camino, suave en orillas y lecho.
	var amp := lerpf(0.04, 0.28, smoothstep(PATH_HALF_WIDTH, PATH_HALF_WIDTH + 4.0, d))
	h += _detail().get_noise_2d(x, z) * amp
	# Las islas emergen del agua.
	h = _pad_circle(h, p, PLAYER_ISLAND, PLAYER_ISLAND_R, 4.0, ISLAND_Y)
	h = _pad_circle(h, p, ALLY_ISLAND, ALLY_ISLAND_R, 3.0, ISLAND_Y)
	# Pie de torre plano (dentro de la isla del jugador).
	h = _pad_rect(h, p, Rect2(0.5, -33.5, 7.0, 7.0), ISLAND_Y, 2.0)
	# Explanada del Portón amplia (la cola de ataque necesita superficie seca;
	# angosta, el RVO tiraba a media horda al agua) y punto de spawn.
	h = _pad_rect(h, p, Rect2(-19.5, -7.5, 15.0, 8.0), PATH_Y, 2.5)
	h = _pad_circle(h, p, Vector2(0.0, -140.0), 4.0, 3.0, PATH_Y)
	return clampf(h, WATER_BED - 0.4, MAX_Y)


static func path_distance(p: Vector2) -> float:
	var best := INF
	for i in WAYPOINTS.size() - 1:
		var a: Vector2 = WAYPOINTS[i]
		var b: Vector2 = WAYPOINTS[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


## x de la centerline a un z dado (los waypoints son monotónicos en z).
static func center_x_at_z(z: float) -> float:
	if z <= WAYPOINTS[0].y:
		return WAYPOINTS[0].x
	for i in WAYPOINTS.size() - 1:
		var a: Vector2 = WAYPOINTS[i]
		var b: Vector2 = WAYPOINTS[i + 1]
		if z >= a.y and z <= b.y:
			var t := (z - a.y) / maxf(b.y - a.y, 0.001)
			return lerpf(a.x, b.x, t)
	return WAYPOINTS[WAYPOINTS.size() - 1].x


## Aplana hacia `target` dentro del rect, con fundido de `feather` m afuera.
static func _pad_rect(h: float, p: Vector2, rect: Rect2, target: float, feather: float) -> float:
	var closest := Vector2(
		clampf(p.x, rect.position.x, rect.end.x),
		clampf(p.y, rect.position.y, rect.end.y))
	var t := smoothstep(0.0, feather, p.distance_to(closest))
	return lerpf(target, h, t)


static func _pad_circle(h: float, p: Vector2, center: Vector2, radius: float, feather: float, target: float) -> float:
	var t := smoothstep(radius, radius + feather, p.distance_to(center))
	return lerpf(target, h, t)


static func _detail() -> FastNoiseLite:
	if _detail_noise == null:
		_detail_noise = FastNoiseLite.new()
		_detail_noise.noise_type = FastNoiseLite.TYPE_PERLIN
		_detail_noise.seed = 60517
		_detail_noise.frequency = 0.06
	return _detail_noise
