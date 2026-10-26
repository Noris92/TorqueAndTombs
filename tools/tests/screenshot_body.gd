extends Node

var tree: SceneTree
var out_dir: String = "user://screenshots/"


func _ready() -> void:
	tree = get_tree()
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		out_dir = args[0].path_join("")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func frames(count: int) -> void:
	for _i in count:
		await tree.process_frame


func shot(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png(out_dir.path_join(file_name + ".png"))
	print("shot ", file_name)


func player() -> PlayerVehicle:
	return tree.get_first_node_in_group("player") as PlayerVehicle


func _run() -> void:
	PlayerData.reset_save()
	var args := OS.get_cmdline_user_args()
	if args.size() > 1 and args[1] == "new":
		await _new_feature_shots()
		PlayerData.reset_save()
		tree.quit()
		return
	if args.size() > 1 and args[1] == "rooms":
		await _room_shots()
		PlayerData.reset_save()
		tree.quit()
		return
	await _gallery()
	tree.change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	await frames(40)
	await shot("01_main_menu")

	GameManager.go_to_garage()
	await frames(60)
	await shot("03_garage")
	var shop := tree.current_scene.get("shop_ui") as ShopUI
	PlayerData.add_scrap(300)
	shop.open()
	await frames(10)
	await shot("04_shop")
	shop.close()

	GameManager.start_run()
	await frames(90)
	await shot("05_dungeon_start")
	var generator := tree.current_scene.get_node("DungeonGenerator") as DungeonGenerator
	for room in generator.rooms:
		if room is ArenaRoom and not room is ExitRoom:
			player().teleport_to(Transform3D(Basis(), room.global_position + Vector3(0, 0.3, 6)))
			break
	for _i in 8:
		PlayerData.heal_full()
		await frames(30)
	await shot("06_arena_fight")
	for room in generator.rooms:
		if room.name.begins_with("PLATFORM") or room.scene_file_path.ends_with("PlatformRoom.tscn"):
			player().teleport_to(Transform3D(Basis(), room.global_position + Vector3(-14, 0.3, 14)))
			await frames(40)
			await shot("07_platform_room")
			break
	for room in generator.rooms:
		if room is ExitRoom:
			player().teleport_to(Transform3D(Basis(), room.global_position + Vector3(0, 0.3, 9)))
			for _i in 6:
				PlayerData.heal_full()
				await frames(30)
			await shot("08_boss_room")
			break

	GameManager.start_tutorial()
	await frames(60)
	await shot("09_tutorial_start")
	var p := player()
	p.teleport_to(Transform3D(Basis(), Vector3(0, 0.3, -64)))
	Input.action_press("accelerate")
	await frames(62)
	await shot("10_tutorial_jump")
	Input.action_release("accelerate")
	PlayerData.reset_save()
	tree.quit()


## Dungeon lighting/camera/HUD with a single hand-picked room instead of a generated layout.
func _stage(room_path: String, player_position: Vector3, yaw: float) -> PlayerVehicle:
	var dungeon := (load("res://scenes/world/Dungeon.tscn") as PackedScene).instantiate()
	var generator := dungeon.get_node("DungeonGenerator")
	dungeon.remove_child(generator)
	generator.free()
	dungeon.add_child((load(room_path) as PackedScene).instantiate())
	var p := (load("res://scenes/player/PlayerVehicle.tscn") as PackedScene).instantiate() as PlayerVehicle
	dungeon.add_child(p)
	var old := tree.current_scene
	tree.root.add_child(dungeon)
	tree.current_scene = dungeon
	if old != null:
		old.queue_free()
	await frames(2)
	p.teleport_to(Transform3D(Basis(Vector3.UP, deg_to_rad(yaw)), player_position))
	PlayerData.heal_full()
	return p


func _room_shots() -> void:
	var p := await _stage("res://scenes/world/rooms/PlatformRoom.tscn", Vector3(0, 0.3, 22), 0.0)
	var camera := tree.current_scene.get_node("IsometricCamera") as IsometricCamera
	camera.offset = Vector3(0, 52, 36)
	camera.snap_to_target()
	await frames(20)
	await shot("30_platform_room_wide")
	p = await _stage("res://scenes/world/rooms/gauntlets/GauntletLavaNorth.tscn", Vector3(0, 0.3, 24), 0.0)
	camera = tree.current_scene.get_node("IsometricCamera") as IsometricCamera
	camera.offset = Vector3(0, 52, 36)
	camera.snap_to_target()
	await frames(20)
	await shot("31_gauntlet_wide")
	p = await _stage("res://scenes/world/rooms/MazeRoomA.tscn", Vector3(0, 0.3, 22), 0.0)
	await frames(20)
	await shot("32_maze_gamecam")

	GameManager.go_to_garage()
	await frames(30)
	PlayerData.add_scrap(400)
	var shop := tree.current_scene.get("shop_ui") as ShopUI
	shop.open()
	shop.tab_container.current_tab = 4
	await frames(10)
	await shot("33_shop_utility")
	shop.close()
	var summary := tree.current_scene.get("run_summary") as RunSummary
	summary.show_summary({"success": true, "depth": 3, "time": 312.0, "scrap": 168, "scrap_lost": 0, "kills": 34, "rooms": 7,
		"best_combo": 6, "boss": true, "damage": 142.0, "score": 9840, "new_best": true, "best_score": 9840})
	await frames(10)
	await shot("34_run_summary")


func _new_feature_shots() -> void:
	GameManager.start_run()
	await frames(60)
	var generator := tree.current_scene.get_node("DungeonGenerator") as DungeonGenerator
	for door in generator.get_node("Doors").get_children():
		(door as Door).lock()
	await frames(30)
	for door in generator.get_node("Doors").get_children():
		var d := door as Node3D
		if absf(d.global_transform.basis.x.z) > 0.9:
			player().teleport_to(Transform3D(Basis(), d.global_position + d.global_transform.basis.z * 7.0 + Vector3(0, 0.3, 0)))
			break
	await frames(30)
	await shot("20_side_door_locked")
	ComboTracker.register_drift(1.8)
	ComboTracker.register_air(1.1, true)
	ComboTracker.register_kill()
	PlayerData.unlocked_flags["rocket_mouse_aim"] = true
	Input.warp_mouse(Vector2(1180, 330))
	await frames(12)
	await shot("21_combo_and_aim")

	var p := await _stage("res://scenes/world/rooms/gauntlets/GauntletLavaNorth.tscn", Vector3(0, 0.3, 18), 0.0)
	await frames(10)
	Input.action_press("accelerate")
	await frames(48)
	await shot("22_gauntlet_lava_jump")
	Input.action_release("accelerate")

	p = await _stage("res://scenes/world/rooms/gauntlets/GauntletSpikeEast.tscn", Vector3(-18, 0.3, 0), -90.0)
	await frames(10)
	Input.action_press("accelerate")
	await frames(46)
	await shot("23_gauntlet_spike_jump")
	Input.action_release("accelerate")

	for case in [["PyreArchon", 95, "24_boss_archon"], ["SiegeCrawler", 75, "25_boss_siege"]]:
		p = await _stage("res://scenes/world/rooms/ArenaRoom.tscn", Vector3(0, 0.3, 7), 0.0)
		p.controls_locked = true
		var boss := (load("res://scenes/enemies/%s.tscn" % case[0]) as PackedScene).instantiate() as Node3D
		tree.current_scene.add_child(boss)
		boss.global_position = Vector3(0, 0.5, -9)
		for _i in 3:
			PlayerData.heal_full()
			await frames(case[1] / 3)
		await shot(case[2])


func _gallery() -> void:
	var world := Node3D.new()
	world.name = "Gallery"
	tree.root.add_child(world)
	var old := tree.current_scene
	tree.current_scene = world
	if old != null:
		old.queue_free()
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.12, 0.1, 0.09)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.65, 0.6)
	e.ambient_light_energy = 0.6
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.glow_enabled = true
	env.environment = e
	world.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	world.add_child(sun)
	var floor_mesh := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 40)
	floor_mesh.mesh = plane
	world.add_child(floor_mesh)

	var row_a := [["buggy", Vector3(-12, 0, 0)], ["rammer", Vector3(-7, 0, 0)], ["caster", Vector3(-3, 0, 0)],
		["mortar_buggy", Vector3(1, 0, 0)], ["dummy", Vector3(5, 0, 0)], ["crate", Vector3(8, 0.7, 0)], ["scrap", Vector3(10.5, 0.4, 0)]]
	for entry in row_a:
		_place_model(world, entry[0], entry[1])
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(-1, 6, 13)
	camera.look_at(Vector3(-1, 0.8, 0))
	camera.current = true
	await frames(10)
	await shot("02a_gallery_vehicles")

	for child in world.get_children():
		if child is MeshInstance3D and child != floor_mesh or child is Node3D and child.name.begins_with("Model"):
			child.queue_free()
	var row_b := [["door", Vector3(-13, 0, 0)], ["teleporter", Vector3(-5, 0, 0)], ["spikes", Vector3(0, 0, 1)],
		["boost_pad", Vector3(4, 0, 1)], ["ramp", Vector3(10, 0, 0)], ["torch", Vector3(-1, 1.2, -2)], ["brazier", Vector3(14, 0, 0)]]
	for entry in row_b:
		_place_model(world, entry[0], entry[1])
	camera.position = Vector3(0, 9, 16)
	camera.look_at(Vector3(0, 1.2, 0))
	await frames(10)
	await shot("02b_gallery_props")
	world.queue_free()


