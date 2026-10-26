extends Node
## Scripted playtest of the real scenes. Prints PASS/FAIL lines and quits with the failure count.

var failures: int = 0
var tree: SceneTree


func _ready() -> void:
	tree = get_tree()
	_run.call_deferred()


func check(condition: bool, what: String) -> void:
	print(("  PASS  " if condition else "  FAIL  ") + what)
	if not condition:
		failures += 1


func frames(count: int) -> void:
	for _i in count:
		await tree.physics_frame


func player() -> PlayerVehicle:
	return tree.get_first_node_in_group("player") as PlayerVehicle


func place(p: PlayerVehicle, position: Vector3, yaw_degrees: float = 0.0) -> void:
	p.teleport_to(Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_degrees)), position))


func _run() -> void:
	PlayerData.reset_save()
	await _test_main_menu()
	await _test_dungeon_run()
	await _test_garage()
	await _test_upgrades_in_run()
	await _test_death()
	await _test_tutorial()
	await _test_platform_jump()
	await _test_enemy_pathing()
	await _test_crate_touch()
	await _test_wall_hop()
	await _test_gauntlets()
	await _test_generator_variety()
	await _test_bosses()
	await _test_progression()
	_test_random_waves()
	PlayerData.reset_save()
	print("TESTS FINISHED: %d failure(s)" % failures)
	tree.quit(failures)


func _test_main_menu() -> void:
	print("== Main menu")
	tree.change_scene_to_file("res://scenes/ui/MainMenu.tscn")
	await frames(10)
	check(tree.current_scene != null and tree.current_scene.name == "MainMenu", "main menu loads")


func _test_dungeon_run() -> void:
	print("== Dungeon run")
	GameManager.start_run()
	await frames(20)
	var generator := tree.current_scene.get_node_or_null("DungeonGenerator") as DungeonGenerator
	check(generator != null and generator.rooms.size() >= 7, "dungeon generated %d rooms" % (generator.rooms.size() if generator else 0))
	var p := player()
	check(p != null, "player spawned")
	if p == null or generator == null:
		return
	await frames(30)
	check(p.is_on_floor(), "player resting on the start room floor")
	var start_z := p.global_position.z
	Input.action_press("accelerate")
	await frames(40)
	Input.action_release("accelerate")
	check(absf(p.global_position.z - start_z) > 3.0 or p.get_speed() > 3.0, "player drives (speed %.1f)" % p.get_speed())

	var gates_aligned := true
	var side_doors := 0
	for door in generator.get_node("Doors").get_children():
		var gate := (door as Door).gate
		gates_aligned = gates_aligned and gate.global_transform.basis.x.normalized().dot((door as Node3D).global_transform.basis.x.normalized()) > 0.99
		if absf((door as Node3D).global_transform.basis.x.z) > 0.9:
			side_doors += 1
	check(gates_aligned, "door gates line up with their frames (%d side doors)" % side_doors)

	var arena: ArenaRoom = null
	var exit_room: ExitRoom = null
	for room in generator.rooms:
		if room is ExitRoom:
			exit_room = room
		elif room is ArenaRoom and arena == null:
			arena = room
	check(arena != null and exit_room != null, "arena and exit rooms exist")
	if arena == null or exit_room == null:
		return

	place(p, arena.global_position + Vector3(0, 0.3, 0))
	await frames(60)
	check(arena.state == BaseRoom.RoomState.ACTIVE, "arena becomes ACTIVE on entry")
	var all_locked := not arena.doors.is_empty()
	for door in arena.doors:
		all_locked = all_locked and door.is_locked
	check(all_locked, "arena doors lock (%d doors)" % arena.doors.size())
	await frames(90)
	check(arena.wave_spawner.enemies_remaining > 0, "wave 1 spawned %d enemies" % arena.wave_spawner.enemies_remaining)
	var shots_fired := [0]
	var turret := p.get_node("VisualRoot/RoofTurret") as TurretController
	turret.fired.connect(func(_w: WeaponResource) -> void: shots_fired[0] += 1)
	await frames(90)
	check(shots_fired[0] > 0, "roof turret auto-fires at enemies (%d shots)" % shots_fired[0])
	var scrap_before := PlayerData.scrap_currency
	check(await _clear_waves(arena), "all arena waves cleared")
	var all_open := true
	for door in arena.doors:
		all_open = all_open and not door.is_locked
	check(all_open, "arena doors unlock after clearing")
	await frames(150)
	check(PlayerData.scrap_currency > scrap_before, "scrap collected (%d -> %d)" % [scrap_before, PlayerData.scrap_currency])

	place(p, exit_room.global_position + Vector3(0, 0.3, 7))
	await frames(60)
	check(exit_room.state == BaseRoom.RoomState.ACTIVE, "boss room locks on entry")
	check(not exit_room.teleporter.active, "exit teleporter dormant during the fight")
	check(await _clear_waves(exit_room), "boss waves cleared")
	await frames(5)
	check(exit_room.teleporter.active, "exit teleporter activates")
	place(p, exit_room.global_position + Vector3(0, 0.3, 0))
	await frames(40)
	check(tree.current_scene != null and tree.current_scene.name == "GarageHub", "teleporter returns to the garage")
	await frames(5)
	var summary_ui := tree.current_scene.get("run_summary") as RunSummary
	check(summary_ui != null and summary_ui.visible and summary_ui.score_label.text.begins_with("SCORE"), "score screen shows after the run (%s)" % (summary_ui.score_label.text if summary_ui != null else "none"))
	check(summary_ui != null and summary_ui.stats_grid.get_child_count() >= 14, "score screen lists time, scrap, kills, rooms, combo, boss, damage")
	check(PlayerData.runs_completed == 1 and GameManager.get_depth() == 2, "a successful run goes one level deeper (depth %d)" % GameManager.get_depth())
	if summary_ui != null:
		summary_ui.close()


