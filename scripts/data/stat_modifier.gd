class_name StatModifier
extends Resource
## Un ajuste atómico de una stat (M4b §1, patrón ability-system): al recomputar,
## primero se SUMAN todos los `add`, después se MULTIPLICAN todos los `mult` —
## orden determinista, sin importar en qué orden se aprendieron los talentos.

@export var stat: StringName
@export var add := 0.0
@export var mult := 1.0


static func make(stat_name: StringName, add_value := 0.0, mult_value := 1.0) -> StatModifier:
	var modifier := StatModifier.new()
	modifier.stat = stat_name
	modifier.add = add_value
	modifier.mult = mult_value
	return modifier