func _place_model(world: Node3D, key: String, position: Vector3) -> void:
	var holder := Node3D.new()
	holder.name = "Model_" + key
	holder.position = position
	holder.rotation_degrees.y = -25.0
	world.add_child(holder)
	var parts: Array = []
	match key:
		"buggy":
			parts = [["buggy_body", Vector3.ZERO], ["autocannon", Vector3(0, 1.88, 0.35)], ["rocket_pod", Vector3(0, 0.97, -1.0)],
				["wheel", Vector3(-0.95, 0.45, -1.05)], ["wheel", Vector3(0.95, 0.45, -1.05)], ["wheel", Vector3(-0.95, 0.45, 1.05)], ["wheel", Vector3(0.95, 0.45, 1.05)],
				["armor_plates", Vector3(0, 0.82, 0)], ["spoiler", Vector3(0, 1.5, 1.6)]]
		"door":
			parts = [["door_frame", Vector3.ZERO], ["door_gate", Vector3.ZERO]]
		"teleporter":
			parts = [["teleporter_base", Vector3.ZERO], ["teleporter_active", Vector3.ZERO], ["teleporter_ring", Vector3(0, 1.3, 0)]]
		"spikes":
			parts = [["spike_base", Vector3.ZERO], ["spikes", Vector3.ZERO]]
		_:
			parts = [[key, Vector3.ZERO]]
	for part in parts:
		var mi := MeshInstance3D.new()
		mi.mesh = load("res://models/%s.tres" % part[0])
		mi.position = part[1]
		if key == "scrap":
			mi.scale = Vector3.ONE * 2.5
			mi.rotation_degrees.x = 60.0
		holder.add_child(mi)
