extends Node
## Estado del mundo (GDD §4): reloj, fases del día, día actual, oro y stats nocturnas.
## El tiempo interno usa horas 8.0..27.0 (27.0 == 03:00 del día siguiente, congelación).

signal hour_changed(clock_hour: int)
signal phase_changed(phase: Phase)
signal day_started(day: int)
signal night_started(day: int)
signal time_frozen
signal gold_changed(gold: int)
signal xp_gained(amount: int)
signal xp_changed(xp: int, next_level_xp: int, level: int)
signal level_up(level: int)

enum Phase { DAY, DUSK, NIGHT, FROZEN }

const DAY_START_HOUR := 8.0
const DUSK_HOUR := 20.0
const NIGHT_HOUR := 21.0
const FREEZE_HOUR := 27.0  # 03:00

## Ritmo (GDD §14.1 — se afina jugando M3): día ~5 min, noche ~5.5 min.
@export var day_seconds_per_hour := 25.0
@export var night_seconds_per_hour := 55.0

var day := 1
var hour := DAY_START_HOUR
var phase: Phase = Phase.DAY
var gold := 60
var xp := 0
var level := 1

# Stats para el pergamino del amanecer (GDD §4.1).
var kills_tonight := 0
var headshots_tonight := 0
var gold_earned_today := 0
var door_damage_tonight := 0.0

var _last_hour_int := int(DAY_START_HOUR)
var _default_day_sph := 25.0
var _default_night_sph := 55.0


func _ready() -> void:
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.door_damaged.connect(_on_door_damaged)
	# Flags de debug: `godot -- --fast-clock --start-night` (probar el ciclo sin esperar).
	var args := OS.get_cmdline_user_args()
	if args.has("--fast-clock"):
		day_seconds_per_hour = 0.5
		night_seconds_per_hour = 12.0
	if args.has("--start-night"):
		hour = 20.5
	for arg in args:
		if arg.begins_with("--night-secs="):
			night_seconds_per_hour = float(arg.get_slice("=", 1))
	# Los flags CLI definen los defaults de la sesión; reset() vuelve a ellos
	# (el reloj rápido del DebugMenu no debe sobrevivir a "Nueva partida").
	_default_day_sph = day_seconds_per_hour
	_default_night_sph = night_seconds_per_hour
	if args.has("--quit-at-freeze"):
		time_frozen.connect(_debug_quit_after_freeze)


func _debug_quit_after_freeze() -> void:
	await get_tree().create_timer(8.0).timeout
	get_tree().quit()


func _process(delta: float) -> void:
	if phase == Phase.FROZEN or get_tree().paused:
		return
	var seconds_per_hour := day_seconds_per_hour if phase == Phase.DAY else night_seconds_per_hour
	hour += delta / seconds_per_hour
	_update_phase()
	if int(hour) != _last_hour_int:
		_last_hour_int = int(hour)
		hour_changed.emit(clock_hour())


func clock_hour() -> int:
	return int(hour) % 24


func clock_minute() -> int:
	return int(fmod(hour, 1.0) * 60.0)


func clock_text() -> String:
	return "%02d:%02d" % [clock_hour(), clock_minute()]


func is_day() -> bool:
	return phase == Phase.DAY


func add_gold(amount: int) -> void:
	gold += amount
	if amount > 0:
		gold_earned_today += amount
	gold_changed.emit(gold)


func try_spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	gold_changed.emit(gold)
	return true


## XP del arquero (D15): la otorgan las flechas al acertar y los kills.
## En M4b los niveles alimentarán puntos de talento.
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


## Llamado por GameManager al confirmar el despertar (GDD §4.1: dormir sella el día).
func advance_day() -> void:
	day += 1
	hour = DAY_START_HOUR
	_last_hour_int = int(hour)
	kills_tonight = 0
	headshots_tonight = 0
	gold_earned_today = 0
	door_damage_tonight = 0.0
	phase = Phase.DAY
	phase_changed.emit(phase)
	day_started.emit(day)
	hour_changed.emit(clock_hour())


## Nueva partida (desde el menú de pausa o tras game over).
func reset(starting_day := 1, starting_gold := 60) -> void:
	day = starting_day
	gold = starting_gold
	xp = 0
	level = 1
	hour = DAY_START_HOUR
	_last_hour_int = int(hour)
	phase = Phase.DAY
	kills_tonight = 0
	headshots_tonight = 0
	gold_earned_today = 0
	door_damage_tonight = 0.0
	day_seconds_per_hour = _default_day_sph
	night_seconds_per_hour = _default_night_sph


func _update_phase() -> void:
	var new_phase := phase
	if hour >= FREEZE_HOUR:
		hour = FREEZE_HOUR
		new_phase = Phase.FROZEN
	elif hour >= NIGHT_HOUR:
		new_phase = Phase.NIGHT
	elif hour >= DUSK_HOUR:
		new_phase = Phase.DUSK
	else:
		new_phase = Phase.DAY
	if new_phase == phase:
		return
	phase = new_phase
	phase_changed.emit(phase)
	match phase:
		Phase.NIGHT:
			night_started.emit(day)
		Phase.FROZEN:
			time_frozen.emit()


func _on_enemy_killed(enemy: Node3D, headshot: bool) -> void:
	kills_tonight += 1
	if headshot:
		headshots_tonight += 1
	# El botín lo define el enemigo (élites pagan más); el headshot suma un extra.
	var bounty := 10
	if "bounty" in enemy:
		bounty = enemy.bounty
	add_gold(bounty + (5 if headshot else 0))
	add_xp(8)  # kill bonus (D15) — el impacto ya pagó su XP


func _on_door_damaged(_current: float, _maximum: float) -> void:
	# El monto exacto lo acumula la puerta; acá solo registramos que hubo daño.
	pass