func _clear_waves(room: BaseRoom) -> bool:
	for _i in 80:
		PlayerData.heal_full()
		for enemy in tree.get_nodes_in_group("enemies"):
			if enemy is BaseEnemy and room.is_ancestor_of(enemy):
				(enemy as BaseEnemy).take_damage(99999.0)
		await frames(30)
		if room.state == BaseRoom.RoomState.CLEARED:
			return true
	return false


func _test_garage() -> void:
	print("== Garage")
	await frames(30)
	var garage := tree.current_scene
	var shop := garage.get("shop_ui") as ShopUI
	var p := player()
	check(shop != null and p != null, "garage has shop and player")
	if shop == null or p == null:
		return
	PlayerData.add_scrap(1000)
	shop.open()
	await frames(2)
	check(tree.paused, "shop pauses the game")
	shop._on_buy_pressed(load("res://data/upgrades/twin_cannon_unlock.tres"))
	shop._on_buy_pressed(load("res://data/upgrades/armor_plating.tres"))
	shop._on_buy_pressed(load("res://data/upgrades/engine_turbo.tres"))
	shop.close()
	await frames(5)
	var turret := p.get_node("VisualRoot/RoofTurret") as TurretController
	check(turret.weapon != null and turret.weapon.weapon_name == "Twin Cannon", "twin cannon equipped")
	check(p.get_node("VisualRoot/Mounts/SideMounts").get_child_count() == 1, "armor plates attached to the buggy")
	check(p.get_node("VisualRoot/Mounts/RearMount").get_child_count() == 1, "spoiler attached to the buggy")
	check(is_equal_approx(PlayerData.max_health, 125.0) and is_equal_approx(PlayerData.top_speed, 24.5), "stats upgraded (hp %.0f, top speed %.1f)" % [PlayerData.max_health, PlayerData.top_speed])
	var tabs := shop.tab_container.get_tab_count()
	check(tabs == 5, "shop has 5 category tabs (incl. Utility)")
	place(p, Vector3(11, 0.3, 0))
	await frames(90)
	check(shop.is_open, "parking in the bay opens the shop")
	shop.close()
	await frames(2)


