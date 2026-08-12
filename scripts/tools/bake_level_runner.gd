extends Node
## Hornea el nivel generado (LevelBuilder) a una escena EDITABLE:
## scenes/levels/outpost_01.tscn — main.gd la prefiere si existe.
##
## Correr (necesita los autoloads, por eso es una escena y no un -s):
##   godot --path . --headless res://scenes/tools/bake_runner.tscn
##
## Qué guarda: terreno, muros, navmesh, markers (PlayerStart/SpawnPoint) y los
## props como nodos con script y posición (sus visuales se reconstruyen solos en
## _ready). Si ya existe el .tscn deja backup en outpost_01_backup.tscn antes de
## pisarlo — las ediciones manuales se pierden al re-hornear.

const OUT_PATH := "res://scenes/levels/outpost_01.tscn"
const BACKUP_PATH := "res://scenes/levels/outpost_01_backup.tscn"


func _ready() -> void:
	var builder := LevelBuilder.new()
	add_child(builder)  # _ready construye el nivel completo

	var baked := Node3D.new()
	baked.name = "Outpost01"
	add_child(baked)
	for child in builder.get_children().duplicate():
		builder.remove_child(child)
		baked.add_child(child)
	_set_owner_recursive(baked, baked)

	var packed := PackedScene.new()
	var err := packed.pack(baked)
	if err == OK:
		DirAccess.make_dir_recursive_absolute("res://scenes/levels")
		if FileAccess.file_exists(OUT_PATH):
			DirAccess.copy_absolute(
				ProjectSettings.globalize_path(OUT_PATH),
				ProjectSettings.globalize_path(BACKUP_PATH))
			print("BACKUP=", BACKUP_PATH)
		err = ResourceSaver.save(packed, OUT_PATH)
	print("BAKE_RESULT=", error_string(err), " -> ", OUT_PATH)
	get_tree().quit()


## Los nodos CON script no guardan sus hijos: los reconstruyen en _ready.
## Terrain3D tampoco: sus hijos son internos y carga todo desde data_directory.
func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		child.owner = scene_root
		if child.get_script() == null and not child is Terrain3D:
			_set_owner_recursive(child, scene_root)
