class_name WaveSpawner
extends Node3D
## Spawns WaveData waves at random Marker3D spawn points, tracks the enemies still alive
## and emits all_waves_completed when the last wave is wiped out.
## With `randomize_waves` on, the waves are rolled fresh every time the spawner starts:
## a random number of waves, each filled with random enemies from `enemy_options` until its
## threat budget runs out. The budget grows with the wave number and with the run depth.

signal wave_started(wave_index: int, total_waves: int)
signal wave_completed(wave_index: int)
signal all_waves_completed
signal enemies_remaining_changed(count: int)

enum SpawnerState { IDLE, WAITING, SPAWNING, FIGHTING, FINISHED }

@export var waves: Array[WaveData] = []
## Parent of the Marker3D spawn points. Defaults to this node.
@export var spawn_points_root: Node3D
## Where spawned enemies are parented. Defaults to this node's parent (the room).
@export var enemy_container: Node
@export var spawn_effect: PackedScene
## Spawn points closer than this to the player are skipped when possible.
@export var min_distance_from_player: float = 6.0

@export_group("Random Waves")
@export var randomize_waves: bool = false
@export var enemy_options: Array[WaveEnemyOption] = []
@export var min_waves: int = 2
@export var max_waves: int = 4
## Extra waves per 3 depth levels (capped at +2).
@export var waves_per_three_depth: int = 1
## Threat points in the first wave on the first run...
@export var base_budget: float = 6.0
## ...plus this much for each later wave...
@export var budget_per_wave: float = 2.5
## ...plus this much per depth level.
@export var budget_per_depth: float = 2.0
@export var max_enemies_per_wave: int = 14
## Optional boss that joins the final wave (boss rooms), with random escorts.
@export var boss_scene: PackedScene
@export var boss_escort_budget: float = 4.0

var enemies_remaining: int = 0
var current_wave: int = -1
var state: SpawnerState = SpawnerState.IDLE

var _spawn_queue: Array[PackedScene] = []
var _timer: float = 0.0
var _spawn_interval: float = 0.5


func start() -> void:
	if state != SpawnerState.IDLE:
		return
	if randomize_waves:
		waves = generate_waves(GameManager.get_depth_level() if GameManager.run_active else 0)
	current_wave = -1
	_advance_wave()


## True if starting this spawner will produce at least one wave.
func has_waves() -> bool:
	return (randomize_waves and (not enemy_options.is_empty() or boss_scene != null)) or not waves.is_empty()


## Rolls a fresh set of random waves for the given depth level (0 = first run).
func generate_waves(depth_level: int) -> Array[WaveData]:
	var result: Array[WaveData] = []
	var count := randi_range(min_waves, maxi(max_waves, min_waves)) + mini(depth_level / 3 * waves_per_three_depth, 2)
	for i in count:
		var is_boss_wave := boss_scene != null and i == count - 1
		var budget := base_budget + budget_per_wave * i + budget_per_depth * depth_level
		if is_boss_wave:
			budget = boss_escort_budget + budget_per_depth * depth_level * 0.5
		budget *= randf_range(0.85, 1.2)
		var picks := _roll_enemies(budget, depth_level, not is_boss_wave)
		if is_boss_wave:
			picks.push_front(boss_scene)
		var wave := WaveData.new()
		var groups: Array[SpawnGroup] = []
		for scene in picks:
			var group: SpawnGroup = null
			for existing in groups:
				if existing.enemy_scene == scene:
					group = existing
			if group == null:
				group = SpawnGroup.new()
				group.enemy_scene = scene
				group.count = 0
				groups.append(group)
			group.count += 1
		wave.groups = groups
		wave.delay_before_wave = 2.0 if is_boss_wave else randf_range(1.0, 1.8)
		wave.spawn_interval = randf_range(0.35, 0.65)
		result.append(wave)
	return result


