class_name GameOverScreen
extends CanvasLayer
## Derrota (GDD §4.3): la Puerta cayó. Reintento desde el último amanecer guardado.

func _ready() -> void:
	layer = 15
	visible = false
	_build()
	GameManager.state_changed.connect(func(state: GameManager.State) -> void:
		visible = state == GameManager.State.GAME_OVER)


func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.06, 0.0, 0.0, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.06, 0.05, 0.97)
	style.border_color = Color(0.55, 0.2, 0.15)
	style.set_border_width_all(2)
	style.set_content_margin_all(18)
	panel.add_theme_stylebox_override("panel", style)
	panel.custom_minimum_size = Vector2(300, 0)
	panel.position = Vector2(170, 90)
	add_child(panel)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	panel.add_child(content)

	var title := Label.new()
	var title_settings := LabelSettings.new()
	title_settings.font_size = 20
	title_settings.font_color = Color(0.9, 0.3, 0.22)
	title.label_settings = title_settings
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.text = "LA PUERTA CAYÓ"
	content.add_child(title)

	var subtitle := Label.new()
	var sub_settings := LabelSettings.new()
	sub_settings.font_size = 13
	sub_settings.font_color = Color(0.8, 0.72, 0.62)
	subtitle.label_settings = sub_settings
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(subtitle)
	visibility_changed.connect(func() -> void:
		if visible:
			subtitle.text = "El puesto fue saqueado en el día %d" % WorldState.day)

	var retry := Button.new()
	retry.text = "Reintentar desde el amanecer"
	retry.pressed.connect(func() -> void: GameManager.restart_game(false))
	content.add_child(retry)

	var new_game := Button.new()
	new_game.text = "Nueva partida"
	new_game.pressed.connect(func() -> void: GameManager.restart_game(true))
	content.add_child(new_game)

	var quit := Button.new()
	quit.text = "Salir"
	quit.pressed.connect(func() -> void: GameManager.quit_game())
	content.add_child(quit)
