class_name ArcherStats
extends Resource
## Stats FINALES del arquero (M4b §1). Las BASES son exactamente los valores
## validados del gunfeel (M1 + balística v2 + apuntado v3): sin talentos, el
## juego se siente idéntico a antes de M4b. NO tocar bases sin re-validar.

const BASES := {
	&"draw_time": 0.65,
	&"renock_time": 0.35,
	&"arrow_speed_min": 14.0,
	&"arrow_speed_max": 42.0,
	&"arrow_damage_min": 18.0,
	&"arrow_damage_max": 55.0,
	&"headshot_bonus": 1.0,     # multiplicador EXTRA del player (el goblin aplica su 2.5 aparte)
	&"base_spread": 0.3,
	&"move_spread": 3.4,
	&"air_spread": 2.4,
	&"low_draw_spread": 7.0,
	&"quiver_max": 30.0,
	&"trap_limit": 2.0,
	&"gravity": 13.0,
	&"draw_move_mult": 0.55,
	&"guide_level": 0.0,        # ojo_de_halcon: 1 = distancia numérica en la guía
	&"harvest_bonus": 0.0,      # cosecha (F3): +N por recolección/pájaro
}

var draw_time := 0.65
var renock_time := 0.35
var arrow_speed_min := 14.0
var arrow_speed_max := 42.0
var arrow_damage_min := 18.0
var arrow_damage_max := 55.0
var headshot_bonus := 1.0
var base_spread := 0.3
var move_spread := 3.4
var air_spread := 2.4
var low_draw_spread := 7.0
var quiver_max := 30
var trap_limit := 2
var gravity := 13.0
var draw_move_mult := 0.55
var guide_level := 0
var harvest_bonus := 0


## Resetea a bases y aplica suma de adds → producto de mults, por stat.
func recompute(modifiers: Array[StatModifier]) -> void:
	var adds := {}
	var mults := {}
	for modifier in modifiers:
		adds[modifier.stat] = adds.get(modifier.stat, 0.0) + modifier.add
		mults[modifier.stat] = mults.get(modifier.stat, 1.0) * modifier.mult
	for stat_name in BASES:
		var value: float = (BASES[stat_name] + adds.get(stat_name, 0.0)) \
			* mults.get(stat_name, 1.0)
		match stat_name:
			&"quiver_max":
				quiver_max = roundi(value)
			&"trap_limit":
				trap_limit = roundi(value)
			&"guide_level":
				guide_level = roundi(value)
			&"harvest_bonus":
				harvest_bonus = roundi(value)
			_:
				set(stat_name, value)
