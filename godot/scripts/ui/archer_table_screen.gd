class_name ArcherTableScreen
extends CanvasLayer
## La Mesa del Arquero (M4b §5): pestañas TALLER (F4) y TALENTOS. Se abre con T.
## Patrón DebugMenu: mouse libre, SIN pausa — el reloj sigue corriendo
## (decidir talentos también consume tu día: presión horaria).

const BRANCH_NAMES := {
	TalentData.Branch.OJO: "OJO",
	TalentData.Branch.MANOS: "MANOS",
	TalentData.Branch.OFICIO: "OFICIO",
}
const GOLD_COLOR := Color(0.95, 0.83, 0.4)

var _points_label: Label
var _description_label: Label
var _talent_buttons: Dictionary = {}  # id → Button
var _columns: Dictionary = {}


func _ready() -> void:
	layer = 25
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Progression.points_changed.connect(func(_p: int) -> void: _refresh())
	Progression.talent_learned.connect(func(_id: StringName, _r: int) -> void: _refresh())


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("talents"):
		_toggle()
		get_viewport().set_input_as_handled()
	elif visible and event.is_action_pressed("pause"):
		_toggle()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	if not visible and GameManager.state != GameManager.State.PLAYING:
		return
	visible = not visible
	if visible:
		_refresh()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		AudioManager.play_ui("ui_click", -8.0)
	elif GameManager.state == GameManager.State.PLAYING:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ------------------------------------------------------------------ lógica

func _refresh() -> void:
	if not visible:
		return
	_points_label.text = "PUNTOS: %d" % Progression.points
	for id in _talent_buttons:
		var button: Button = _talent_buttons[id]
		var data := Catalog.talent(id)
		var rank := Progression.rank_of(id)
		button.text = "%s  %d/%d" % [data.display_name, rank, data.max_ranks]
		if rank >= data.max_ranks:
			button.disabled = true
			button.modulate = GOLD_COLOR
		elif Progression.can_learn(id):
			button.disabled = false
			button.modulate = Color.WHITE
		else:
			button.disabled = true
			button.modulate = Color(0.65, 0.65, 0.65)


func _on_talent_pressed(id: StringName) -> void:
	var data := Catalog.talent(id)
	_description_label.text = data.description
	if Progression.learn(id):
		AudioManager.play_ui("repair", -10.0)
	else:
		AudioManager.play_ui("ui_click", -8.0)


# ------------------------------------------------------------------ construcción

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.24, 0.2, 0.14, 0.97)  # pergamino oscuro
	style.border_color = Color(0.5, 0.42, 0.28)
	style.set_border_width_all(2)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	panel.position = Vector2(30, 16)
	panel.custom_minimum_size = Vector2(580, 326)
	add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	panel.add_child(content)

	# Header: título + tabs + puntos.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	content.add_child(header)
	var title := _make_label("MESA DEL ARQUERO", 14, Color(0.92, 0.82, 0.55))
	header.add_child(title)
	var workshop_tab := Button.new()
	workshop_tab.text = "TALLER"
	workshop_tab.disabled = true
	workshop_tab.tooltip_text = "La mesa de trabajo llega con el crafteo (F4)"
	workshop_tab.add_theme_font_size_override("font_size", 10)
	header.add_child(workshop_tab)
	var talents_tab := Button.new()
	talents_tab.text = "TALENTOS"
	talents_tab.disabled = true  # única pestaña activa por ahora
	talents_tab.modulate = GOLD_COLOR
	talents_tab.add_theme_font_size_override("font_size", 10)
	header.add_child(talents_tab)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_points_label = _make_label("PUNTOS: 0", 12, GOLD_COLOR)
	header.add_child(_points_label)

	# Tres columnas de ramas.
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 10)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(columns)
	for branch in BRANCH_NAMES:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 4)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		columns.add_child(column)
		column.add_child(_make_label(BRANCH_NAMES[branch], 12, Color(0.85, 0.78, 0.62)))
		_columns[branch] = column

	for id in Catalog.talents():
		var data: TalentData = Catalog.talents()[id]
		var button := Button.new()
		button.add_theme_font_size_override("font_size", 10)
		button.tooltip_text = data.description
		button.pressed.connect(_on_talent_pressed.bind(id))
		(_columns[data.branch] as VBoxContainer).add_child(button)
		_talent_buttons[id] = button

	_description_label = _make_label("Clic en un talento para aprenderlo. T o Esc cierran.", 10, Color(0.8, 0.75, 0.65))
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.custom_minimum_size = Vector2(0, 30)
	content.add_child(_description_label)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = color
	label.label_settings = settings
	label.text = text
	return label
