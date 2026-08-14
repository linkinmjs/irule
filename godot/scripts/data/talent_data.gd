class_name TalentData
extends Resource
## Definición de un talento del arquero (M4b §1). Cadenas lineales por rama:
## `requires` es el talento previo. `modifiers` se aplican POR RANGO aprendido.
## `unlock_arrows[i]` se desbloquea al alcanzar el rango i+1.

enum Branch { OJO, MANOS, OFICIO }

@export var id: StringName
@export var display_name := ""
@export var description := ""
@export var branch: Branch = Branch.OJO
@export var requires: StringName = &""
@export var max_ranks := 1
@export var modifiers: Array[StatModifier] = []
@export var unlock_arrows: Array[StringName] = []
