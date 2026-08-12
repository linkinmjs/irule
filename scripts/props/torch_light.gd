class_name TorchLight
extends Node3D
## Antorcha con flicker suave: elige un brillo objetivo cada ~0.12 s y lo
## interpola (nada de senos por frame — el estroboscópico era parte del
## "ruido de luz" del playtest). Usa el asset Torch_1 si está disponible.

const BASE_ENERGY := 1.4

## Pieza del pack a usar: "Torch_1" (pared) o "Brazier_1" (piso).
@export var piece_name := "Torch_1"

var _light: OmniLight3D
var _flame: MeshInstance3D
var _target_energy := BASE_ENERGY
var _retarget_in := 0.0


func _ready() -> void:
	var asset := AssetLib.piece(piece_name)
	var flame_height := 0.45
	if asset != null:
		add_child(asset)
		if piece_name == "Torch_1":
			asset.rotation.x = 0.3  # inclinada contra la pared
		flame_height = float(asset.get_meta("height", 1.2)) + 0.05
	else:
		var stick := MeshInstance3D.new()
		var stick_mesh := BoxMesh.new()
		stick_mesh.size = Vector3(0.06, 0.45, 0.06)
		stick.mesh = stick_mesh
		stick.position = Vector3(0.0, -0.1, 0.0)
		stick.rotation.x = 0.35
		stick.material_override = PSXMaterials.wood_dark()
		add_child(stick)

	_flame = MeshInstance3D.new()
	var flame_mesh := BoxMesh.new()
	flame_mesh.size = Vector3(0.14, 0.2, 0.14)
	_flame.mesh = flame_mesh
	_flame.position = Vector3(0.0, flame_height, 0.08)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.7, 0.25)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.55, 0.15)
	mat.emission_energy_multiplier = 1.4
	_flame.material_override = mat
	add_child(_flame)

	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.62, 0.3)
	_light.omni_range = 7.0
	_light.light_energy = BASE_ENERGY
	_light.position = Vector3(0.0, flame_height + 0.1, 0.1)
	add_child(_light)


func _process(delta: float) -> void:
	_retarget_in -= delta
	if _retarget_in <= 0.0:
		_retarget_in = randf_range(0.09, 0.16)
		_target_energy = BASE_ENERGY + randf_range(-0.18, 0.22)
	_light.light_energy = lerpf(_light.light_energy, _target_energy, minf(delta * 6.0, 1.0))
	var flame_scale := 1.0 + (_light.light_energy - BASE_ENERGY) * 0.3
	_flame.scale = Vector3.ONE * flame_scale
