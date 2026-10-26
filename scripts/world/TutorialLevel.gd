extends Node3D
## Hand-built tutorial. Zones A-E teach one mechanic each; gates open as objectives are met.
##   A: Drive & drift through the S-curves (one drift >= required_drift_time opens drift_gate;
##      the gate is also the only way on, so the S-curves are the place to practise)
##   B: Hit the boost pad to clear the lava ramp (reaching zone C's trigger completes it)
##   C: Break every crate under crates_root (opens crate_gate)
##   D: Destroy every dummy under dummies_root with the auto-turret (opens target_gate, wakes teleporter)
##   E: Drive into the teleporter (destination TUTORIAL_COMPLETE) to reach the Garage

enum Step { DRIFT, BOOST_JUMP, CRATES, TARGETS, TELEPORT }

@export var player_spawn: Marker3D
@export var player_scene: PackedScene

@export_group("Zone Triggers")
@export var zone_a_trigger: Area3D
@export var zone_b_trigger: Area3D
@export var zone_c_trigger: Area3D
@export var zone_d_trigger: Area3D
@export var zone_e_trigger: Area3D

@export_group("Objectives")
## Start these doors locked (start_locked = true).
@export var drift_gate: Door
@export var crate_gate: Door
@export var target_gate: Door
@export var crates_root: Node3D
@export var dummies_root: Node3D
@export var teleporter: Teleporter
@export var required_drift_time: float = 0.6

@export_group("Messages")
@export_multiline var message_zone_a: String = "ZONE A: W/S to drive, A/D to steer. Hold SPACE while turning to DRIFT. Let go after a long drift for a speed boost!"
@export_multiline var message_drift_done: String = "Nice drift! The gate is open."
@export_multiline var message_zone_b: String = "ZONE B: Hit the BOOST PAD to clear the lava. Hold SHIFT for nitro. In the air, W/S tilt the nose: land level for a clean landing."
@export_multiline var message_zone_c: String = "ZONE C: Smash crates by ramming them or firing rockets (E / Right Mouse). Scrap is your currency!"
@export_multiline var message_crates_done: String = "All crates smashed!"
@export_multiline var message_zone_d: String = "ZONE D: Your roof turret aims and fires on its own. Get close to the training dummies!"
@export_multiline var message_targets_done: String = "Targets destroyed! The teleporter is online."
@export_multiline var message_zone_e: String = "ZONE E: Drive into the teleporter to reach your Garage."

var step: Step = Step.DRIFT
var _crates_left: int = 0
var _dummies_left: int = 0
var _zones_announced: Dictionary = {}
var _player: PlayerVehicle


func _ready() -> void:
	GameManager.in_tutorial = true
	GameManager.run_active = false
	for gate in [drift_gate, crate_gate, target_gate]:
		if gate != null:
			(gate as Door).lock()
	if teleporter != null:
		teleporter.destination = Teleporter.Destination.TUTORIAL_COMPLETE
		teleporter.deactivate()

	if crates_root != null:
		for child in crates_root.get_children():
			if child is LootCrate:
				_crates_left += 1
				(child as LootCrate).broken.connect(_on_crate_broken)
	if dummies_root != null:
		for child in dummies_root.get_children():
			if child.has_signal("died"):
				_dummies_left += 1
				child.connect("died", _on_dummy_destroyed)

	_connect_zone(zone_a_trigger, "A")
	_connect_zone(zone_b_trigger, "B")
	_connect_zone(zone_c_trigger, "C")
	_connect_zone(zone_d_trigger, "D")
	_connect_zone(zone_e_trigger, "E")
	_setup_player.call_deferred()


func _setup_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as PlayerVehicle
	if _player == null and player_scene != null:
		_player = player_scene.instantiate() as PlayerVehicle
		add_child(_player)
	if _player == null:
		push_warning("TutorialLevel: no player in the scene and no player_scene assigned.")
		return
	if player_spawn != null:
		_player.teleport_to(player_spawn.global_transform)
	_player.drift_ended.connect(_on_drift_ended)
	_announce("A", message_zone_a)
	if _crates_left == 0:
		_unlock(crate_gate)
	if _dummies_left == 0:
		_on_all_dummies_destroyed()


func _connect_zone(trigger: Area3D, zone: String) -> void:
	if trigger != null:
		trigger.body_entered.connect(_on_zone_entered.bind(zone))


func _on_zone_entered(body: Node3D, zone: String) -> void:
	if not body.is_in_group("player"):
		return
	match zone:
		"A":
			_announce(zone, message_zone_a)
		"B":
			_announce(zone, message_zone_b)
		"C":
			if step == Step.BOOST_JUMP:
				step = Step.CRATES
			_announce(zone, message_zone_c)
		"D":
			if step == Step.CRATES:
				step = Step.TARGETS
			_announce(zone, message_zone_d)
		"E":
			_announce(zone, message_zone_e)


func _announce(zone: String, text: String) -> void:
	if _zones_announced.has(zone) or text == "":
		return
	_zones_announced[zone] = true
	GameManager.show_message(text, 6.0)


func _on_drift_ended(duration: float, _boosted: bool) -> void:
	if step != Step.DRIFT or duration < required_drift_time:
		return
	step = Step.BOOST_JUMP
	_unlock(drift_gate)
	GameManager.show_message(message_drift_done)


func _on_crate_broken(_crate: LootCrate) -> void:
	_crates_left -= 1
	if _crates_left <= 0:
		_unlock(crate_gate)
		GameManager.show_message(message_crates_done)


func _on_dummy_destroyed(_dummy: Node) -> void:
	_dummies_left -= 1
	if _dummies_left <= 0:
		_on_all_dummies_destroyed()


func _on_all_dummies_destroyed() -> void:
	step = Step.TELEPORT
	_unlock(target_gate)
	if teleporter != null:
		teleporter.activate()
	GameManager.show_message(message_targets_done)


func _unlock(gate: Door) -> void:
	if gate != null:
		gate.unlock()
