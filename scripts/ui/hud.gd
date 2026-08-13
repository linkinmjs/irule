class_name HUD
extends CanvasLayer
## HUD mínimo (GDD §10.2): vida, flechas, oro, reloj, vida de la Puerta. Nada más.
## Crosshair dinámico: se abre con la velocidad — la lectura del spread CS (§5.1).

var _player: Player

var _day_label: Label
var _clock_label: Label
var _phase_label: Label
var _hp_label: Label
var _arrows_label: Label
var _gold_label: Label
var _prompt_label: Label
var _announce_label: Label
var _door_bar: ProgressBar
var _crosshair: CrosshairControl
var _announce_tween: Tween


func setup(player: Player) -> void:
	_player = player


func _ready() -> void:
	layer = 1
	_build()

	EventBus.arrows_changed.connect(_on_arrows_changed)
	WorldState.gold_changed.connect(_on_gold_changed)
	EventBus.door_damaged.connect(_on_door_changed)
	EventBus.door_repaired.connect(_on_door_changed)
	EventBus.interact_prompt_changed.connect(_on_prompt)
	EventBus.announcement.connect(_announce)
	EventBus.arrow_hit.connect(_on_arrow_hit)
	EventBus.wave_started.connect(_on_wave_started)
	EventBus.night_cleared.connect(func() -> void: _announce("El corredor quedó en silencio…"))
	WorldState.day_started.connect(func(day: int) -> void: _announce("DÍA %d" % day))
	WorldState.night_started.connect(func(_day: int) -> void: _announce("¡LA HORDA AVANZA!"))
	WorldState.time_frozen.connect(func() -> void: _announce("03:00 — EL TIEMPO SE CONGELÓ. La cama espera."))
	GameManager.state_changed.connect(func(state: GameManager.State) -> void:
		visible = state == GameManager.State.PLAYING)

	_on_gold_changed(WorldState.gold)
	var door := get_tree().get_first_node_in_group("tower_door")
	if door != null:
		_on_door_changed(door.hp, TowerDoor.MAX_HP)


func _process(_delta: float) -> void:
	_clock_label.text = WorldState.clock_text()
	_day_label.text = "DÍA %d" % WorldState.day
	match WorldState.phase:
		WorldState.Phase.DAY:
			_phase_label.text = "Preparación"
		WorldState.Phase.DUSK:
			_phase_label.text = "Atardece…"
		WorldState.Phase.NIGHT:
			_phase_label.text = "¡Asedio!"
		WorldState.Phase.FROZEN:
			_phase_label.text = "El tiempo se congeló"
	if _player != null:
		_crosshair.spread = _player.get_crosshair_spread()
		_crosshair.draw_charge = _player.draw_charge if _player.is_drawing else 0.0
		_crosshair.target_distance = _player.aimed_enemy_distance


# ------------------------------------------------------------------ señales

func _on_arrows_changed(arrows: int, max_arrows: int) -> void:
	_arrows_label.text = "FLECHAS %d/%d" % [arrows, max_arrows]


func _on_gold_changed(gold: int) -> void:
	_gold_label.text = "ORO %d" % gold


func _on_door_changed(current: float, maximum: float) -> void:
	_door_bar.max_value = maximum
	_door_bar.value = current


func _on_prompt(text: String) -> void:
	_prompt_label.text = text


func _on_wave_started(index: int, total: int) -> void:
	_announce("EMPUJE %d/%d" % [index, total])


func _on_arrow_hit(lethal: bool, headshot: bool) -> void:
	_crosshair.hit_feedback(lethal, headshot)
	AudioManager.play_ui("hitmarker", -16.0)


func _announce(text: String) -> void:
	_announce_label.text = text
	if _announce_tween != null and _announce_tween.is_running():
		_announce_tween.kill()
	_announce_label.modulate.a = 1.0
	_announce_tween = create_tween()
	_announce_tween.tween_interval(2.2)
	_announce_tween.tween_property(_announce_label, "modulate:a", 0.0, 0.6)


# ------------------------------------------------------------------ construcción

func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_crosshair = CrosshairControl.new()
	_crosshair.set_anchors_preset(Control.PRESET_CENTER)
	_crosshair.set_ballistics(Player.ARROW_SPEED_MAX, Arrow.GRAVITY)
	root.add_child(_crosshair)

	_day_label = _label(13, Color(0.85, 0.8, 0.7))
	_day_label.position = Vector2(8, 5)
	root.add_child(_day_label)

	_clock_label = _label(22, Color(0.95, 0.92, 0.85))
	_clock_label.position = Vector2(8, 20)
	root.add_child(_clock_label)

	_phase_label = _label(11, Color(0.7, 0.66, 0.6))
	_phase_label.position = Vector2(8, 48)
	root.add_child(_phase_label)

	# Posiciones absolutas: el viewport es fijo 640×360 (stretch viewport).
	# No usar anchors_preset + position antes de add_child (offsets contra padre 0).
	_hp_label = _label(14, Color(0.85, 0.55, 0.5))
	_hp_label.text = "VIDA 100"
	_hp_label.position = Vector2(8, 334)
	root.add_child(_hp_label)

	_arrows_label = _label(14, Color(0.9, 0.87, 0.78))
	_arrows_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_arrows_label.position = Vector2(478, 334)
	_arrows_label.size = Vector2(154, 18)
	_arrows_label.text = "FLECHAS 30/30"
	root.add_child(_arrows_label)

	_gold_label = _label(14, Color(0.95, 0.83, 0.4))
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_gold_label.position = Vector2(478, 312)
	_gold_label.size = Vector2(154, 18)
	root.add_child(_gold_label)

	var door_title := _label(10, Color(0.75, 0.7, 0.62))
	door_title.text = "PUERTA"
	door_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	door_title.position = Vector2(285, 328)
	door_title.size = Vector2(70, 13)
	root.add_child(door_title)

	_door_bar = ProgressBar.new()
	_door_bar.show_percentage = false
	_door_bar.position = Vector2(230, 344)
	_door_bar.size = Vector2(180, 8)
	_door_bar.max_value = TowerDoor.MAX_HP
	_door_bar.value = TowerDoor.MAX_HP
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.08, 0.07, 0.06, 0.85)
	bg.border_color = Color(0.4, 0.34, 0.24)
	bg.set_border_width_all(1)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.62, 0.44, 0.22)
	_door_bar.add_theme_stylebox_override("background", bg)
	_door_bar.add_theme_stylebox_override("fill", fill)
	root.add_child(_door_bar)

	_prompt_label = _label(13, Color(0.95, 0.93, 0.85))
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.position = Vector2(120, 228)
	_prompt_label.size = Vector2(400, 20)
	root.add_child(_prompt_label)

	_announce_label = _label(18, Color(0.95, 0.85, 0.6))
	_announce_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_announce_label.position = Vector2(70, 62)
	_announce_label.size = Vector2(500, 28)
	_announce_label.modulate.a = 0.0
	root.add_child(_announce_label)


