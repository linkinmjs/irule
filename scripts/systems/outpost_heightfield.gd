class_name OutpostHeightfield
extends RefCounted
## Campo de alturas de Outpost 01. La MISMA función la usan el generador de
## Terrain3D (scenes/tools/terrain_gen.tscn), el navmesh y el apoyo de props en
## LevelBuilder — el terreno horneado y la lógica de gameplay no pueden
## desincronizarse.
##
## Lenguaje del boceto D11: camino hundido (y=0) en S doble, meseta transitable
## al este (y=2.5), macizo oeste (y=6) — con taludes y ruido en vez de cortes
## verticales. Zonas planas garantizadas: pie de torre, boca de spawn y Puerta.

const PATH_Y := 0.0
const PLATEAU_Y := 2.5
const CLIFF_Y := 6.0
const PATH_HALF_WIDTH := 3.2
const BANK_EAST := 3.6  ## ancho del talud camino→meseta
const BANK_WEST := 6.0  ## ancho del talud camino→macizo
const MAX_Y := 7.0  ## tope: el relieve no debe asomar sobre la muralla (y=8)

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

static var _detail_noise: FastNoiseLite
static var _relief_noise: FastNoiseLite


static func height_at(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var d := path_distance(p)
	var side := x - center_x_at_z(z)  # >0: este (meseta), <0: oeste (macizo)
	var h_east := lerpf(PATH_Y, PLATEAU_Y,
		smoothstep(PATH_HALF_WIDTH - 0.6, PATH_HALF_WIDTH + BANK_EAST, d))
	var h_west := lerpf(PATH_Y, CLIFF_Y,
		smoothstep(PATH_HALF_WIDTH - 0.6, PATH_HALF_WIDTH + BANK_WEST, d))
	var h := lerpf(h_west, h_east, smoothstep(-2.0, 2.0, side))
	# Ondulación fina: casi nula sobre el camino para no ensuciar la navegación.
	var amp := lerpf(0.05, 0.35, smoothstep(PATH_HALF_WIDTH, PATH_HALF_WIDTH + 3.0, d))
	h += _detail().get_noise_2d(x, z) * amp
	# Relieve amplio solo sobre el macizo (se apaga por debajo de la meseta).
	h += _relief().get_noise_2d(x, z) * smoothstep(PLATEAU_Y + 0.8, CLIFF_Y, h)
	h = _pad_rect(h, p, Rect2(5.5, -16.5, 7.0, 7.0), PLATEAU_Y, 3.0)  # torre
	h = _pad_circle(h, p, Vector2(-26.0, -70.2), 3.5, 3.0, PATH_Y)  # spawn
	h = _pad_rect(h, p, Rect2(-3.0, -6.0, 6.0, 6.5), PATH_Y, 2.5)  # Puerta
	return minf(h, MAX_Y)


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


static func _relief() -> FastNoiseLite:
	if _relief_noise == null:
		_relief_noise = FastNoiseLite.new()
		_relief_noise.noise_type = FastNoiseLite.TYPE_PERLIN
		_relief_noise.seed = 41207
		_relief_noise.frequency = 0.025
	return _relief_noise