func _test_upgrades_in_run() -> void:
	print("== Upgrades carry into runs")
	GameManager.start_run()
	await frames(30)
	var p := player()
	var turret := p.get_node("VisualRoot/RoofTurret") as TurretController
	check(turret.weapon != null and turret.weapon.weapon_name == "Twin Cannon", "twin cannon still equipped in the dungeon (%s)" % (turret.weapon.weapon_name if turret.weapon else "none"))
	check(not String(PlayerData.equipped_weapons.get("turret", "")).contains("::"), "equipped weapon saved as a real file path")
	check(p.get_node("VisualRoot/Mounts/SideMounts").get_child_count() == 1, "armor plates visible in the dungeon")
	var probe := (load("res://scenes/enemies/RammerEnemy.tscn") as PackedScene).instantiate() as BaseEnemy
	tree.current_scene.add_child(probe)
	check(is_equal_approx(probe.max_health, 35.0 * 1.2) and probe.scrap_reward == 2, "depth 2 enemies are tougher (rammer hp %.1f, was 35)" % probe.max_health)
	probe.queue_free()

	print("== Combo")
	var scrap_before := PlayerData.scrap_currency
	ComboTracker.register_drift(2.0)
	ComboTracker.register_kill()
	ComboTracker.register_kill()
	var expected := ComboTracker.get_payout()
	check(ComboTracker.multiplier == 3 and expected == 9, "drift + 2 quick kills = x3 combo worth %d scrap" % expected)
	await frames(240)
	check(PlayerData.scrap_currency == scrap_before + expected, "combo cashes in after the window (+%d)" % (PlayerData.scrap_currency - scrap_before))

	print("== Mouse / stick aimed rockets")
	PlayerData.unlocked_flags["rocket_mouse_aim"] = true
	var rockets: Array[Node] = []
	var watcher := func(node: Node) -> void:
		if node is Rocket:
			rockets.append(node)
	tree.current_scene.child_entered_tree.connect(watcher)
	var stick := InputEventJoypadMotion.new()
	stick.device = 0
	stick.axis = JOY_AXIS_RIGHT_X
	stick.axis_value = 1.0
	Input.parse_input_event(stick)
	await frames(20)
	Input.action_press("fire_rocket")
	await frames(2)
	Input.action_release("fire_rocket")
	await frames(2)
	stick.axis_value = 0.0
	Input.parse_input_event(stick)
	tree.current_scene.child_entered_tree.disconnect(watcher)
	var aimed := not rockets.is_empty() and is_instance_valid(rockets[0]) and (rockets[0] as Rocket).velocity.normalized().x > 0.9
	check(aimed, "Targeting Computer: right stick aims the rocket sideways")
	var launcher := p.get_node("VisualRoot/RocketLauncher") as RocketLauncher
	check(absf(launcher.rotation.y) > 0.5, "rocket pod swivels toward the aim (yaw %.0f deg)" % rad_to_deg(launcher.rotation.y))
	PlayerData.unlocked_flags.erase("rocket_mouse_aim")


func _test_death() -> void:
	print("== Death")
	GameManager.start_run()
	await frames(30)
	GameManager.run_scrap_collected = 40
	ComboTracker.register_kill()
	var scrap_before := PlayerData.scrap_currency
	PlayerData.take_damage(99999.0)
	check(not ComboTracker.is_active(), "getting wrecked loses the running combo")
	await frames(200)
	check(tree.current_scene != null and tree.current_scene.name == "GarageHub", "wreck sends you back to the garage")
	check(PlayerData.scrap_currency == scrap_before - 20, "death penalty: lost half of the run's scrap")


