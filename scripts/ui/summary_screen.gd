class_name SummaryScreen
extends CanvasLayer
## El pergamino del amanecer (GDD §4.1, §11.3): resumen del día al dormir.

var _panel: PanelContainer
var _content: VBoxContainer


func _ready() -> void:
	layer = 10
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS  # el árbol se pausa durante el sueño
	_build()
	GameManager.state_changed.connect(_on_state_changed)


func _on_state_changed(state: GameManager.State) -> void:
	var show := state == GameManager.State.SUMMARY
	if show:
		_fill()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = show


func _fill() -> void:
	for child in _content.get_children():
		child.queue_free()

	_add_line("— NOCHE %d SUPERADA —" % WorldState.day, 18, Color(0.92, 0.82, 0.55))
	_add_line("", 6, Color.WHITE)
	_add_line("Bajas: %d" % WorldState.kills_tonight, 13, Color(0.88, 0.85, 0.78))
	_add_line("Headshots: %d" % WorldState.headshots_tonight, 13, Color(0.88, 0.85, 0.78))
	_add_line("Oro ganado: %d" % WorldState.gold_earned_today, 13, Color(0.95, 0.83, 0.4))
	_add_line("Daño recibido por la Puerta: %d" % int(WorldState.door_damage_tonight), 13, Color(0.85, 0.6, 0.5))
	var door := get_tree().get_first_node_in_group("tower_door")
	if door != null:
		_add_line("Puerta: %d/%d" % [int(door.hp), int(TowerDoor.MAX_HP)], 13, Color(0.8, 0.72, 0.6))
	_add_line("", 6, Color.WHITE)

	var wake := Button.new()
	wake.text = "Despertar — Día %d" % (WorldState.day + 1)
	wake.add_theme_font_size_override("font_size", 15)
	wake.pressed.connect(func() -> void:
		GameManager.confirm_wake()
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		AudioManager.play_ui("ui_click", -6.0))
	_content.add_child(wake)


func _add_line(text: String, font_size: int, color: Color) -> void:
	var label := Label.new()
	var settings := LabelSettings.new()
	settings.font_size = font_size
	settings.font_color = color
	label.label_settings = settings
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.text = text
	_content.add_child(label)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_panel = PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.13, 0.11, 0.08, 0.97)
	style.border_color = Color(0.5, 0.4, 0.24)
	style.set_border_width_all(2)
	style.set_content_margin_all(16)
	_panel.add_theme_stylebox_override("panel", style)
	_panel.custom_minimum_size = Vector2(300, 0)
	_panel.position = Vector2(170, 80)
	add_child(_panel)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 4)
	_panel.add_child(_content)
