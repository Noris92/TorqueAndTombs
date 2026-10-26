class_name ShopUI
extends Control
## Garage shop. Builds one tab per UpgradeResource.Category (Weapons, Engines, Armor, Tires)
## with a row per upgrade: icon, name, description, effect, tier and a Buy button.
## Upgrades come from the `upgrades` array plus every .tres in `upgrades_folder`.

signal opened
signal closed
signal item_purchased(item: UpgradeResource)

@export var upgrades: Array[UpgradeResource] = []
@export_dir var upgrades_folder: String = "res://data/upgrades"
@export var tab_container: TabContainer
@export var scrap_label: Label
@export var feedback_label: Label
@export var close_button: Button
@export var pause_game_while_open: bool = true
@export var icon_size: int = 56
@export var ui_audio_player: AudioStreamPlayer
@export var purchase_sound: AudioStream
@export var error_sound: AudioStream

var is_open: bool = false
var _rows: Dictionary = {}  # upgrade id -> {"button": Button, "tier_label": Label}
var _feedback_tween: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	_load_upgrades_from_folder()
	_build_tabs()
	PlayerData.scrap_changed.connect(_on_scrap_changed)
	if close_button != null:
		close_button.pressed.connect(close)
	if feedback_label != null:
		feedback_label.modulate.a = 0.0
	_refresh_all()


func open() -> void:
	if is_open:
		return
	is_open = true
	_refresh_all()
	show()
	if pause_game_while_open:
		get_tree().paused = true
	_focus_first_button()
	opened.emit()


func close() -> void:
	if not is_open:
		return
	is_open = false
	hide()
	if pause_game_while_open:
		get_tree().paused = false
	closed.emit()


func toggle() -> void:
	if is_open:
		close()
	else:
		open()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("toggle_shop") or event.is_action_pressed("pause"):
		close()
		get_viewport().set_input_as_handled()


# --------------------------------------------------------------------------
# Building the UI
# --------------------------------------------------------------------------

func _load_upgrades_from_folder() -> void:
	if upgrades_folder == "":
		return
	var dir := DirAccess.open(upgrades_folder)
	if dir == null:
		return
	for file_name in dir.get_files():
		# Exported builds list "name.tres.remap".
		var clean_name := file_name.trim_suffix(".remap")
		if not (clean_name.ends_with(".tres") or clean_name.ends_with(".res")):
			continue
		var resource := load(upgrades_folder.path_join(clean_name))
		if resource is UpgradeResource and not upgrades.has(resource):
			upgrades.append(resource)


func _build_tabs() -> void:
	if tab_container == null:
		push_error("ShopUI: assign tab_container.")
		return
	for child in tab_container.get_children():
		tab_container.remove_child(child)
		child.queue_free()
	_rows.clear()

	var seen_ids: Dictionary = {}
	var category_names: Array = UpgradeResource.Category.keys()
	for category_index in category_names.size():
		var scroll := ScrollContainer.new()
		scroll.name = String(category_names[category_index]).capitalize()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		var list := VBoxContainer.new()
		list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		list.add_theme_constant_override("separation", 8)
		scroll.add_child(list)
		tab_container.add_child(scroll)

		var items := _get_items_in_category(category_index)
		if items.is_empty():
			var empty_label := Label.new()
			empty_label.text = "Nothing for sale here yet."
			list.add_child(empty_label)
		for item in items:
			if seen_ids.has(item.get_id()):
				push_warning("ShopUI: duplicate upgrade id '%s'." % item.get_id())
				continue
			seen_ids[item.get_id()] = true
			list.add_child(_create_row(item))


func _get_items_in_category(category_index: int) -> Array[UpgradeResource]:
	var items: Array[UpgradeResource] = []
	for item in upgrades:
		if item != null and int(item.category) == category_index:
			items.append(item)
	items.sort_custom(func(a: UpgradeResource, b: UpgradeResource) -> bool: return a.base_cost < b.base_cost)
	return items


func _create_row(item: UpgradeResource) -> Control:
	var panel := PanelContainer.new()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	panel.add_child(row)

	var icon := TextureRect.new()
	icon.texture = item.icon
	icon.custom_minimum_size = Vector2(icon_size, icon_size)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info)

	var name_label := Label.new()
	name_label.text = item.display_name
	info.add_child(name_label)

	if item.description != "":
		var description_label := Label.new()
		description_label.text = item.description
		description_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description_label.custom_minimum_size = Vector2(220.0, 0.0)
		description_label.modulate = Color(1.0, 1.0, 1.0, 0.75)
		info.add_child(description_label)

	var effect_text := item.get_effect_text()
	if effect_text != "":
		var effect_label := Label.new()
		effect_label.text = effect_text
		effect_label.modulate = Color(0.6, 1.0, 0.6)
		info.add_child(effect_label)

	var tier_label := Label.new()
	info.add_child(tier_label)

	var buy_button := Button.new()
	buy_button.custom_minimum_size = Vector2(160.0, 44.0)
	buy_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	buy_button.pressed.connect(_on_buy_pressed.bind(item))
	row.add_child(buy_button)

	_rows[item.get_id()] = {"button": buy_button, "tier_label": tier_label}
	return panel


# --------------------------------------------------------------------------
# State
# --------------------------------------------------------------------------

func _refresh_all() -> void:
	for item in upgrades:
		if item != null:
			_refresh_row(item)
	if scrap_label != null:
		scrap_label.text = "Scrap: %d" % PlayerData.scrap_currency


func _refresh_row(item: UpgradeResource) -> void:
	var controls: Dictionary = _rows.get(item.get_id(), {})
	if controls.is_empty():
		return
	var button: Button = controls["button"]
	var tier_label: Label = controls["tier_label"]
	var tier := PlayerData.get_upgrade_tier(item.get_id())
	tier_label.text = "Tier %d / %d" % [tier, item.max_tier]
	if PlayerData.is_upgrade_maxed(item):
		button.text = "MAXED"
		button.disabled = true
		button.modulate = Color.WHITE
		return
	var cost := PlayerData.get_upgrade_cost(item)
	button.text = "Buy  -  %d scrap" % cost
	button.disabled = false
	button.modulate = Color.WHITE if PlayerData.can_afford(cost) else Color(1.0, 0.55, 0.55)


func _on_buy_pressed(item: UpgradeResource) -> void:
	var reason := PlayerData.get_purchase_block_reason(item)
	if reason != "":
		_show_feedback(reason, true)
		_play(error_sound)
		return
	if PlayerData.apply_upgrade(item):
		_show_feedback("Installed %s!" % item.display_name, false)
		_play(purchase_sound)
		item_purchased.emit(item)
	_refresh_all()


func _on_scrap_changed(_amount: int) -> void:
	_refresh_all()


func _show_feedback(text: String, is_error: bool) -> void:
	if feedback_label == null:
		return
	feedback_label.text = text
	feedback_label.modulate = Color(1.0, 0.45, 0.45, 1.0) if is_error else Color(0.6, 1.0, 0.6, 1.0)
	if _feedback_tween != null:
		_feedback_tween.kill()
	_feedback_tween = create_tween()
	_feedback_tween.tween_interval(1.5)
	_feedback_tween.tween_property(feedback_label, "modulate:a", 0.0, 0.5)


func _focus_first_button() -> void:
	for controls in _rows.values():
		var button: Button = controls["button"]
		if button.is_visible_in_tree() and not button.disabled:
			button.grab_focus()
			return
	if close_button != null:
		close_button.grab_focus()


func _play(stream: AudioStream) -> void:
	if ui_audio_player != null and stream != null:
		ui_audio_player.stream = stream
		ui_audio_player.play()