func _test_tutorial() -> void:
	print("== Tutorial")
	GameManager.start_tutorial()
	await frames(30)
	var tutorial := tree.current_scene
	var p := player()
	check(p != null, "tutorial spawns the player")
	if p == null:
		return
	var drift_gate := tutorial.get("drift_gate") as Door
	var crate_gate := tutorial.get("crate_gate") as Door
	var target_gate := tutorial.get("target_gate") as Door
	var teleporter := tutorial.get("teleporter") as Teleporter
	check(drift_gate.is_locked and crate_gate.is_locked and target_gate.is_locked, "all tutorial gates start locked")
	check(not teleporter.active, "tutorial teleporter starts dormant")

	var respawned := [false]
	p.respawned.connect(func() -> void: respawned[0] = true)
	place(p, Vector3(0, 0.3, -64))
	await frames(10)
	Input.action_press("accelerate")
	await frames(200)
	Input.action_release("accelerate")
	await frames(30)
	check(not respawned[0] and p.global_position.z < -96.0, "boost pad + ramp clears the lava (landed at z %.1f)" % p.global_position.z)

	p.drift_ended.connect(func(duration: float, boosted: bool) -> void: print("    drift ended: %.2f s, boosted=%s, speed %.1f" % [duration, boosted, p.get_speed()]))
	# Drift in the open stretch after the jump.
	place(p, Vector3(0, 0.3, -98))
	await frames(5)
	Input.action_press("accelerate")
	await frames(40)
	Input.action_press("drift")
	for step in [["steer_left", 12], ["steer_right", 24], ["steer_left", 14]]:
		Input.action_press(step[0])
		await frames(step[1])
		Input.action_release(step[0])
	Input.action_release("drift")
	Input.action_release("accelerate")
	await frames(5)
	check(not drift_gate.is_locked, "a held drift opens the drift gate")

	for crate in tutorial.get("crates_root").get_children():
		crate.take_damage(999.0)
	await frames(10)
	check(not crate_gate.is_locked, "smashing every crate opens the crate gate")
	for dummy in tutorial.get("dummies_root").get_children():
		dummy.take_damage(999.0)
	await frames(10)
	check(not target_gate.is_locked and teleporter.active, "destroying the dummies opens the last gate and teleporter")
	place(p, Vector3(0, 0.3, -193))
	await frames(40)
	check(PlayerData.tutorial_completed and tree.current_scene.name == "GarageHub", "tutorial teleporter completes the tutorial")


func _test_platform_jump() -> void:
	print("== Lava platform room")
	var world := Node3D.new()
	world.name = "TestWorld"
	tree.root.add_child(world)
	var old := tree.current_scene
	tree.current_scene = world
	if old != null:
		old.queue_free()
	world.add_child((load("res://scenes/world/rooms/PlatformRoom.tscn") as PackedScene).instantiate())
	var p := (load("res://scenes/player/PlayerVehicle.tscn") as PackedScene).instantiate() as PlayerVehicle
	world.add_child(p)
	place(p, Vector3(9, 0.3, 25.0))
	var respawned := [false]
	p.respawned.connect(func() -> void: respawned[0] = true)
	await frames(10)
	Input.action_press("accelerate")
	for i in 9:
		await frames(10)
		print("    t=%.2f pos=%s vel=%s floor=%s" % [i * 10 / 60.0, p.global_position.snapped(Vector3.ONE * 0.1), p.velocity.snapped(Vector3.ONE * 0.1), p.is_on_floor()])
	Input.action_release("accelerate")
	await frames(30)
	check(not respawned[0] and p.global_position.z < -13.0 and p.global_position.y > -0.5, "boost pad jump clears the wider lava pool (z %.1f)" % p.global_position.z)
	place(p, Vector3(-18, 0.3, -18))
	await frames(60)
	p.global_position = Vector3(0, 2.0, 0)
	await frames(110)
	check(respawned[0], "falling into lava respawns the buggy")
	check(PlayerData.current_health < PlayerData.max_health, "lava burns (hp %.0f)" % PlayerData.current_health)
	PlayerData.heal_full()


func _fresh_world(room_path: String) -> Dictionary:
	var world := tree.current_scene
	for child in world.get_children():
		child.queue_free()
	await frames(2)
	var room := (load(room_path) as PackedScene).instantiate() as Node3D
	world.add_child(room)
	var p := (load("res://scenes/player/PlayerVehicle.tscn") as PackedScene).instantiate() as PlayerVehicle
	world.add_child(p)
	PlayerData.heal_full()
	return {"world": world, "room": room, "player": p}


func _test_crate_touch() -> void:
	print("== Crates")
	var ctx: Dictionary = await _fresh_world("res://scenes/world/rooms/StartRoom.tscn")
	var p: PlayerVehicle = ctx.player
	var crate: Node3D = null
	for node in (ctx.room as Node).get_children():
		if node is LootCrate and (node as Node3D).position.x < 0.0:
			crate = node
	place(p, Vector3(crate.global_position.x, 0.3, crate.global_position.z + 12.0))
	await frames(5)
	Input.action_press("accelerate")
	var worst_drop := 0.0
	var previous := 0.0
	for _i in 60:
		await frames(1)
		var speed := p.get_speed()
		if previous > 5.0:
			worst_drop = maxf(worst_drop, (previous - speed) / previous)
		previous = speed
	Input.action_release("accelerate")
	check(not is_instance_valid(crate), "driving into a crate smashes it")
	check(worst_drop < 0.1, "smashing a crate keeps your speed (worst frame drop %.0f%%)" % (worst_drop * 100.0))


