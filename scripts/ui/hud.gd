class_name HUD
extends CanvasLayer
## HUD mínimo (GDD §10.2): vida, flechas, oro, ronda, vida de la Puerta. Nada más.
## Crosshair dinámico: se abre con la velocidad — la lectura del spread CS (§5.1).

var _player: Player

var _round_label: Label
var _phase_label: Label
var _hp_label: Label
var _arrows_label: Label
var _gold_label: Label
var _prompt_label: Label
var _announce_label: Label
var _door_bar: ProgressBar
var _crosshair: CrosshairControl
var _announce_tween: Tween
var _level_label: Label
var _xp_bar: ProgressBar
var _xp_float: Label
var _xp_float_tween: Tween
var _talent_hint: Label


func setup(player: Player) -> void:
	_player = player


func _ready() -> void:
	layer = 1
	_build()

	WorldState.ammo_changed.connect(_on_ammo_changed)
	WorldState.gold_changed.connect(_on_gold_changed)
	Progression.stats_changed.connect(_on_stats_changed)
	Progression.points_changed.connect(_on_points_changed)
	EventBus.door_damaged.connect(_on_door_changed)
	EventBus.door_repaired.connect(_on_door_changed)
	EventBus.interact_prompt_changed.connect(_on_prompt)
	EventBus.announcement.connect(_announce)
	EventBus.arrow_hit.connect(_on_arrow_hit)
	EventBus.wave_started.connect(_on_wave_started)
	WorldState.round_started.connect(func(n: int) -> void: _announce("RONDA %d" % n))
	WorldState.assault_started.connect(func(_n: int) -> void: _announce("¡LA HORDA AVANZA!"))
	WorldState.round_cleared.connect(func(_n: int) -> void:
		_announce("Ronda superada. El corredor quedó en silencio…"))
	GameManager.state_changed.connect(func(state: GameManager.State) -> void:
		visible = state == GameManager.State.PLAYING)

	WorldState.xp_gained.connect(_on_xp_gained)
	WorldState.xp_changed.connect(_on_xp_changed)
	WorldState.level_up.connect(func(new_level: int) -> void:
		_announce("¡NIVEL %d!" % new_level)
		AudioManager.play_ui("kill_bell", -8.0))

	_on_gold_changed(WorldState.gold)
	_on_xp_changed(WorldState.xp, WorldState.xp_for_next(), WorldState.level)
	_on_ammo_changed(&"normal", WorldState.ammo_count(&"normal"))
	_on_points_changed(Progression.points)
	var door := get_tree().get_first_node_in_group("tower_door")
	if door != null:
		_on_door_changed(door.hp, TowerDoor.MAX_HP)


func _process(_delta: float) -> void:
	if WorldState.round_number == 0:
		_round_label.text = "PUESTO IRULÉ"
		_phase_label.text = "La cama inicia la Ronda 1"
	else:
		_round_label.text = "RONDA %d" % WorldState.round_number
		match WorldState.round_phase:
			WorldState.RoundPhase.PREP:
				_phase_label.text = "Se acercan… %d" % ceili(WorldState.prep_remaining)
			WorldState.RoundPhase.ASSAULT:
				_phase_label.text = "¡Asedio!"
			WorldState.RoundPhase.CLEARED:
				_phase_label.text = "Intermedio — descansá para seguir"
	if _player != null:
		_crosshair.spread = _player.get_crosshair_spread()
		_crosshair.draw_charge = _player.draw_charge if _player.is_drawing else 0.0
		_crosshair.target_distance = _player.aimed_enemy_distance


# ------------------------------------------------------------------ señales

func _on_ammo_changed(type: StringName, count: int) -> void:
	if type != &"normal":
		return  # los tipos especiales entran al HUD en F4
	_arrows_label.text = "FLECHAS %d/%d" % [count, Progression.stats.quiver_max]


## Los talentos cambian balística y carcaj: la guía y el HUD se recalculan.
func _on_stats_changed() -> void:
	_crosshair.set_ballistics(Progression.stats.arrow_speed_max, Progression.stats.gravity)
	_on_ammo_changed(&"normal", WorldState.ammo_count(&"normal"))


func _on_points_changed(points: int) -> void:
	_talent_hint.text = "[T] Talentos (+%d)" % points if points > 0 else ""


func _on_gold_changed(gold: int) -> void:
	_gold_label.text = "ORO %d" % gold


func _on_door_changed(current: float, maximum: float) -> void:
	_door_bar.max_value = maximum
	_door_bar.value = current


func _on_prompt(text: String) -> void:
	_prompt_label.text = text


func _on_xp_changed(current_xp: int, next_level_xp: int, current_level: int) -> void:
	_level_label.text = "NIV %d" % current_level
	_xp_bar.max_value = next_level_xp
	_xp_bar.value = current_xp


## Floater "+N" al lado del crosshair: la recompensa se ve donde mirás (D15).
func _on_xp_gained(amount: int) -> void:
	_xp_float.text = "+%d" % amount
	if _xp_float_tween != null and _xp_float_tween.is_running():
		_xp_float_tween.kill()
	_xp_float.position = Vector2(338, 168)
	_xp_float.modulate.a = 1.0
	_xp_float_tween = create_tween()
	_xp_float_tween.tween_property(_xp_float, "position:y", 152.0, 0.55)
	_xp_float_tween.parallel().tween_property(_xp_float, "modulate:a", 0.0, 0.55)


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
	_crosshair.set_ballistics(Progression.stats.arrow_speed_max, Progression.stats.gravity)
	root.add_child(_crosshair)

	_round_label = _label(18, Color(0.95, 0.92, 0.85))
	_round_label.position = Vector2(8, 8)
	root.add_child(_round_label)

	_phase_label = _label(11, Color(0.7, 0.66, 0.6))
	_phase_label.position = Vector2(8, 32)
	root.add_child(_phase_label)

	_talent_hint = _label(11, Color(0.95, 0.85, 0.5))
	_talent_hint.position = Vector2(8, 50)
	root.add_child(_talent_hint)

	# Posiciones absolutas: el viewport es fijo 640×360 (stretch viewport).
	# No usar anchors_preset + position antes de add_child (offsets contra padre 0).
	_hp_label = _label(14, Color(0.85, 0.55, 0.5))
	_hp_label.text = "VIDA 100"
	_hp_label.position = Vector2(8, 334)
	root.add_child(_hp_label)

	_level_label = _label(11, Color(0.95, 0.85, 0.5))
	_level_label.text = "NIV 1"
	_level_label.position = Vector2(8, 314)
	root.add_child(_level_label)

	_xp_bar = ProgressBar.new()
	_xp_bar.show_percentage = false
	_xp_bar.position = Vector2(52, 320)
	_xp_bar.size = Vector2(70, 6)
	var xp_bg := StyleBoxFlat.new()
	xp_bg.bg_color = Color(0.08, 0.07, 0.06, 0.85)
	xp_bg.border_color = Color(0.4, 0.34, 0.24)
	xp_bg.set_border_width_all(1)
	var xp_fill := StyleBoxFlat.new()
	xp_fill.bg_color = Color(0.85, 0.7, 0.3)
	_xp_bar.add_theme_stylebox_override("background", xp_bg)
	_xp_bar.add_theme_stylebox_override("fill", xp_fill)
	root.add_child(_xp_bar)

	_xp_float = _label(11, Color(0.95, 0.85, 0.5))
	_xp_float.position = Vector2(338, 168)
	_xp_float.modulate.a = 0.0
	root.add_child(_xp_float)

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
