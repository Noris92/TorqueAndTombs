class_name ArenaRoom
extends BaseRoom
## Combat arena: when the player enters, all doors slam shut and the WaveSpawner starts.
## After the last wave the doors unlock, rewards drop and the room is marked CLEARED.

@export var wave_spawner: WaveSpawner
## Delay before the doors lock, so the buggy is fully inside.
@export var lock_delay: float = 0.5
@export var reward_crate_scene: PackedScene
## Parent of Marker3D points where reward crates appear. Defaults to the child "RewardPoints".
@export var reward_points_root: Node3D
@export var clear_scrap_bonus: int = 15
@export var scrap_pickup_scene: PackedScene
@export var lock_message: String = "The doors slam shut!"
@export var clear_message: String = "Arena cleared!"
@export var show_wave_messages: bool = true


func _ready() -> void:
	super()
	clear_on_enter = false
	if wave_spawner == null:
		wave_spawner = get_node_or_null("WaveSpawner") as WaveSpawner
	if reward_points_root == null:
		reward_points_root = get_node_or_null("RewardPoints") as Node3D
	if wave_spawner != null:
		wave_spawner.all_waves_completed.connect(_on_all_waves_completed)
		wave_spawner.wave_started.connect(_on_wave_started)


func _on_player_entered() -> void:
	player_entered.emit(self)
	if state != RoomState.UNVISITED:
		return
	set_state(RoomState.ACTIVE)
	if wave_spawner == null or not wave_spawner.has_waves():
		_complete_arena()
		return
	get_tree().create_timer(lock_delay, false).timeout.connect(_begin_combat)


func _begin_combat() -> void:
	lock_doors()
	if lock_message != "":
		GameManager.show_message(lock_message)
	wave_spawner.start()


func _on_wave_started(wave_index: int, total_waves: int) -> void:
	if show_wave_messages and total_waves > 1:
		GameManager.show_message("Wave %d / %d" % [wave_index + 1, total_waves], 1.5)


func _on_all_waves_completed() -> void:
	# Usually fires from inside a physics callback (the last enemy dying), so defer the spawning.
	_complete_arena.call_deferred()


func _complete_arena() -> void:
	unlock_doors()
	_drop_rewards()
	mark_cleared()
	if clear_message != "":
		GameManager.show_message(clear_message)


func _drop_rewards() -> void:
	var scene_root := get_tree().current_scene
	ScrapPickup.spawn_burst(scrap_pickup_scene, scene_root, global_position + Vector3.UP, clear_scrap_bonus, 8)
	if reward_crate_scene == null or reward_points_root == null:
		return
	for point in reward_points_root.get_children():
		var marker := point as Node3D
		if marker == null:
			continue
		var crate := reward_crate_scene.instantiate() as Node3D
		if crate != null:
			add_child(crate)
			crate.global_transform = marker.global_transform