func _test_wall_hop() -> void:
	print("== Wall hopping")
	var ctx: Dictionary = await _fresh_world("res://scenes/world/rooms/PlatformRoom.tscn")
	var p: PlayerVehicle = ctx.player
	place(p, Vector3(18, 0.3, -18))
	p.controls_locked = true
	await frames(5)
	p.velocity = Vector3(0, 14, -35)
	await frames(70)
	check(p.global_position.z > -27.5, "a huge boosted jump can't clear the room wall (z %.1f)" % p.global_position.z)


func _test_gauntlets() -> void:
	print("== Gauntlets")
	for case in [["GauntletLavaNorth", Vector3(0, 0.3, 18.0), 0.0, Vector3(0, 0, -1)],
			["GauntletSpikeEast", Vector3(-18.0, 0.3, 0), -90.0, Vector3(1, 0, 0)],
			["GauntletLavaWest", Vector3(18.0, 0.3, 0), 90.0, Vector3(-1, 0, 0)],
			["GauntletSpikeSouth", Vector3(0, 0.3, -18.0), 180.0, Vector3(0, 0, 1)]]:
		var ctx: Dictionary = await _fresh_world("res://scenes/world/rooms/gauntlets/%s.tscn" % case[0])
		var p: PlayerVehicle = ctx.player
		var respawned := [false]
		p.respawned.connect(func() -> void: respawned[0] = true)
		place(p, case[1], case[2])
		await frames(5)
		Input.action_press("accelerate")
		await frames(90)
		Input.action_release("accelerate")
		await frames(40)
		var progress: float = p.global_position.dot(case[3])
		check(not respawned[0] and progress > 8.0 and p.global_position.y > -0.5, "%s: boost jump crosses the trench (%.1f m past centre)" % [case[0], progress])

	var ctx2: Dictionary = await _fresh_world("res://scenes/world/rooms/gauntlets/GauntletLavaNorth.tscn")
	var q: PlayerVehicle = ctx2.player
	var fell := [false]
	q.respawned.connect(func() -> void: fell[0] = true)
	place(q, Vector3(12, 0.3, 17))
	await frames(5)
	Input.action_press("accelerate")
	Input.action_press("boost")
	await frames(100)
	Input.action_release("accelerate")
	Input.action_release("boost")
	await frames(60)
	check(fell[0], "skipping the pad (even with nitro) drops you in the lava")


func _test_generator_variety() -> void:
	print("== Generator")
	var world := tree.current_scene
	for child in world.get_children():
		child.queue_free()
	await frames(2)
	var dungeon := (load("res://scenes/world/Dungeon.tscn") as PackedScene).instantiate()
	var generator := dungeon.get_node("DungeonGenerator") as DungeonGenerator
	dungeon.remove_child(generator)
	dungeon.free()
	generator.generate_on_ready = false
	world.add_child(generator)
	var gauntlets := 0
	var bad_gauntlets := 0
	var bosses := {}
	var runs_with_treasure := 0
	for seed_value in range(1, 41):
		generator.generation_seed = seed_value
		generator.generate()
		for room in generator.rooms:
			if room.scene_file_path.ends_with("TreasureRoom.tscn"):
				runs_with_treasure += 1
				break
		for room in generator.rooms:
			if room.scene_file_path.contains("Gauntlet"):
				gauntlets += 1
				# Exactly two doors, on opposite sides, matching the jump direction.
				if room.doors.size() != 2:
					bad_gauntlets += 1
			elif room is ExitRoom:
				bosses[room.scene_file_path.get_file()] = true
		await frames(1)
	check(gauntlets > 5 and bad_gauntlets == 0, "gauntlet rooms appear on straight stretches with 2 doors (%d in 40 runs)" % gauntlets)
	check(bosses.size() == 3, "all three boss rooms show up (%s)" % ", ".join(bosses.keys()))
	check(runs_with_treasure >= 4 and runs_with_treasure <= 20, "treasure vaults are a lucky find (%d of 40 runs)" % runs_with_treasure)
	var first_room := generator.rooms[0]
	check(is_equal_approx(first_room.room_footprint.x, 56.0) and is_equal_approx(generator.cell_size, 56.0), "rooms are 56 m wide")
	generator.clear()
	generator.queue_free()


