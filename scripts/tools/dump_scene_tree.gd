extends SceneTree
## Herramienta de desarrollo: inspecciona escenas importadas (GLB/FBX):
## nodos, AABB globales, esqueletos y animaciones.
## Uso: godot --headless -s res://scripts/tools/dump_scene_tree.gd

const PATHS := [
	"res://assets/models/packs/goblins/GoblinCharacter.fbx",
]


func _initialize() -> void:
	for path in PATHS:
		var scene: PackedScene = load(path)
		if scene == null:
			print("NO_LOAD ", path)
			continue
		var scene_root := scene.instantiate()
		get_root().add_child(scene_root)
		print("=== ", path, " ===")
		_dump(scene_root, 0)
		scene_root.free()
	quit()


func _dump(node: Node, depth: int) -> void:
	var info := "%s%s [%s]" % ["  ".repeat(depth), node.name, node.get_class()]
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		var aabb: AABB = mi.global_transform * mi.get_aabb()
		info += " world_size=(%.2f, %.2f, %.2f)" % [aabb.size.x, aabb.size.y, aabb.size.z]
	elif node is Skeleton3D:
		info += " bones=%d [%s]" % [(node as Skeleton3D).get_bone_count(),
			", ".join(_bone_names(node as Skeleton3D, 12))]
	elif node is AnimationPlayer:
		info += " anims=%s" % str((node as AnimationPlayer).get_animation_list())
	print(info)
	if depth < 4:
		for child in node.get_children():
			_dump(child, depth + 1)


func _bone_names(skeleton: Skeleton3D, limit: int) -> PackedStringArray:
	var names := PackedStringArray()
	for i in mini(skeleton.get_bone_count(), limit):
		names.append(skeleton.get_bone_name(i))
	return names
