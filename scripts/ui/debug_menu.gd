class_name DebugMenu
extends CanvasLayer
## Menú de debug (F1): spawns, saltos de hora, oro, Puerta, reloj rápido.
## Con el menú abierto el mouse queda libre y el player no dispara
## (gatea por Input.mouse_mode).

var _status_label: Label
var _fast_clock := false
var _saved_day_speed := 0.0
var _saved_night_speed := 0.0


func _ready() -> void:
	layer = 30
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	# Autocuración: si el input map en memoria no tiene la acción (p. ej. el
	# editor pisó project.godot), la registramos acá mismo.
	if not InputMap.has_action("debug_menu"):
		InputMap.add_action("debug_menu")
		var key := InputEventKey.new()
		key.physical_keycode = KEY_F1
		InputMap.action_add_event("debug_menu", key)


func _input(event: InputEvent) -> void:
	var toggle_pressed := event.is_action_pressed("debug_menu")
	# Cinturón y tirantes: F1 directo por si la acción no matchea.
	if not toggle_pressed and event is InputEventKey:
		var key := event as InputEventKey
		toggle_pressed = key.pressed and not key.echo and key.physical_keycode == KEY_F1
	if toggle_pressed:
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	visible = not visible
	if visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif GameManager.state == GameManager.State.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(_delta: float) -> void:
	if not visible:
		return
	var enemies := get_tree().get_nodes_in_group("enemies").size()
	_status_label.text = "FPS %d · Goblins %d · %s (día %d) · Oro %d" % [
		Engine.get_frames_per_second(), enemies,
		WorldState.clock_text(), WorldState.day, WorldState.gold]


# ------------------------------------------------------------------ acciones

func _spawn_goblins(count: int, elite: bool) -> void:
	var door := get_tree().get_first_node_in_group("tower_door")
	if door == null:
		return
	var pos := Vector3(-26.0, 0.0, -70.2)
	var level := get_tree().current_scene.get_node_or_null("Level")
	if level != null:
		var marker := level.get_node_or_null("SpawnPoint")
		if marker is Node3D:
			pos = (marker as Node3D).global_position
	for i in count:
		var goblin := Goblin.new()
		goblin.configure(WorldState.day, elite)
		get_tree().current_scene.add_child(goblin)
		goblin.global_position = pos + Vector3(randf_range(-1.6, 1.6), 0.05, randf_range(-1.2, 1.2))
		goblin.set_target(door)
		EventBus.enemy_spawned.emit(goblin)


func _kill_all() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.has_method("take_explosion"):
			enemy.take_explosion(99999.0, enemy.global_position + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)))


func _jump_to_night() -> void:
	if WorldState.phase == WorldState.Phase.DAY or WorldState.phase == WorldState.Phase.DUSK:
		WorldState.hour = 20.95


func _jump_to_freeze() -> void:
	if WorldState.phase != WorldState.Phase.FROZEN:
		WorldState.hour = WorldState.FREEZE_HOUR - 0.01


func _toggle_fast_clock() -> void:
	_fast_clock = not _fast_clock
	if _fast_clock:
		_saved_day_speed = WorldState.day_seconds_per_hour
		_saved_night_speed = WorldState.night_seconds_per_hour
		WorldState.day_seconds_per_hour = 1.0
		WorldState.night_seconds_per_hour = 6.0
	else:
		WorldState.day_seconds_per_hour = _saved_day_speed
		WorldState.night_seconds_per_hour = _saved_night_speed


func _toggle_post() -> void:
	for post in get_tree().get_nodes_in_group("retro_post"):
		(post as Node3D).visible = not (post as Node3D).visible


func _door_action(repair: bool) -> void:
	var door := get_tree().get_first_node_in_group("tower_door")
	if door == null:
		return
	if repair:
		door.repair(9999.0)
	else:
		door.take_damage(150.0)


# ------------------------------------------------------------------ UI

func _build() -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.1, 0.94)
	style.border_color = Color(0.3, 0.55, 0.4)
	style.set_border_width_all(1)
	style.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", style)
	# Posición absoluta (viewport fijo 640×360). Nunca mezclar anchors_preset
	# con position antes de add_child: los offsets se calculan contra padre 0.
	panel.position = Vector2(420, 8)
	panel.custom_minimum_size = Vector2(212, 0)
	add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 3)
	panel.add_child(content)

	var title := Label.new()
	var title_settings := LabelSettings.new()
	title_settings.font_size = 12
	title_settings.font_color = Color(0.5, 0.9, 0.6)
	title.label_settings = title_settings
	title.text = "DEBUG (F1)"
	content.add_child(title)

	_status_label = Label.new()
	var status_settings := LabelSettings.new()
	status_settings.font_size = 9
	status_settings.font_color = Color(0.75, 0.75, 0.7)
	_status_label.label_settings = status_settings
	content.add_child(_status_label)

	# Grid de 2 columnas con textos cortos: 13 acciones entran en ~7 filas
	# (el panel se pasaba de los 360 px del viewport — playtest 2026-08-12).
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 3)
	grid.add_theme_constant_override("v_separation", 3)
	content.add_child(grid)

	_button(grid, "Spawn 1", func() -> void: _spawn_goblins(1, false))
	_button(grid, "Spawn 5", func() -> void: _spawn_goblins(5, false))
	_button(grid, "Spawn élite", func() -> void: _spawn_goblins(1, true))
	_button(grid, "Matar todos", _kill_all)
	_button(grid, "Noche 21:00", _jump_to_night)
	_button(grid, "Congelar 03:00", _jump_to_freeze)
	_button(grid, "Amanecer +1", func() -> void:
		WorldState.advance_day())
	_button(grid, "Reloj rápido", _toggle_fast_clock)
	_button(grid, "+500 oro", func() -> void: WorldState.add_gold(500))
	_button(grid, "Flechas full", func() -> void:
		var p := get_tree().get_first_node_in_group("player")
		if p != null:
			p.refill_arrows())
	_button(grid, "Reparar Puerta", func() -> void: _door_action(true))
	_button(grid, "Dañar Puerta", func() -> void: _door_action(false))
	_button(grid, "Post on/off", _toggle_post)


func _button(parent: Node, text: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text
	button.add_theme_font_size_override("font_size", 9)
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)
