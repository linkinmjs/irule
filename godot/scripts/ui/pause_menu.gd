class_name PauseMenu
extends CanvasLayer
## Pausa con ESC. Único nodo que procesa siempre (el árbol se pausa).

func _ready() -> void:
	layer = 20
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	GameManager.state_changed.connect(func(state: GameManager.State) -> void:
		visible = state == GameManager.State.PAUSED)


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if GameManager.state in [GameManager.State.PLAYING, GameManager.State.PAUSED]:
		GameManager.toggle_pause()
		get_viewport().set_input_as_handled()


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.0, 0.0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.09, 0.08, 0.97)
	style.border_color = Color(0.42, 0.36, 0.25)
	style.set_border_width_all(2)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(280, 0)
	panel.position = Vector2(180, 90)
	add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)

	var title := Label.new()
	var title_settings := LabelSettings.new()
	title_settings.font_size = 18
	title_settings.font_color = Color(0.92, 0.85, 0.65)
	title.label_settings = title_settings
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "PAUSA"
	content.add_child(title)

	var hint := Label.new()
	var hint_settings := LabelSettings.new()
	hint_settings.font_size = 11
	hint_settings.font_color = Color(0.7, 0.66, 0.58)
	hint.label_settings = hint_settings
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.text = "WASD moverse · Click sostenido tensa el arco\nE interactuar · Ctrl agacharse · Espacio saltar"
	content.add_child(hint)

	var resume := Button.new()
	resume.text = "Continuar"
	resume.pressed.connect(func() -> void: GameManager.toggle_pause())
	content.add_child(resume)

	var new_game := Button.new()
	new_game.text = "Nueva partida"
	new_game.pressed.connect(func() -> void: GameManager.restart_game(true))
	content.add_child(new_game)

	var quit := Button.new()
	quit.text = "Salir"
	quit.pressed.connect(func() -> void: GameManager.quit_game())
	content.add_child(quit)
