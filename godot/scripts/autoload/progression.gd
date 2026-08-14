extends Node
## La carrera del defensor (D6/D13, M4b): puntos de talento, talentos aprendidos
## y las ArcherStats derivadas — SIEMPRE recomputadas, los consumidores solo leen
## `Progression.stats`. Frontera: WorldState es el asedio; esto es la carrera.
## Fuentes de puntos: el amanecer (GameManager) y los niveles de XP (D15).

signal points_changed(points: int)
signal talent_learned(id: StringName, rank: int)
signal stats_changed

var points := 0
var talents: Dictionary = {}  # id → rango
var stats := ArcherStats.new()


func _ready() -> void:
	WorldState.level_up.connect(_on_level_up)
	reset()


func _on_level_up(_new_level: int) -> void:
	grant_points(1)
	EventBus.announcement.emit("+1 punto de talento — [T]")


func rank_of(id: StringName) -> int:
	return talents.get(id, 0)


func can_learn(id: StringName) -> bool:
	var data := Catalog.talent(id)
	if data == null or points <= 0:
		return false
	if rank_of(id) >= data.max_ranks:
		return false
	if data.requires != &"" and rank_of(data.requires) <= 0:
		return false
	return true


func learn(id: StringName) -> bool:
	if not can_learn(id):
		return false
	points -= 1
	talents[id] = rank_of(id) + 1
	_recompute()
	points_changed.emit(points)
	talent_learned.emit(id, talents[id])
	return true


func grant_points(amount: int) -> void:
	if amount <= 0:
		return
	points += amount
	points_changed.emit(points)


## Tipos de flecha que el arquero SABE hacer (los talentos desbloquean recetas).
func unlocked_arrow_types() -> Array[StringName]:
	var result: Array[StringName] = [&"normal"]
	for id in talents:
		var data := Catalog.talent(id)
		if data == null:
			continue
		var rank: int = talents[id]
		for i in mini(rank, data.unlock_arrows.size()):
			result.append(data.unlock_arrows[i])
	return result


func to_dict() -> Dictionary:
	return {"points": points, "talents": talents.duplicate()}


func from_dict(data: Dictionary) -> void:
	points = int(data.get("points", 1))
	talents.clear()
	var saved: Dictionary = data.get("talents", {})
	for key in saved:
		talents[StringName(key)] = int(saved[key])
	_recompute()
	points_changed.emit(points)


## Nueva carrera. El día 1 es un amanecer: arranca con 1 punto.
func reset() -> void:
	points = 1
	talents.clear()
	_recompute()
	points_changed.emit(points)


func _recompute() -> void:
	var modifiers: Array[StatModifier] = []
	for id in talents:
		var data := Catalog.talent(id)
		if data == null:
			continue
		for rank in talents[id]:
			modifiers.append_array(data.modifiers)
	stats.recompute(modifiers)
	stats_changed.emit()
