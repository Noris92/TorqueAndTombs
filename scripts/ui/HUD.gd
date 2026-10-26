extends CanvasLayer
## In-game HUD: health, boost, scrap, speed, the style combo meter and centred messages from
## GameManager.show_message().

@export var health_bar: Range
@export var health_label: Label
@export var boost_bar: Range
@export var scrap_label: Label
@export var speed_label: Label
@export var message_label: Label

@export_group("Combo")
## Shown while a combo is running.
@export var combo_panel: Control
@export var combo_label: Label
@export var combo_detail_label: Label
@export var combo_bar: Range

var _player: PlayerVehicle
var _player_search_timer: float = 0.0
var _message_tween: Tween
var _combo_tween: Tween


func _ready() -> void:
	PlayerData.health_changed.connect(_on_health_changed)
	PlayerData.scrap_changed.connect(_on_scrap_changed)
	GameManager.message_requested.connect(show_message)
	ComboTracker.combo_changed.connect(_on_combo_changed)
	ComboTracker.combo_timer_changed.connect(_on_combo_timer_changed)
	ComboTracker.combo_banked.connect(_on_combo_banked)
	ComboTracker.combo_dropped.connect(_on_combo_dropped)
	_on_health_changed(PlayerData.current_health, PlayerData.max_health)
	_on_scrap_changed(PlayerData.scrap_currency)
	if combo_panel != null:
		combo_panel.visible = false
		combo_panel.pivot_offset = combo_panel.size * 0.5
		# A combo can carry over from the previous scene (e.g. through a teleporter).
		if ComboTracker.is_active():
			_on_combo_changed(ComboTracker.multiplier, ComboTracker.points, "Combo running")
	if message_label != null:
		message_label.modulate.a = 0.0
	var pending := GameManager.consume_pending_message()
	if pending != "":
		show_message.call_deferred(pending, 4.0)


func _process(delta: float) -> void:
	if not is_instance_valid(_player):
		_player_search_timer -= delta
		if _player_search_timer <= 0.0:
			_player_search_timer = 0.5
			_connect_player()
		return
	if speed_label != null:
		speed_label.text = "%d km/h" % roundi(_player.get_speed() * 3.6)


func show_message(text: String, duration: float = 2.5) -> void:
	if message_label == null:
		return
	message_label.text = text
	if _message_tween != null:
		_message_tween.kill()
	_message_tween = create_tween()
	_message_tween.tween_property(message_label, "modulate:a", 1.0, 0.15)
	_message_tween.tween_interval(maxf(duration, 0.1))
	_message_tween.tween_property(message_label, "modulate:a", 0.0, 0.4)


func _connect_player() -> void:
	_player = get_tree().get_first_node_in_group("player") as PlayerVehicle
	if _player == null:
		return
	_player.boost_changed.connect(_on_boost_changed)
	_on_boost_changed(_player.boost_meter, PlayerData.boost_capacity)


func _on_health_changed(current: float, maximum: float) -> void:
	if health_bar != null:
		health_bar.max_value = maximum
		health_bar.value = current
	if health_label != null:
		health_label.text = "%d / %d" % [ceili(current), roundi(maximum)]


func _on_boost_changed(current: float, maximum: float) -> void:
	if boost_bar != null:
		boost_bar.max_value = maximum
		boost_bar.value = current


func _on_scrap_changed(amount: int) -> void:
	if scrap_label != null:
		scrap_label.text = "Scrap: %d" % amount


func _on_combo_changed(multiplier: int, _points: float, last_trick: String) -> void:
	if combo_panel == null or multiplier <= 0:
		return
	if _combo_tween != null:
		_combo_tween.kill()
	combo_panel.visible = true
	combo_panel.modulate = Color.WHITE
	if combo_label != null:
		combo_label.text = "x%d COMBO" % multiplier
	if combo_detail_label != null:
		combo_detail_label.text = "%s   +%d scrap" % [last_trick, ComboTracker.get_payout()]
	# Little pop on every new trick.
	combo_panel.scale = Vector2.ONE * 1.15
	_combo_tween = create_tween()
	_combo_tween.tween_property(combo_panel, "scale", Vector2.ONE, 0.15)


func _on_combo_timer_changed(time_left: float, window: float) -> void:
	if combo_bar != null:
		combo_bar.max_value = window
		combo_bar.value = time_left


func _on_combo_banked(scrap: int, multiplier: int) -> void:
	_finish_combo("BANKED  +%d scrap" % scrap, "x%d COMBO" % multiplier, Color(1.0, 0.85, 0.3))


func _on_combo_dropped() -> void:
	_finish_combo("COMBO LOST", "WRECKED", Color(1.0, 0.35, 0.3))


func _finish_combo(detail: String, title: String, color: Color) -> void:
	if combo_panel == null:
		return
	if _combo_tween != null:
		_combo_tween.kill()
	combo_panel.visible = true
	combo_panel.scale = Vector2.ONE
	if combo_label != null:
		combo_label.text = title
	if combo_detail_label != null:
		combo_detail_label.text = detail
	if combo_bar != null:
		combo_bar.value = 0.0
	combo_panel.modulate = color
	_combo_tween = create_tween()
	_combo_tween.tween_interval(1.4)
	_combo_tween.tween_property(combo_panel, "modulate:a", 0.0, 0.5)
	_combo_tween.tween_callback(combo_panel.hide)
