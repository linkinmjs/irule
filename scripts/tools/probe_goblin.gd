extends SceneTree
## Sonda v3: pose del goblin CON la animación corriendo (las anims FBX pueden
## traer la orientación en sus tracks — el rest pose engaña).
## Uso: godot --headless -s res://scripts/tools/probe_goblin.gd

func _initialize() -> void:
	var scene: PackedScene = load("res://assets/models/packs/goblins/GoblinCharacter.fbx")
	if scene == null:
		print("NO_LOAD")
		quit()
		return
	var root := scene.instantiate() as Node3D
	get_root().add_child(root)

	var skeleton: Skeleton3D = root.find_children("*", "Skeleton3D", true, false).front()
	var anim: AnimationPlayer = root.find_children("*", "AnimationPlayer", true, false).front()

	print("--- REST (sin anim) ---")
	_report(skeleton, root)

	if anim != null:
		anim.play("Goblin Rig|Goblin_Walk_Melee")
		anim.advance(0.25)
		print("--- CON ANIM (walk, t=0.25) ---")
		_report(skeleton, root)

	root.free()
	quit()


func _report(skeleton: Skeleton3D, root: Node3D) -> void:
	var rig := root.get_node_or_null("Goblin Rig") as Node3D
	if rig != null:
		print("rig basis=", rig.transform.basis)
	print("skel global basis=", skeleton.global_transform.basis)
	for bone_name in ["Hips", "Head", "Foot.L"]:
		var idx := skeleton.find_bone(bone_name)
		if idx >= 0:
			var world_pos: Vector3 = (skeleton.global_transform * skeleton.get_bone_global_pose(idx)).origin
			print("  %s world=(%.2f, %.2f, %.2f)" % [bone_name, world_pos.x, world_pos.y, world_pos.z])
