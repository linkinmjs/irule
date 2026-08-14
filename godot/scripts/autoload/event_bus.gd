extends Node
## EventBus global (GDD §12.4): solo señales, sin estado.
## Regla: quien produce el hecho lo emite; quien reacciona se conecta acá.

# --- Combate ---
@warning_ignore("unused_signal")
signal enemy_spawned(enemy: Node3D)
@warning_ignore("unused_signal")
signal enemy_killed(enemy: Node3D, headshot: bool)
@warning_ignore("unused_signal")
signal arrow_hit(lethal: bool, headshot: bool)
@warning_ignore("unused_signal")
signal door_damaged(current: float, maximum: float)
@warning_ignore("unused_signal")
signal door_repaired(current: float, maximum: float)
@warning_ignore("unused_signal")
signal door_destroyed

# --- Oleadas ---
@warning_ignore("unused_signal")
signal wave_started(wave_index: int, wave_count: int)

# --- Jugador / HUD ---
# (la munición es estado del mundo: WorldState.ammo_changed — F2/M4b)
@warning_ignore("unused_signal")
signal interact_prompt_changed(text: String)
@warning_ignore("unused_signal")
signal announcement(text: String)


## Con `godot -- --debug-log` imprime el flujo de combate en consola.
func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--debug-log"):
		return
	enemy_spawned.connect(func(enemy: Node3D) -> void:
		print("[%s] spawn %s" % [WorldState.round_tag(), enemy.name]))
	enemy_killed.connect(func(_enemy: Node3D, headshot: bool) -> void:
		print("[%s] kill (headshot=%s)" % [WorldState.round_tag(), headshot]))
	wave_started.connect(func(index: int, total: int) -> void:
		print("[%s] EMPUJE %d/%d" % [WorldState.round_tag(), index, total]))
	door_damaged.connect(func(current: float, maximum: float) -> void:
		print("[%s] puerta %d/%d" % [WorldState.round_tag(), current, maximum]))
	door_destroyed.connect(func() -> void:
		print("[%s] PUERTA DESTRUIDA" % WorldState.round_tag()))
	WorldState.round_started.connect(func(n: int) -> void:
		print("[%s] RONDA %d — %s / %s / %d enemigos" % [WorldState.round_tag(), n,
			WorldState.current_round.get("ambience", &"?"),
			WorldState.current_round.get("weather", &"?"),
			WorldState.current_round.get("enemy_count", 0)]))
	WorldState.assault_started.connect(func(_n: int) -> void:
		print("[%s] ASALTO" % WorldState.round_tag()))
	WorldState.round_cleared.connect(func(n: int) -> void:
		print("[%s] RONDA %d SUPERADA" % [WorldState.round_tag(), n]))
	# Tracker de atascos cada 8 s: goblins que se movieron < 1 m entre muestras
	# se reportan como STUCK con su posición — localiza pilas y deadlocks RVO.
	var last_pos: Dictionary = {}
	var tracker := Timer.new()
	tracker.wait_time = 8.0
	tracker.autostart = true
	add_child(tracker)
	tracker.timeout.connect(func() -> void:
		var enemies := get_tree().get_nodes_in_group("enemies")
		if enemies.is_empty():
			last_pos.clear()
			return
		var stuck: Array[String] = []
		var seen: Dictionary = {}
		for e in enemies:
			var e3 := e as Node3D
			var id := e3.get_instance_id()
			seen[id] = true
			var pos := e3.global_position
			# state 1 == ATTACK: pegado a la Puerta se está quieto legítimamente.
			if last_pos.has(id) and pos.distance_to(last_pos[id]) < 1.0 \
					and int(e3.get("state")) != 1:
				stuck.append("(%.0f,%.0f)" % [pos.x, pos.z])
			last_pos[id] = pos
		for id in last_pos.keys():
			if not seen.has(id):
				last_pos.erase(id)
		var lead := enemies[0] as Node3D
		print("[%s] vivos=%d lead=(%.0f,%.0f) stuck=%d %s" % [
			WorldState.round_tag(), enemies.size(),
			lead.global_position.x, lead.global_position.z,
			stuck.size(), " ".join(stuck)]))
