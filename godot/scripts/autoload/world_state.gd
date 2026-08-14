extends Node
## Estado del mundo v3 (D17 "RONDAS"): el juego avanza por rondas, no por días.
## CLEARED (intermedio libre: comprar, reparar, talentos, farmear) → la cama
## inicia la siguiente → PREP (10 s de gracia con countdown) → ASSAULT (la
## horda de la ronda) → al caer el último goblin, CLEARED de nuevo.
## Cada ronda define sus características: ambiente/color, clima y horda
## progresiva. XP, oro y munición también viven acá.

signal round_started(round_number: int)    # entra PREP (características seteadas)
signal assault_started(round_number: int)  # fin del countdown: spawns
signal round_cleared(round_number: int)    # último goblin muerto
signal gold_changed(gold: int)
signal xp_gained(amount: int)
signal xp_changed(xp: int, next_level_xp: int, level: int)
signal level_up(level: int)
signal ammo_changed(type: StringName, count: int)

enum RoundPhase { PREP, ASSAULT, CLEARED }

const PREP_SECONDS := 10.0  # knob: duración de la gracia inicial (a pulir)

## Ambientes (color/hora ligados — D17) y climas posibles.
const AMBIENCE_CYCLE: Array[StringName] = [
	&"amanecer", &"mediodia", &"atardecer", &"anochecer", &"luna", &"noche_cerrada",
]
const WEATHERS: Array[StringName] = [&"despejado", &"neblina", &"bruma_roja"]

var round_number := 0  # 0 = pre-juego (intermedio inicial, la cama inicia la 1)
var round_phase: RoundPhase = RoundPhase.CLEARED
var prep_remaining := 0.0
var current_round: Dictionary = {}

var gold := 60
var xp := 0
var level := 1

# Munición por tipo (F2/M4b): las normales se compran en el cajón (stock por ronda).
var ammo: Dictionary = {&"normal": 30}
var shop_stock: Dictionary = {}

# Stats de la ronda en curso (para el pergamino del intermedio).
var kills_this_round := 0
var headshots_this_round := 0
var gold_earned_this_round := 0
var door_damage_this_round := 0.0

var _auto_rounds := false


func _ready() -> void:
	EventBus.enemy_killed.connect(_on_enemy_killed)
	# Flags de debug/CI: --auto-rounds encadena rondas solo (headless),
	# --skip-prep acorta la gracia a 0.5 s, --quit-at-round=N corta la corrida.
	var args := OS.get_cmdline_user_args()
	_auto_rounds = args.has("--auto-rounds")
	if args.has("--skip-prep"):
		prep_remaining = 0.0
	var quit_at := 0
	for arg in args:
		if arg.begins_with("--quit-at-round="):
			quit_at = int(arg.get_slice("=", 1))
	if quit_at > 0:
		round_cleared.connect(func(n: int) -> void:
			if n >= quit_at:
				print("[ci] ronda %d superada — fin de la corrida" % n)
				get_tree().quit())
	if _auto_rounds:
		round_cleared.connect(func(_n: int) -> void:
			get_tree().create_timer(2.0, false).timeout.connect(func() -> void: start_round()))
		get_tree().create_timer(2.0, false).timeout.connect(func() -> void:
			if round_number == 0:
				start_round())


## Etiqueta corta para logs de debug: "R3·prep 7s" / "R3·asalto" / "R3·libre".
func round_tag() -> String:
	match round_phase:
		RoundPhase.PREP:
			return "R%d·prep %ds" % [round_number, ceili(prep_remaining)]
		RoundPhase.ASSAULT:
			return "R%d·asalto" % round_number
		_:
			return "R%d·libre" % round_number


func _process(delta: float) -> void:
	if round_phase != RoundPhase.PREP or get_tree().paused:
		return
	prep_remaining -= delta
	if prep_remaining <= 0.0:
		round_phase = RoundPhase.ASSAULT
		assault_started.emit(round_number)


