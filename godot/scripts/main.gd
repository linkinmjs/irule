extends Node3D
## Punto de entrada. El nivel: usa la escena horneada (editable en el editor)
## si existe; si no, lo genera LevelBuilder por código. Los markers
## PlayerStart/SpawnPoint de la escena definen posiciones (movelos a gusto).

const LEVEL_SCENE := "res://scenes/levels/outpost_01.tscn"


func _ready() -> void:
	var save := SaveManager.load_game()
	if save.is_empty():
		WorldState.reset()
		Progression.reset()
	else:
		WorldState.reset(int(save.get("round", 0)), int(save.get("gold", 60)))
		WorldState.xp = int(save.get("xp", 0))
		WorldState.level = int(save.get("level", 1))
		Progression.from_dict({
			"points": save.get("talent_points", 1),
			"talents": save.get("talents", {}),
		})
		var saved_ammo: Dictionary = save.get("ammo", {})
		if not saved_ammo.is_empty():
			WorldState.ammo.clear()
			for key in saved_ammo:
				WorldState.ammo[StringName(key)] = int(saved_ammo[key])
		var saved_stock: Dictionary = save.get("shop_stock", {})
		if not saved_stock.is_empty():
			WorldState.shop_stock.clear()
			for key in saved_stock:
				WorldState.shop_stock[StringName(key)] = int(saved_stock[key])
		var saved_materials: Dictionary = save.get("materials", {})
		for key in saved_materials:
			WorldState.materials[StringName(key)] = int(saved_materials[key])
		WorldState.xp = int(save.get("xp", 0))
		WorldState.level = int(save.get("level", 1))

	var level: Node3D
	if ResourceLoader.exists(LEVEL_SCENE):
		level = (load(LEVEL_SCENE) as PackedScene).instantiate()
	else:
		level = LevelBuilder.new()
	level.name = "Level"
	add_child(level)

	var door := get_tree().get_first_node_in_group("tower_door") as TowerDoor
	if door != null and save.has("door_hp"):
		door.load_hp(float(save["door_hp"]))

	var player_start := Vector3(9.0, 5.95, -13.0)
	var start_marker := level.get_node_or_null("PlayerStart")
	if start_marker is Node3D:
		player_start = (start_marker as Node3D).position
	elif level is LevelBuilder:
		player_start = (level as LevelBuilder).player_start

	var spawn_center := Vector3(-26.0, 0.0, -70.2)
	var spawn_marker := level.get_node_or_null("SpawnPoint")
	if spawn_marker is Node3D:
		spawn_center = (spawn_marker as Node3D).position
	elif level is LevelBuilder:
		spawn_center = (level as LevelBuilder).spawn_center

	var ambience := RoundAmbience.new()
	ambience.name = "RoundAmbience"
	add_child(ambience)

	var events := RoundEvents.new()
	events.name = "RoundEvents"
	add_child(events)

	var forage := ForageSystem.new()
	forage.name = "ForageSystem"
	add_child(forage)

	var player := Player.new()
	player.name = "Player"
	add_child(player)
	player.global_position = player_start
	player.respawn_point = player_start

	var spawner := WaveSpawner.new()
	spawner.name = "WaveSpawner"
	spawner.door = door
	spawner.spawn_center = spawn_center
	add_child(spawner)

	var hud := HUD.new()
	hud.name = "HUD"
	hud.setup(player)
	add_child(hud)
	add_child(SummaryScreen.new())
	add_child(GameOverScreen.new())
	add_child(PauseMenu.new())
	add_child(ArcherTableScreen.new())  # después de PauseMenu: consume Esc si está abierta
	add_child(DebugMenu.new())

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
