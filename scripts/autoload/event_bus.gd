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
@warning_ignore("unused_signal")
signal night_cleared

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
		print("[%s] spawn %s" % [WorldState.clock_text(), enemy.name]))
	enemy_killed.connect(func(_enemy: Node3D, headshot: bool) -> void:
		print("[%s] kill (headshot=%s)" % [WorldState.clock_text(), headshot]))
	wave_started.connect(func(index: int, total: int) -> void:
		print("[%s] EMPUJE %d/%d" % [WorldState.clock_text(), index, total]))
	door_damaged.connect(func(current: float, maximum: float) -> void:
		print("[%s] puerta %d/%d" % [WorldState.clock_text(), current, maximum]))
	door_destroyed.connect(func() -> void:
		print("[%s] PUERTA DESTRUIDA" % WorldState.clock_text()))
	night_cleared.connect(func() -> void:
		print("[%s] corredor limpio" % WorldState.clock_text()))
	# Posición del primer goblin cada 8 s: detecta atascos de navegación.
	var tracker := Timer.new()
	tracker.wait_time = 8.0
	tracker.autostart = true
	add_child(tracker)
	tracker.timeout.connect(func() -> void:
		var enemies := get_tree().get_nodes_in_group("enemies")
		if enemies.is_empty():
			return
		var e := enemies[0] as Node3D
		print("[%s] goblin0 pos=(%.1f, %.1f) vivos=%d" % [
			WorldState.clock_text(), e.global_position.x, e.global_position.z, enemies.size()]))