## Buys random enemies until the budget (or max_enemies_per_wave) runs out.
func _roll_enemies(budget: float, depth_level: int, at_least_one: bool) -> Array[PackedScene]:
	var picks: Array[PackedScene] = []
	var spent := 0.0
	while picks.size() < max_enemies_per_wave:
		var affordable: Array[WaveEnemyOption] = []
		var total_weight := 0.0
		for option in enemy_options:
			if option != null and option.enemy_scene != null and depth_level >= option.min_depth and spent + option.cost <= budget:
				affordable.append(option)
				total_weight += option.weight
		if affordable.is_empty():
			break
		var roll := randf() * total_weight
		var chosen := affordable[affordable.size() - 1]
		for option in affordable:
			roll -= option.weight
			if roll <= 0.0:
				chosen = option
				break
		picks.append(chosen.enemy_scene)
		spent += chosen.cost
	if picks.is_empty() and at_least_one:
		var cheapest: WaveEnemyOption = null
		for option in enemy_options:
			if option != null and option.enemy_scene != null and (cheapest == null or option.cost < cheapest.cost):
				cheapest = option
		if cheapest != null:
			picks.append(cheapest.enemy_scene)
	return picks


func is_running() -> bool:
	return state == SpawnerState.WAITING or state == SpawnerState.SPAWNING or state == SpawnerState.FIGHTING


func _physics_process(delta: float) -> void:
	match state:
		SpawnerState.WAITING:
			_timer -= delta
			if _timer <= 0.0:
				state = SpawnerState.SPAWNING
				_timer = 0.0
		SpawnerState.SPAWNING:
			_timer -= delta
			if _timer <= 0.0:
				if _spawn_queue.is_empty():
					state = SpawnerState.FIGHTING
					_check_wave_complete()
				else:
					_spawn_enemy(_spawn_queue.pop_front())
					_timer = _spawn_interval


func _advance_wave() -> void:
	current_wave += 1
	if current_wave >= waves.size():
		state = SpawnerState.FINISHED
		all_waves_completed.emit()
		return
	var wave := waves[current_wave]
	_spawn_queue.clear()
	if wave != null:
		var largest_group: SpawnGroup = null
		for group in wave.groups:
			if group == null or group.enemy_scene == null:
				continue
			for _i in group.count:
				_spawn_queue.append(group.enemy_scene)
			if largest_group == null or group.count > largest_group.count:
				largest_group = group
		# Hand-authored waves get extra regular enemies at depth (random waves scale via their budget).
		if not randomize_waves and largest_group != null and largest_group.count > 1:
			for _i in GameManager.extra_enemies_per_wave():
				_spawn_queue.append(largest_group.enemy_scene)
		if wave.shuffle_spawn_order:
			_spawn_queue.shuffle()
		_spawn_interval = wave.spawn_interval
		_timer = wave.delay_before_wave
	state = SpawnerState.WAITING
	wave_started.emit(current_wave, waves.size())


func _spawn_enemy(scene: PackedScene) -> void:
	var enemy := scene.instantiate() as Node3D
	if enemy == null:
		push_warning("WaveSpawner: enemy scene root must be a Node3D.")
		return
	var parent: Node = enemy_container if enemy_container != null else get_parent()
	var point := _pick_spawn_point()
	parent.add_child(enemy)
	enemy.global_position = point
	if enemy.has_signal("died"):
		enemy.connect("died", _on_enemy_died)
	enemies_remaining += 1
	enemies_remaining_changed.emit(enemies_remaining)
	GameManager.spawn_effect(spawn_effect, point)


func _on_enemy_died(_enemy: Node) -> void:
	enemies_remaining = maxi(enemies_remaining - 1, 0)
	enemies_remaining_changed.emit(enemies_remaining)
	_check_wave_complete()


func _check_wave_complete() -> void:
	if state != SpawnerState.FIGHTING or enemies_remaining > 0:
		return
	wave_completed.emit(current_wave)
	_advance_wave()


func _pick_spawn_point() -> Vector3:
	var root: Node3D = spawn_points_root if spawn_points_root != null else self
	var points: Array[Vector3] = []
	for child in root.get_children():
		if child is Marker3D:
			points.append((child as Marker3D).global_position)
	if points.is_empty():
		return global_position

	var player := get_tree().get_first_node_in_group("player") as Node3D
	var candidates: Array[Vector3] = []
	for point in points:
		if player == null or point.distance_to(player.global_position) >= min_distance_from_player:
			candidates.append(point)
	if candidates.is_empty():
		candidates = points
	return candidates.pick_random()
