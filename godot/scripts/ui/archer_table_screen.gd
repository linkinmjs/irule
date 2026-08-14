class_name ArcherTableScreen
extends CanvasLayer
## La Mesa del Arquero (M4b §5): pestañas TALLER (F4) y TALENTOS. Se abre con T.
## Patrón DebugMenu: mouse libre, SIN pausa — el mundo sigue corriendo
## (craftear y decidir talentos también consume tu intermedio).

const BRANCH_NAMES := {
	TalentData.Branch.OJO: "OJO",
	TalentData.Branch.MANOS: "MANOS",
	TalentData.Branch.OFICIO: "OFICIO",
}
const GOLD_COLOR := Color(0.95, 0.83, 0.4)
const MATERIAL_NAMES := {&"flor": "FLOR", &"hongo": "HONGO", &"pluma": "PLUMA"}

var _points_label: Label
var _gold_label: Label
var _description_label: Label
var _talent_buttons: Dictionary = {}  # id → Button
var _columns: Dictionary = {}

var _workshop_tab: Button
var _talents_tab: Button
var _workshop_box: Control
var _talents_box: Control
var _pouch_labels: Dictionary = {}    # material/normal → Label
var _craft_buttons: Dictionary = {}   # arrow_id → Button
var _recipe_labels: Dictionary = {}   # arrow_id → Label
var _quiver_label: Label


func _ready() -> void:
	layer = 25
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	Progression.points_changed.connect(func(_p: int) -> void: _refresh())
	Progression.talent_learned.connect(func(_id: StringName, _r: int) -> void: _refresh())
	WorldState.materials_changed.connect(func(_t: StringName, _c: int) -> void: _refresh())
	WorldState.ammo_changed.connect(func(_t: StringName, _c: int) -> void: _refresh())
	WorldState.gold_changed.connect(func(_g: int) -> void: _refresh())


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


func _show_tab(workshop: bool) -> void:
	_workshop_box.visible = workshop
	_talents_box.visible = not workshop
	_workshop_tab.modulate = GOLD_COLOR if workshop else Color.WHITE
	_talents_tab.modulate = Color.WHITE if workshop else GOLD_COLOR
	_refresh()


# ------------------------------------------------------------------ lógica

func _refresh() -> void:
	if not visible:
		return
	_points_label.text = "PUNTOS: %d" % Progression.points
	_gold_label.text = "ORO %d" % WorldState.gold
	_refresh_talents()
	_refresh_workshop()


func _refresh_talents() -> void:
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


func _refresh_workshop() -> void:
	for key in _pouch_labels:
		var label: Label = _pouch_labels[key]
		if key == &"normal":
			label.text = "NORMAL     x%d" % WorldState.ammo_count(&"normal")
		else:
			label.text = "%s%s x%d" % [MATERIAL_NAMES[key],
				" ".repeat(maxi(9 - MATERIAL_NAMES[key].length(), 1)),
				WorldState.material_count(key)]
	var unlocked := Progression.unlocked_arrow_types()
	for arrow_id in _craft_buttons:
		var button: Button = _craft_buttons[arrow_id]
		var label: Label = _recipe_labels[arrow_id]
		var known: bool = arrow_id in unlocked
		label.modulate = Color.WHITE if known else Color(0.55, 0.55, 0.55)
		if not known:
			button.disabled = true
			button.tooltip_text = "Aprendé el talento en OFICIO"
			continue
		button.disabled = not _can_craft(arrow_id)
		button.tooltip_text = ""
	var parts: Array[String] = []
	for arrow_id in Player.ARROW_SLOTS:
		var count := WorldState.ammo_count(arrow_id)
		if arrow_id == &"normal" or count > 0 or arrow_id in unlocked:
			var data := Catalog.arrow_type(arrow_id)
			parts.append("%s %d" % [data.display_name.to_upper().substr(0, 6), count])
	_quiver_label.text = "CARCAJ  " + " · ".join(parts) + "   (teclas 1-5)"


func _can_craft(arrow_id: StringName) -> bool:
	var data := Catalog.arrow_type(arrow_id)
	if data == null or WorldState.ammo_count(arrow_id) >= WorldState.SPECIAL_ARROW_CAP:
		return false
	for ingredient in data.recipe:
		var need := int(data.recipe[ingredient])
		match ingredient:
			&"oro":
				if WorldState.gold < need:
					return false
			&"normal":
				if WorldState.ammo_count(&"normal") < need:
					return false
			_:
				if WorldState.material_count(ingredient) < need:
					return false
	return true


func _on_craft_pressed(arrow_id: StringName) -> void:
	if WorldState.try_craft(arrow_id):
		AudioManager.play_ui("repair", -10.0)
		var data := Catalog.arrow_type(arrow_id)
		_description_label.text = "+1 %s (%d/%d en el carcaj)" % [
			data.display_name, WorldState.ammo_count(arrow_id), WorldState.SPECIAL_ARROW_CAP]
	else:
		AudioManager.play_ui("ui_click", -8.0)


