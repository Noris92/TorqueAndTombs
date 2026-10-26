extends Node
## Autoload singleton "GameManager".
## Scene flow (menu / garage / dungeon / tutorial), run bookkeeping, HUD messages,
## shared helpers for one-shot sounds and effects, and default input bindings.
## Register in Project Settings > Globals > Autoload as "GameManager" (below PlayerData).

signal message_requested(text: String, duration: float)
signal run_started
signal run_ended(success: bool)
signal rooms_cleared_changed(count: int)

## Change these if you save your scenes somewhere else.
const MAIN_MENU_SCENE: String = "res://scenes/ui/MainMenu.tscn"
const GARAGE_SCENE: String = "res://scenes/garage/GarageHub.tscn"
const DUNGEON_SCENE: String = "res://scenes/world/Dungeon.tscn"
const TUTORIAL_SCENE: String = "res://scenes/world/TutorialLevel.tscn"

## Fraction of the scrap picked up during a run that is lost when the buggy is wrecked.
var death_scrap_penalty: float = 0.5
## Bonus scrap for reaching the exit teleporter.
var run_success_bonus: int = 15
## Seconds between being wrecked and leaving the level.
var death_return_delay: float = 2.5

# --- Depth scaling: every successful run takes you one level deeper. Per level, enemies get: ---
var health_per_depth: float = 0.2
var damage_per_depth: float = 0.15
var speed_per_depth: float = 0.04
var max_speed_bonus: float = 0.3
var fire_rate_per_depth: float = 0.06
var min_fire_cooldown_factor: float = 0.6
## Extra enemies added to every wave per 2 levels of depth (capped).
var max_extra_enemies_per_wave: int = 4
## Enemy scrap drops grow a little with depth so upgrades stay within reach.
var scrap_per_depth: float = 0.1

var run_active: bool = false
var in_tutorial: bool = false
var run_scrap_collected: int = 0
var rooms_cleared: int = 0
## Shown by the HUD after the next scene loads.
var pending_message: String = ""

# Run stats for the end-of-run score screen
var run_time: float = 0.0
var run_kills: int = 0
var run_best_combo: int = 0
var run_boss_defeated: bool = false
var run_damage_taken: float = 0.0
var last_run_summary: Dictionary = {}
var _last_boss_index: int = -1
var _last_health: float = 0.0
# Room grid of the current dungeon (set by DungeonGenerator), used to tell which room a point is in.
var _room_grid_origin: Vector3 = Vector3.ZERO
var _room_grid_size: float = 0.0


func _enter_tree() -> void:
	_register_default_inputs()


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	PlayerData.player_died.connect(_on_player_died)
	PlayerData.health_changed.connect(_on_health_changed)
	OptionsMenu.apply_saved_settings()


func _process(delta: float) -> void:
	if run_active and not get_tree().paused:
		run_time += delta


# --------------------------------------------------------------------------
# Scene flow
# --------------------------------------------------------------------------

func start_run() -> void:
	run_active = true
	in_tutorial = false
	run_scrap_collected = 0
	rooms_cleared = 0
	run_time = 0.0
	run_kills = 0
	run_best_combo = 0
	run_boss_defeated = false
	run_damage_taken = 0.0
	PlayerData.reset_for_run()
	_last_health = PlayerData.current_health
	run_started.emit()
	pending_message = "Depth %d  -  Find the exit teleporter!" % get_depth()
	if get_depth_level() > 0:
		pending_message += "\nThe tombs grow deadlier..."
	change_scene(DUNGEON_SCENE)


## Ends the current run. Success pays a bonus and goes one level deeper; failure loses part of
## the scrap found this run. Either way a score summary is prepared for the garage.
func end_run(success: bool, return_to_garage: bool = true) -> void:
	if run_active:
		ComboTracker.bank()
		run_active = false
		var lost := 0
		if success:
			PlayerData.add_scrap(run_success_bonus)
			run_scrap_collected += run_success_bonus
			pending_message = "Run complete! +%d scrap" % run_scrap_collected
		else:
			lost = mini(int(run_scrap_collected * death_scrap_penalty), PlayerData.scrap_currency)
			PlayerData.spend_scrap(lost)
			pending_message = "Wrecked! Lost %d scrap." % lost
		last_run_summary = _build_summary(success, lost)
		if success:
			PlayerData.runs_completed += 1
		run_ended.emit(success)
		PlayerData.save_game()
	if return_to_garage:
		go_to_garage()