func _test_bosses() -> void:
	print("== Bosses")
	for case in [["PyreArchon", "EnemyFireball", 5], ["SiegeCrawler", "MortarShell", 5]]:
		var ctx: Dictionary = await _fresh_world("res://scenes/world/rooms/ArenaRoom.tscn")
		var p: PlayerVehicle = ctx.player
		place(p, Vector3(0, 0.3, 8))
		p.controls_locked = true
		var shots := [0]
		var world: Node = ctx.world
		var watcher := func(node: Node) -> void:
			if node.scene_file_path.ends_with("/%s.tscn" % case[1]):
				shots[0] += 1
		world.child_entered_tree.connect(watcher)
		var boss := (load("res://scenes/enemies/%s.tscn" % case[0]) as PackedScene).instantiate() as BaseEnemy
		world.add_child(boss)
		boss.global_position = Vector3(0, 0.5, -12)
		for _i in 10:
			PlayerData.heal_full()
			await frames(24)
		world.child_entered_tree.disconnect(watcher)
		check(shots[0] >= case[2], "%s fires big volleys (%d %s in 4 s)" % [case[0], shots[0], case[1]])
		check(boss.max_health >= 200.0, "%s is a tank (%.0f hp)" % [case[0], boss.max_health])
	PlayerData.heal_full()


func _roll_stats(spawner: WaveSpawner, depth_level: int, rolls: int) -> Dictionary:
	var wave_counts := {}
	var combos := {}
	var total_enemies := 0
	var elites := 0
	for _r in rolls:
		var waves := spawner.generate_waves(depth_level)
		wave_counts[waves.size()] = true
		var combo := []
		for wave in waves:
			for group in wave.groups:
				var scene_name := group.enemy_scene.resource_path.get_file().get_basename()
				combo.append("%s%d" % [scene_name, group.count])
				total_enemies += group.count
				if scene_name in ["Juggernaut", "PyreArchon", "SiegeCrawler"]:
					elites += group.count
		combos[str(combo)] = true
	return {"wave_counts": wave_counts.size(), "combos": combos.size(), "avg_enemies": float(total_enemies) / rolls, "elites": elites}


func _test_random_waves() -> void:
	print("== Random waves")
	var arena := (load("res://scenes/world/rooms/ArenaRoom.tscn") as PackedScene).instantiate()
	var spawner := arena.get_node("WaveSpawner") as WaveSpawner
	var first_run := _roll_stats(spawner, 0, 40)
	var deep_run := _roll_stats(spawner, 4, 40)
	check(spawner.randomize_waves and first_run.wave_counts >= 3, "arena wave count varies (%d different counts)" % first_run.wave_counts)
	check(first_run.combos >= 30, "enemy types and numbers vary (%d unique line-ups in 40 rolls)" % first_run.combos)
	check(first_run.elites == 0, "no elite bosses in arenas on the first run")
	check(deep_run.avg_enemies > first_run.avg_enemies * 1.6, "depth 5 waves are bigger (%.1f enemies per arena vs %.1f)" % [deep_run.avg_enemies, first_run.avg_enemies])
	check(deep_run.elites > 0, "elite Juggernauts can join arenas at depth 5 (%d in 40 rolls)" % deep_run.elites)
	arena.free()
	for room_name in ["ExitRoom", "ExitRoomArchon", "ExitRoomSiege"]:
		var room := (load("res://scenes/world/rooms/%s.tscn" % room_name) as PackedScene).instantiate()
		var boss_spawner := room.get_node("WaveSpawner") as WaveSpawner
		var always_boss := true
		for _r in 10:
			var waves := boss_spawner.generate_waves(0)
			always_boss = always_boss and waves[waves.size() - 1].groups[0].enemy_scene == boss_spawner.boss_scene
		check(always_boss, "%s: random warm-up waves, final wave is always its boss" % room_name)
		room.free()


