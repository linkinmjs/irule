class_name RoundEvents
extends Node
## Eventos de rondas especiales (D17): cada 5 rondas pasa algo distinto.
## v1: el mago Calcu visita la isla durante la ronda. Nuevos eventos se
## suman acá (mercader, tormenta, ronda de élites…).

## Aparece cerca de la torre, sobre la isla del player (se asienta por raycast).
const WIZARD_SPOT := Vector3(11.0, 10.0, -22.0)

var _wizard: WizardVisitor = null


func _ready() -> void:
	WorldState.round_started.connect(_on_round_started)
	WorldState.round_cleared.connect(_on_round_cleared)


func _on_round_started(round_number: int) -> void:
	if not bool(WorldState.current_round.get("special", false)):
		return
	if is_instance_valid(_wizard):
		return
	_wizard = WizardVisitor.new()
	_wizard.visit_round = round_number
	get_tree().current_scene.add_child(_wizard)
	_wizard.global_position = WIZARD_SPOT
	get_tree().create_timer(6.0, false).timeout.connect(func() -> void:
		if is_instance_valid(_wizard):
			EventBus.announcement.emit("Un visitante llegó a la isla…"))


## Si nadie le habló, el mago no espera para siempre: se va al superar la ronda.
func _on_round_cleared(_round_number: int) -> void:
	if is_instance_valid(_wizard):
		get_tree().create_timer(20.0, false).timeout.connect(func() -> void:
			if is_instance_valid(_wizard):
				_wizard._leave())