func consume_run_summary() -> Dictionary:
	var summary := last_run_summary
	last_run_summary = {}
	return summary


func _build_summary(success: bool, scrap_lost: int) -> Dictionary:
	var depth := get_depth()
	var score := run_scrap_collected * 10 + run_kills * 25 + rooms_cleared * 100 + run_best_combo * 150
	if run_boss_defeated:
		score += 2000
	if success:
		# Faster runs score more; deeper runs are worth more.
		score += maxi(0, int((600.0 - run_time) * 3.0))
		score = int(score * (1.0 + 0.25 * (depth - 1)))
	var new_best := score > PlayerData.best_score
	if new_best:
		PlayerData.best_score = score
	return {
		"success": success, "depth": depth, "time": run_time, "scrap": run_scrap_collected, "scrap_lost": scrap_lost,
		"kills": run_kills, "rooms": rooms_cleared, "best_combo": run_best_combo, "boss": run_boss_defeated,
		"damage": run_damage_taken, "score": score, "new_best": new_best, "best_score": PlayerData.best_score,
	}


# --------------------------------------------------------------------------
# Depth (difficulty) scaling
# --------------------------------------------------------------------------

## 0 on the first run; +1 for every successful run.
func get_depth_level() -> int:
	return PlayerData.runs_completed


## Shown to the player: Depth 1, 2, 3...
func get_depth() -> int:
	return get_depth_level() + 1


func enemy_health_multiplier() -> float:
	return 1.0 + health_per_depth * get_depth_level()


func enemy_damage_multiplier() -> float:
	return 1.0 + damage_per_depth * get_depth_level()


func enemy_speed_multiplier() -> float:
	return 1.0 + minf(speed_per_depth * get_depth_level(), max_speed_bonus)


func enemy_fire_cooldown_multiplier() -> float:
	return maxf(1.0 - fire_rate_per_depth * get_depth_level(), min_fire_cooldown_factor)


func extra_enemies_per_wave() -> int:
	return mini(get_depth_level() / 2, max_extra_enemies_per_wave)


func scrap_multiplier() -> float:
	return 1.0 + scrap_per_depth * get_depth_level()


func set_room_grid(origin: Vector3, cell_size: float) -> void:
	_room_grid_origin = origin
	_room_grid_size = cell_size


## True when both points are in the same dungeon room. Outside a generated dungeon (garage,
## tutorial, test scenes) it falls back to "within 80 m".
func same_room(a: Vector3, b: Vector3) -> bool:
	if _room_grid_size <= 0.0:
		return a.distance_to(b) <= 80.0
	return _room_cell(a) == _room_cell(b)


func _room_cell(point: Vector3) -> Vector2i:
	var local := point - _room_grid_origin
	return Vector2i(roundi(local.x / _room_grid_size), roundi(local.z / _room_grid_size))


## Picks which boss guards this run's exit: random, but never the same one twice in a row.
func pick_boss_index(count: int) -> int:
	if count <= 1:
		return 0
	var index := randi_range(0, count - 1)
	while index == _last_boss_index:
		index = randi_range(0, count - 1)
	_last_boss_index = index
	return index


func go_to_garage() -> void:
	in_tutorial = false
	PlayerData.heal_full()
	change_scene(GARAGE_SCENE)


func go_to_main_menu() -> void:
	if run_active:
		end_run(false, false)
	in_tutorial = false
	PlayerData.save_game()
	change_scene(MAIN_MENU_SCENE)


func start_tutorial() -> void:
	run_active = false
	in_tutorial = true
	PlayerData.reset_for_run()
	change_scene(TUTORIAL_SCENE)


func complete_tutorial() -> void:
	PlayerData.tutorial_completed = true
	PlayerData.save_game()
	pending_message = "Tutorial complete! Welcome to the Garage."
	go_to_garage()


func change_scene(path: String) -> void:
	if not ResourceLoader.exists(path):
		push_error("GameManager: scene '%s' not found. Update the path constants in GameManager.gd." % path)
		return
	get_tree().paused = false
	_room_grid_size = 0.0
	get_tree().change_scene_to_file.call_deferred(path)


func quit_game() -> void:
	PlayerData.save_game()
	get_tree().quit()


# --------------------------------------------------------------------------
# Run bookkeeping
# --------------------------------------------------------------------------

func add_run_scrap(amount: int) -> void:
	PlayerData.add_scrap(amount)
	if run_active:
		run_scrap_collected += amount


