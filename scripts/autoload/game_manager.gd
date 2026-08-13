extends Node
## Flujo de juego (GDD §4): dormir → pergamino → nuevo día; game over; pausa; hitstop.

signal state_changed(state: State)

enum State { PLAYING, SUMMARY, GAME_OVER, PAUSED }

var state: State = State.PLAYING

var _hitstop_active := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.door_destroyed.connect(_on_door_destroyed)


func _exit_tree() -> void:
	AssetLib.clear()


func is_gameplay() -> bool:
	return state == State.PLAYING


## GDD §4.1: se puede dormir en la congelación (03:00) o de día (la noche ya terminó).
func can_sleep() -> bool:
	return WorldState.phase in [WorldState.Phase.FROZEN, WorldState.Phase.DAY]


func request_sleep() -> void:
	if state != State.PLAYING or not can_sleep():
		return
	state = State.SUMMARY
	get_tree().paused = true  # el mundo se detiene mientras dormís
	state_changed.emit(state)
	AudioManager.play_ui("ui_click", -6.0)


## Botón "Despertar" del pergamino: sella el día y guarda (GDD §4.1).
func confirm_wake() -> void:
	if state != State.SUMMARY:
		return
	WorldState.advance_day()
	_apply_dawn_rules()
	_save_now()
	state = State.PLAYING
	get_tree().paused = false
	state_changed.emit(state)


## Reglas de juego del amanecer, separadas del guardado (M4 las reemplaza por
## producción/economía — GDD §6: la munición dejará de reponerse gratis).
func _apply_dawn_rules() -> void:
	var player := get_tree().get_first_node_in_group("player")
	if player != null:
		player.refill_arrows()


func toggle_pause() -> void:
	if state == State.PLAYING:
		state = State.PAUSED
		get_tree().paused = true
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		state_changed.emit(state)
	elif state == State.PAUSED:
		state = State.PLAYING
		get_tree().paused = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		state_changed.emit(state)


## Micro-hitstop (GDD §11.1): solo kills importantes. Duración en segundos reales.
func do_hitstop(time_scale := 0.1, duration := 0.05) -> void:
	if _hitstop_active:
		return
	_hitstop_active = true
	Engine.time_scale = time_scale
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false


## Recarga la escena. main.gd re-aplica el save al construir (o resetea si no hay).
func restart_game(clear_save := false) -> void:
	Engine.time_scale = 1.0
	get_tree().paused = false
	if clear_save:
		SaveManager.clear_save()
	state = State.PLAYING
	state_changed.emit(state)
	get_tree().reload_current_scene()


func quit_game() -> void:
	get_tree().quit()


## Solo serializa (las reglas del amanecer viven en _apply_dawn_rules).
func _save_now() -> void:
	var data := {
		"day": WorldState.day,
		"gold": WorldState.gold,
		"xp": WorldState.xp,
		"level": WorldState.level,
	}
	var door := get_tree().get_first_node_in_group("tower_door")
	if door != null:
		data["door_hp"] = door.hp
	SaveManager.save_game(data)


func _on_door_destroyed() -> void:
	if state == State.GAME_OVER:
		return
	state = State.GAME_OVER
	state_changed.emit(state)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
