extends Node3D
## Garage hub between runs. Park inside the shop zone (or press Tab anywhere / F in the zone)
## to open the shop. Purchases immediately update the buggy's weapons and attached visuals.
## Put a Teleporter set to NEW_RUN somewhere in the garage to start a run.

@export var shop_ui: ShopUI
@export var shop_zone: Area3D
## "Press F / park to open the shop" prompt.
@export var prompt_label: Control
@export var player_spawn: Marker3D
## Spawned if the scene has no node in group "player".
@export var player_scene: PackedScene
@export var park_time_to_open: float = 0.8
@export var park_max_speed: float = 1.5
@export var purchase_effect: PackedScene
## End-of-run score screen, shown when you arrive back from a run.
@export var run_summary: RunSummary

var _player: PlayerVehicle
var _player_in_zone: bool = false
var _park_timer: float = 0.0
## Stops the shop reopening the moment you close it while still parked.
var _auto_open_armed: bool = true


func _ready() -> void:
	PlayerData.heal_full()
	PlayerData.save_game()
	if shop_zone != null:
		shop_zone.body_entered.connect(_on_shop_zone_entered)
		shop_zone.body_exited.connect(_on_shop_zone_exited)
	if shop_ui != null:
		shop_ui.item_purchased.connect(_on_item_purchased)
		shop_ui.closed.connect(_on_shop_closed)
	if prompt_label != null:
		prompt_label.hide()
	var summary := GameManager.consume_run_summary()
	if run_summary != null and not summary.is_empty():
		run_summary.show_summary.call_deferred(summary)
	_setup_player.call_deferred()


func _is_summary_open() -> bool:
	return run_summary != null and run_summary.visible


func _setup_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as PlayerVehicle
	if _player == null and player_scene != null:
		_player = player_scene.instantiate() as PlayerVehicle
		add_child(_player)
	if _player != null and player_spawn != null:
		_player.teleport_to(player_spawn.global_transform)


func _physics_process(delta: float) -> void:
	if _player == null or shop_ui == null or _is_summary_open():
		return
	if prompt_label != null:
		prompt_label.visible = _player_in_zone and not shop_ui.is_open
	if not _player_in_zone or not _auto_open_armed:
		_park_timer = 0.0
		return
	if _player.get_speed() <= park_max_speed:
		_park_timer += delta
		if _park_timer >= park_time_to_open:
			_park_timer = 0.0
			_auto_open_armed = false
			shop_ui.open()
	else:
		_park_timer = 0.0


func _unhandled_input(event: InputEvent) -> void:
	if shop_ui == null or shop_ui.is_open or _is_summary_open():
		return
	if event.is_action_pressed("toggle_shop") or (event.is_action_pressed("interact") and _player_in_zone):
		shop_ui.open()
		get_viewport().set_input_as_handled()


func _on_shop_zone_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in_zone = true


func _on_shop_zone_exited(body: Node3D) -> void:
	if body.is_in_group("player"):
		_player_in_zone = false
		_auto_open_armed = true


func _on_shop_closed() -> void:
	_park_timer = 0.0


func _on_item_purchased(_item: UpgradeResource) -> void:
	if _player != null:
		_player.refresh_attachments()
		GameManager.spawn_effect(purchase_effect, _player.global_position)
