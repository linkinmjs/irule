class_name Catalog
extends RefCounted
## Catálogo v2 (M4b §1-2): talentos y tipos de flecha construidos en código
## (sin .tres — estilo del proyecto). Lazy, una sola vez por sesión.

static var _talents: Dictionary = {}
static var _arrows: Dictionary = {}


static func talents() -> Dictionary:
	if _talents.is_empty():
		_build_talents()
	return _talents


static func talent(id: StringName) -> TalentData:
	return talents().get(id, null)


static func arrow_types() -> Dictionary:
	if _arrows.is_empty():
		_build_arrows()
	return _arrows


static func arrow_type(id: StringName) -> ArrowTypeData:
	return arrow_types().get(id, null)


## Árbol v2 — OJO / MANOS / OFICIO, cadenas lineales, 1 punto por rango.
static func _build_talents() -> void:
	# --- OJO (puntería) ---
	_talent(&"ojo_certero", "Ojo certero", "Los headshots pegan un 15% más fuerte por rango.",
		TalentData.Branch.OJO, &"", 2,
		[StatModifier.make(&"headshot_bonus", 0.0, 1.15)])
	_talent(&"pulso_firme", "Pulso firme", "30% menos de dispersión base y a media tensión.",
		TalentData.Branch.OJO, &"ojo_certero", 1,
		[StatModifier.make(&"base_spread", 0.0, 0.7), StatModifier.make(&"low_draw_spread", 0.0, 0.7)])
	_talent(&"ojo_de_halcon", "Ojo de halcón", "La guía de tiro muestra la distancia exacta al blanco.",
		TalentData.Branch.OJO, &"pulso_firme", 1,
		[StatModifier.make(&"guide_level", 1.0)])
	_talent(&"punto_debil", "Punto débil", "Los headshots pegan un 25% más fuerte.",
		TalentData.Branch.OJO, &"ojo_de_halcon", 1,
		[StatModifier.make(&"headshot_bonus", 0.0, 1.25)])

	# --- MANOS (manejo) ---
	_talent(&"manos_rapidas", "Manos rápidas", "Tensás un 15% más rápido por rango.",
		TalentData.Branch.MANOS, &"", 2,
		[StatModifier.make(&"draw_time", 0.0, 0.85)])
	_talent(&"nock_veloz", "Nock veloz", "30% menos de tiempo entre flechas.",
		TalentData.Branch.MANOS, &"manos_rapidas", 1,
		[StatModifier.make(&"renock_time", 0.0, 0.7)])
	_talent(&"paso_de_cazador", "Paso de cazador", "Te movés mejor con el arco tensado.",
		TalentData.Branch.MANOS, &"nock_veloz", 1,
		[StatModifier.make(&"draw_move_mult", 0.15)])
	_talent(&"carcaj_hondo", "Carcaj hondo", "+15 flechas de capacidad.",
		TalentData.Branch.MANOS, &"paso_de_cazador", 1,
		[StatModifier.make(&"quiver_max", 15.0)])

	# --- OFICIO (fletchería y alquimia) ---
	_talent(&"fletcheria", "Fletchería", "Sabés hacer flechas EMPLUMADAS (menos caída, más rango).",
		TalentData.Branch.OFICIO, &"", 1, [], [&"emplumada"])
	_talent(&"alquimia", "Alquimia", "R1: flechas INCENDIARIAS. R2: flechas CONGELANTES.",
		TalentData.Branch.OFICIO, &"fletcheria", 2, [], [&"incendiaria", &"congelante"])
	_talent(&"mezcla_volatil", "Mezcla volátil", "Sabés hacer flechas EXPLOSIVAS (AoE + empujón).",
		TalentData.Branch.OFICIO, &"alquimia", 1, [], [&"explosiva"])
	_talent(&"cosecha", "Cosecha", "+1 material por recolección y por pájaro cazado.",
		TalentData.Branch.OFICIO, &"mezcla_volatil", 1,
		[StatModifier.make(&"harvest_bonus", 1.0)])
	_talent(&"ingenio_prestado", "Ingenio prestado", "+1 trampa activa a la vez.",
		TalentData.Branch.OFICIO, &"cosecha", 1,
		[StatModifier.make(&"trap_limit", 1.0)])


static func _talent(id: StringName, display_name: String, description: String,
		branch: TalentData.Branch, requires: StringName, max_ranks: int,
		modifiers: Array[StatModifier], unlock_arrows: Array[StringName] = []) -> void:
	var data := TalentData.new()
	data.id = id
	data.display_name = display_name
	data.description = description
	data.branch = branch
	data.requires = requires
	data.max_ranks = max_ranks
	data.modifiers = modifiers
	data.unlock_arrows = unlock_arrows
	_talents[id] = data


## Catálogo de flechas v2 (M4b §2) — precios/pesos placeholder, knobs de F7.
static func _build_arrows() -> void:
	var normal := ArrowTypeData.new()
	normal.id = &"normal"
	normal.display_name = "Normal"
	normal.tint = Color(0.9, 0.87, 0.78)
	normal.bundle_size = 10
	normal.bundle_price = 15
	normal.daily_stock = 40
	_arrows[normal.id] = normal

	var feather := ArrowTypeData.new()
	feather.id = &"emplumada"
	feather.display_name = "Emplumada"
	feather.recipe = {&"normal": 1, &"pluma": 3, &"oro": 2}
	feather.gravity_mult = 0.7
	feather.speed_mult = 1.1
	feather.damage_mult = 0.9
	feather.tint = Color(0.7, 0.85, 0.95)
	_arrows[feather.id] = feather

	var fire := ArrowTypeData.new()
	fire.id = &"incendiaria"
	fire.display_name = "Incendiaria"
	fire.recipe = {&"normal": 1, &"flor": 2, &"oro": 5}
	fire.gravity_mult = 1.15
	fire.speed_mult = 0.95
	fire.damage_mult = 0.8
	fire.zone = ArrowTypeData.ZoneEffect.FIRE
	fire.zone_radius = 2.5
	fire.zone_duration = 5.0
	fire.zone_dps = 6.0
	fire.tint = Color(1.0, 0.55, 0.2)
	_arrows[fire.id] = fire

	var frost := ArrowTypeData.new()
	frost.id = &"congelante"
	frost.display_name = "Congelante"
	frost.recipe = {&"normal": 1, &"hongo": 2, &"oro": 5}
	frost.gravity_mult = 1.15
	frost.speed_mult = 0.95
	frost.damage_mult = 0.7
	frost.zone = ArrowTypeData.ZoneEffect.FROST
	frost.zone_radius = 3.0
	frost.zone_duration = 4.0
	frost.zone_slow = 0.45
	frost.tint = Color(0.55, 0.8, 1.0)
	_arrows[frost.id] = frost

	var explosive := ArrowTypeData.new()
	explosive.id = &"explosiva"
	explosive.display_name = "Explosiva"
	explosive.recipe = {&"normal": 1, &"flor": 1, &"hongo": 1, &"oro": 10}
	explosive.gravity_mult = 1.45
	explosive.speed_mult = 0.85
	explosive.damage_mult = 1.0
	explosive.aoe_radius = 3.0
	explosive.aoe_damage = 50.0
	explosive.knockback = 8.0
	explosive.tint = Color(0.95, 0.35, 0.3)
	_arrows[explosive.id] = explosive