## Inicia la ronda `n` (o la siguiente): setea características y arranca PREP.
func start_round(n := -1) -> void:
	round_number = n if n > 0 else round_number + 1
	current_round = round_info(round_number)
	round_phase = RoundPhase.PREP
	var args := OS.get_cmdline_user_args()
	prep_remaining = 0.5 if args.has("--skip-prep") else PREP_SECONDS
	kills_this_round = 0
	headshots_this_round = 0
	gold_earned_this_round = 0
	door_damage_this_round = 0.0
	_refresh_shop_stock()  # el cajón repone su stock cada ronda (las flechas NO)
	round_started.emit(round_number)


## La llama el spawner cuando la horda fue derrotada.
func clear_round() -> void:
	if round_phase != RoundPhase.ASSAULT:
		return
	round_phase = RoundPhase.CLEARED
	round_cleared.emit(round_number)


func combat_active() -> bool:
	return round_phase == RoundPhase.ASSAULT


## Características de la ronda (D17): deterministas por número.
## `special` cada 5 rondas — el evento lo maneja RoundEvents (mago, etc.).
func round_info(n: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7000 + n * 131
	return {
		"number": n,
		"ambience": AMBIENCE_CYCLE[(n - 1) % AMBIENCE_CYCLE.size()],
		"weather": WEATHERS[rng.randi() % WEATHERS.size()],
		"enemy_count": 6 + n * 3,
		"elites": maxi(n - 2, 0),
		"special": n > 0 and n % 5 == 0,
	}


# ------------------------------------------------------------------ recursos

func add_gold(amount: int) -> void:
	gold += amount
	if amount > 0:
		gold_earned_this_round += amount
	gold_changed.emit(gold)


func try_spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


func ammo_count(type: StringName) -> int:
	return int(ammo.get(type, 0))


func add_ammo(type: StringName, amount: int) -> void:
	var cap := 999
	if type == &"normal":
		cap = Progression.stats.quiver_max
	ammo[type] = clampi(ammo_count(type) + amount, 0, cap)
	ammo_changed.emit(type, ammo[type])


func try_spend_ammo(type: StringName, amount := 1) -> bool:
	if ammo_count(type) < amount:
		return false
	ammo[type] = ammo_count(type) - amount
	ammo_changed.emit(type, ammo[type])
	return true


## Compra de un paquete en el cajón (solo tipos con bundle — la normal).
func try_buy_ammo(type: StringName) -> bool:
	var data := Catalog.arrow_type(type)
	if data == null or data.bundle_size <= 0:
		return false
	if int(shop_stock.get(type, 0)) < data.bundle_size:
		return false
	if ammo_count(type) >= Progression.stats.quiver_max:
		return false
	if not try_spend_gold(data.bundle_price):
		return false
	shop_stock[type] = int(shop_stock.get(type, 0)) - data.bundle_size
	add_ammo(type, data.bundle_size)
	return true


func _refresh_shop_stock() -> void:
	for id in Catalog.arrow_types():
		var data: ArrowTypeData = Catalog.arrow_types()[id]
		if data.daily_stock > 0:
			shop_stock[id] = data.daily_stock


## XP del arquero (D15): la otorgan las flechas al acertar y los kills.
func xp_for_next() -> int:
	return 40 + (level - 1) * 25


func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	xp_gained.emit(amount)
	while xp >= xp_for_next():
		xp -= xp_for_next()
		level += 1
		level_up.emit(level)
	xp_changed.emit(xp, xp_for_next(), level)


## Nueva partida.
func reset(starting_round := 0, starting_gold := 60) -> void:
	round_number = starting_round
	round_phase = RoundPhase.CLEARED
	current_round = round_info(maxi(round_number, 1))
	prep_remaining = 0.0
	gold = starting_gold
	xp = 0
	level = 1
	kills_this_round = 0
	headshots_this_round = 0
	gold_earned_this_round = 0
	door_damage_this_round = 0.0
	ammo = {&"normal": 30}
	_refresh_shop_stock()
	ammo_changed.emit(&"normal", 30)


func _on_enemy_killed(enemy: Node3D, headshot: bool) -> void:
	kills_this_round += 1
	if headshot:
		headshots_this_round += 1
	# El botín lo define el enemigo (élites pagan más); el headshot suma un extra.
	var bounty := 10
	if "bounty" in enemy:
		bounty = enemy.bounty
	add_gold(bounty + (5 if headshot else 0))
	add_xp(8)  # kill bonus (D15) — el impacto ya pagó su XP