func register_room_cleared() -> void:
	rooms_cleared += 1
	rooms_cleared_changed.emit(rooms_cleared)


func register_kill() -> void:
	if run_active:
		run_kills += 1


func register_combo(multiplier: int) -> void:
	if run_active:
		run_best_combo = maxi(run_best_combo, multiplier)


func register_boss_defeated() -> void:
	if run_active:
		run_boss_defeated = true


func _on_health_changed(current: float, _maximum: float) -> void:
	if run_active and current < _last_health:
		run_damage_taken += _last_health - current
	_last_health = current


func _on_player_died() -> void:
	show_message("WRECKED!", death_return_delay)
	get_tree().create_timer(death_return_delay, false).timeout.connect(_after_death)


func _after_death() -> void:
	if in_tutorial:
		PlayerData.reset_for_run()
		change_scene(TUTORIAL_SCENE)
	elif run_active:
		end_run(false)
	else:
		PlayerData.heal_full()
		get_tree().reload_current_scene.call_deferred()


# --------------------------------------------------------------------------
# Messages / shared helpers
# --------------------------------------------------------------------------

func show_message(text: String, duration: float = 2.5) -> void:
	message_requested.emit(text, duration)


func consume_pending_message() -> String:
	var message := pending_message
	pending_message = ""
	return message


## Plays a sound at a world position on a temporary player that frees itself.
func play_sfx_3d(stream: AudioStream, position: Vector3, volume_db: float = 0.0) -> void:
	if stream == null:
		return
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.bus = get_sfx_bus()
	scene_root.add_child(player)
	player.global_position = position
	player.finished.connect(player.queue_free)
	player.play()


## Instantiates an effect scene (particles, decals...) at a world position.
func spawn_effect(effect_scene: PackedScene, position: Vector3) -> Node3D:
	if effect_scene == null:
		return null
	var scene_root := get_tree().current_scene
	if scene_root == null:
		return null
	var effect := effect_scene.instantiate() as Node3D
	if effect == null:
		return null
	scene_root.add_child(effect)
	effect.global_position = position
	return effect


func get_sfx_bus() -> StringName:
	return &"SFX" if AudioServer.get_bus_index("SFX") != -1 else &"Master"


# --------------------------------------------------------------------------
# Default input map (only added if the action isn't already in Project Settings)
# --------------------------------------------------------------------------

func _register_default_inputs() -> void:
	_add_action("accelerate", [KEY_W, KEY_UP], [], [], [[JOY_AXIS_TRIGGER_RIGHT, 1.0]])
	_add_action("brake", [KEY_S, KEY_DOWN], [], [], [[JOY_AXIS_TRIGGER_LEFT, 1.0]])
	_add_action("steer_left", [KEY_A, KEY_LEFT], [], [], [[JOY_AXIS_LEFT_X, -1.0]])
	_add_action("steer_right", [KEY_D, KEY_RIGHT], [], [], [[JOY_AXIS_LEFT_X, 1.0]])
	_add_action("drift", [KEY_SPACE], [], [JOY_BUTTON_A])
	_add_action("boost", [KEY_SHIFT], [], [JOY_BUTTON_X])
	_add_action("fire_rocket", [KEY_E], [MOUSE_BUTTON_RIGHT], [JOY_BUTTON_RIGHT_SHOULDER])
	_add_action("interact", [KEY_F], [], [JOY_BUTTON_Y])
	_add_action("toggle_shop", [KEY_TAB], [], [JOY_BUTTON_BACK])
	_add_action("pause", [KEY_ESCAPE, KEY_P], [], [JOY_BUTTON_START])


func _add_action(action: StringName, keys: Array, mouse_buttons: Array = [], joy_buttons: Array = [], joy_axes: Array = []) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.25)
	for key in keys:
		var key_event := InputEventKey.new()
		key_event.physical_keycode = key
		InputMap.action_add_event(action, key_event)
	for button in mouse_buttons:
		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = button
		InputMap.action_add_event(action, mouse_event)
	for button in joy_buttons:
		var joy_event := InputEventJoypadButton.new()
		joy_event.button_index = button
		InputMap.action_add_event(action, joy_event)
	for axis_pair in joy_axes:
		var motion_event := InputEventJoypadMotion.new()
		motion_event.axis = axis_pair[0]
		motion_event.axis_value = axis_pair[1]
		InputMap.action_add_event(action, motion_event)