func _on_talent_pressed(id: StringName) -> void:
	var data := Catalog.talent(id)
	_description_label.text = data.description
	if Progression.learn(id):
		AudioManager.play_ui("repair", -10.0)
	else:
		AudioManager.play_ui("ui_click", -8.0)


## Costo legible de la receta: "1 NORMAL + 2 FLOR + 5 ORO".
func _recipe_text(data: ArrowTypeData) -> String:
	var parts: Array[String] = []
	for ingredient in [&"normal", &"flor", &"hongo", &"pluma", &"oro"]:
		if data.recipe.has(ingredient):
			var pretty: String = "ORO" if ingredient == &"oro" else \
				("NORMAL" if ingredient == &"normal" else MATERIAL_NAMES[ingredient])
			parts.append("%d %s" % [int(data.recipe[ingredient]), pretty])
	return " + ".join(parts)


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

	# Header: título + tabs + oro + puntos.
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 10)
	content.add_child(header)
	header.add_child(_make_label("MESA DEL ARQUERO", 14, Color(0.92, 0.82, 0.55)))
	_workshop_tab = Button.new()
	_workshop_tab.text = "TALLER"
	_workshop_tab.add_theme_font_size_override("font_size", 10)
	_workshop_tab.pressed.connect(func() -> void: _show_tab(true))
	header.add_child(_workshop_tab)
	_talents_tab = Button.new()
	_talents_tab.text = "TALENTOS"
	_talents_tab.add_theme_font_size_override("font_size", 10)
	_talents_tab.pressed.connect(func() -> void: _show_tab(false))
	header.add_child(_talents_tab)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)
	_gold_label = _make_label("ORO 0", 12, GOLD_COLOR)
	header.add_child(_gold_label)
	_points_label = _make_label("PUNTOS: 0", 12, GOLD_COLOR)
	header.add_child(_points_label)

	_build_workshop(content)
	_build_talents(content)

	_description_label = _make_label("T o Esc cierran. Teclas 1-5 cambian la flecha en mano.", 10, Color(0.8, 0.75, 0.65))
	_description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description_label.custom_minimum_size = Vector2(0, 30)
	content.add_child(_description_label)

	_show_tab(true)  # el taller es la cara de la mesa (los talentos, su reverso)


func _build_workshop(content: VBoxContainer) -> void:
	_workshop_box = VBoxContainer.new()
	_workshop_box.add_theme_constant_override("separation", 6)
	_workshop_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_workshop_box)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_workshop_box.add_child(row)

	# Morral (materiales + normales).
	var pouch := VBoxContainer.new()
	pouch.add_theme_constant_override("separation", 4)
	pouch.custom_minimum_size = Vector2(150, 0)
	row.add_child(pouch)
	pouch.add_child(_make_label("MORRAL", 12, Color(0.85, 0.78, 0.62)))
	for key in [&"flor", &"hongo", &"pluma", &"normal"]:
		var label := _make_label("", 11, Color(0.9, 0.87, 0.78))
		pouch.add_child(label)
		_pouch_labels[key] = label
	var hint := _make_label("La flora brota en las islas\ncada ronda. [E] recoge.", 9, Color(0.65, 0.6, 0.52))
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pouch.add_child(hint)

	# Recetas.
	var recipes := VBoxContainer.new()
	recipes.add_theme_constant_override("separation", 5)
	recipes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(recipes)
	recipes.add_child(_make_label("RECETAS", 12, Color(0.85, 0.78, 0.62)))
	for arrow_id in [&"emplumada", &"incendiaria", &"congelante", &"explosiva"]:
		var data := Catalog.arrow_type(arrow_id)
		var recipe_row := HBoxContainer.new()
		recipe_row.add_theme_constant_override("separation", 8)
		recipes.add_child(recipe_row)
		var swatch := ColorRect.new()
		swatch.color = data.tint
		swatch.custom_minimum_size = Vector2(8, 8)
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		recipe_row.add_child(swatch)
		var label := _make_label("%s — %s" % [data.display_name.to_upper(), _recipe_text(data)],
			10, Color(0.9, 0.87, 0.78))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		recipe_row.add_child(label)
		_recipe_labels[arrow_id] = label
		var button := Button.new()
		button.text = "+1"
		button.add_theme_font_size_override("font_size", 10)
		button.pressed.connect(_on_craft_pressed.bind(arrow_id))
		recipe_row.add_child(button)
		_craft_buttons[arrow_id] = button

	_quiver_label = _make_label("CARCAJ", 10, Color(0.85, 0.78, 0.62))
	_workshop_box.add_child(_quiver_label)


func _build_talents(content: VBoxContainer) -> void:
	_talents_box = VBoxContainer.new()
	_talents_box.add_theme_constant_override("separation", 6)
	_talents_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(_talents_box)

	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 10)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_talents_box.add_child(columns)
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


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = color
	label.label_settings = settings
	label.text = text
	return label