func _label(font_size: int, color: Color) -> Label:
	var label := Label.new()
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = color
	settings.outline_size = 3
	settings.outline_color = Color(0.02, 0.02, 0.03, 0.9)
	label.label_settings = settings
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


# ------------------------------------------------------------------ crosshair

class CrosshairControl extends Control:
	## Escalera de pips (D14, docs/design/guia-de-tiro.md): holdovers exactos
	## para 15/30/45 m a full draw bajo el centro; el telémetro engrosa el pip
	## del goblin apuntado. Aparece recién cerca del full draw (alpha cuantizado
	## PS1). Información, no solución: la puntería sigue siendo tuya.
	const PIP_DISTANCES := [15.0, 30.0, 45.0]
	const VIEWPORT_HALF_H := 180.0
	const FOV_HALF_DEG := 46.0

	var spread := 6.0
	var draw_charge := 0.0
	var target_distance := -1.0

	var _pip_offsets: Array[float] = []
	var _hit_time := 0.0
	var _hit_lethal := false
	var _hit_headshot := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Recalculable por tipo de flecha (M4b): la emplumada comprime la escalera,
	## la explosiva la estira.
	func set_ballistics(speed: float, gravity: float) -> void:
		_pip_offsets.clear()
		var px_per_tan := VIEWPORT_HALF_H / tan(deg_to_rad(FOV_HALF_DEG))
		for d in PIP_DISTANCES:
			var drop_angle := atan(gravity * d / (2.0 * speed * speed))
			_pip_offsets.append(px_per_tan * tan(drop_angle))

	func _process(delta: float) -> void:
		_hit_time = maxf(_hit_time - delta, 0.0)
		queue_redraw()

	func hit_feedback(lethal: bool, headshot: bool) -> void:
		_hit_time = 0.28 if lethal else 0.15
		_hit_lethal = lethal
		_hit_headshot = headshot

	func _draw() -> void:
		var color := Color(0.95, 0.95, 0.9, 0.85)
		var arm := 5.0
		var thickness := 1.0
		draw_rect(Rect2(spread, -thickness * 0.5, arm, thickness), color)
		draw_rect(Rect2(-spread - arm, -thickness * 0.5, arm, thickness), color)
		draw_rect(Rect2(-thickness * 0.5, spread, thickness, arm), color)
		draw_rect(Rect2(-thickness * 0.5, -spread - arm, thickness, arm), color)
		draw_rect(Rect2(-0.5, -0.5, 1.0, 1.0), color)
		_draw_pip_ladder()
		if _hit_time > 0.0:
			var hit_color := Color(1.0, 0.3, 0.25) if _hit_headshot else Color(1.0, 1.0, 1.0, 0.9)
			var o := 3.0
			var l := 7.0 if _hit_lethal else 4.5
			draw_line(Vector2(o, o), Vector2(o + l, o + l), hit_color, 1.0)
			draw_line(Vector2(-o, o), Vector2(-o - l, o + l), hit_color, 1.0)
			draw_line(Vector2(o, -o), Vector2(o + l, -o - l), hit_color, 1.0)
			draw_line(Vector2(-o, -o), Vector2(-o - l, -o - l), hit_color, 1.0)

	func _draw_pip_ladder() -> void:
		if _pip_offsets.is_empty() or draw_charge < 0.55:
			return
		# Fade cuantizado en 3 pasos: nada de alphas suaves modernos.
		var alpha := floorf(clampf((draw_charge - 0.55) / 0.45, 0.0, 1.0) * 3.0) / 3.0
		if alpha <= 0.0:
			return
		var active := _active_pip()
		for i in _pip_offsets.size():
			var y: float = _pip_offsets[i]
			var is_active := i == active
			var half_w := 4.5 if is_active else 2.5
			var th := 2.0 if is_active else 1.0
			var col := Color(0.98, 0.85, 0.5, alpha) if is_active \
				else Color(0.9, 0.9, 0.85, alpha * 0.65)
			draw_rect(Rect2(-half_w, y - th * 0.5, half_w * 2.0, th), col)

	## Pip del goblin apuntado, cuantizado a bandas de ~15 m.
	func _active_pip() -> int:
		if target_distance < 7.5:
			return -1
		if target_distance < 22.5:
			return 0
		if target_distance < 37.5:
			return 1
		if target_distance < 55.0:
			return 2
		return -1