func _test_progression() -> void:
	print("== Progression & economy")
	var picks: Array[int] = []
	for _i in 60:
		picks.append(GameManager.pick_boss_index(3))
	var repeats := 0
	for i in range(1, picks.size()):
		if picks[i] == picks[i - 1]:
			repeats += 1
	check(repeats == 0 and picks.has(0) and picks.has(1) and picks.has(2), "bosses come up at random, never twice in a row")

	var magnet := load("res://data/upgrades/scrap_magnet.tres") as UpgradeResource
	check(magnet != null and magnet.category == UpgradeResource.Category.UTILITY, "Scrap Magnet is in the Utility tab")
	PlayerData.add_scrap(1000)
	PlayerData.apply_upgrade(magnet)
	PlayerData.apply_upgrade(magnet)
	check(is_equal_approx(PlayerData.magnet_range, 31.0), "Scrap Magnet tier 2 pulls from %.0f m" % PlayerData.magnet_range)
	PlayerData.apply_upgrade(load("res://data/upgrades/scrap_vacuum.tres"))
	check(PlayerData.has_flag("scrap_vacuum"), "Scrap Vacuum unlocks")
	var ctx: Dictionary = await _fresh_world("res://scenes/world/rooms/StartRoom.tscn")
	var p: PlayerVehicle = ctx.player
	GameManager.set_room_grid(Vector3.ZERO, 56.0)
	place(p, Vector3(-22, 0.3, 22))
	p.controls_locked = true
	await frames(5)
	var before := PlayerData.scrap_currency
	var scrap_scene: PackedScene = load("res://scenes/hazards/ScrapPickup.tscn")
	ScrapPickup.spawn_burst(scrap_scene, ctx.world, Vector3(22, 0.5, -22), 5, 5)
	# One piece in the next room over (x = 56) must stay put.
	ScrapPickup.spawn_burst(scrap_scene, ctx.world, Vector3(56, 0.5, 0), 3, 1)
	await frames(300)
	check(PlayerData.scrap_currency == before + 5, "vacuum collects all scrap in your room, corner to corner, but not next door (+%d)" % (PlayerData.scrap_currency - before))
	GameManager.set_room_grid(Vector3.ZERO, 0.0)

	var costs := []
	for item_path in ["engine_turbo", "armor_plating", "hot_rounds", "twin_cannon_unlock"]:
		costs.append((load("res://data/upgrades/%s.tres" % item_path) as UpgradeResource).base_cost)
	check(costs.min() >= 55, "upgrades cost more now (%s)" % str(costs))
	var gold := load("res://scenes/hazards/GoldCrate.tscn").instantiate() as LootCrate
	check(gold.scrap_value >= 20, "treasure gold crates are worth %d scrap" % gold.scrap_value)
	gold.free()


func _test_enemy_pathing() -> void:
	print("== Enemy navigation")
	var world := tree.current_scene
	for child in world.get_children():
		child.queue_free()
	await frames(2)
	world.add_child((load("res://scenes/world/rooms/MazeRoomA.tscn") as PackedScene).instantiate())
	var p := (load("res://scenes/player/PlayerVehicle.tscn") as PackedScene).instantiate() as PlayerVehicle
	world.add_child(p)
	place(p, Vector3(5, 0.3, -21.7))
	p.controls_locked = true
	await frames(5)
	var rammer: BaseEnemy = null
	for enemy in tree.get_nodes_in_group("enemies"):
		if enemy is RammerEnemy and (enemy as Node3D).global_position.x > 10.0:
			rammer = enemy
	check(rammer != null, "maze rammer present")
	if rammer == null:
		return
	var start_distance := rammer.global_position.distance_to(p.global_position)
	await frames(100)
	var end_distance := rammer.global_position.distance_to(p.global_position) if is_instance_valid(rammer) else 0.0
	check(end_distance < start_distance - 4.0, "rammer paths toward the player (%.1f m -> %.1f m)" % [start_distance, end_distance])
