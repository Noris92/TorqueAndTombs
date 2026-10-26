extends Node
## Autoload singleton "PlayerData".
## Holds persistent vehicle stats, upgrade tiers, unlocked weapons, scrap currency and save/load.
## Register in Project Settings > Globals > Autoload as "PlayerData" (above GameManager).

signal stats_changed
signal health_changed(current: float, maximum: float)
signal scrap_changed(amount: int)
signal player_died
signal upgrade_purchased(item: UpgradeResource)

const SAVE_PATH: String = "user://torque_tombs_save.json"
const SAVE_VERSION: int = 1

## Base values before upgrades. Every key must match a stat variable below.
const BASE_STATS: Dictionary = {
	"max_health": 100.0,
	"armor": 0.0,
	"acceleration": 28.0,
	"top_speed": 22.0,
	"friction": 10.0,
	"grip": 12.0,
	"drift_factor": 0.7,
	"boost_capacity": 100.0,
	"weapon_damage_multiplier": 1.0,
	"fire_rate_multiplier": 1.0,
	"magnet_range": 7.0,
}

# --- Runtime stats: (base + flat modifiers) * (1 + percent modifiers) ---
var max_health: float = 100.0
var current_health: float = 100.0
## Damage taken is multiplied by 100 / (100 + armor).
var armor: float = 0.0
var acceleration: float = 28.0
var top_speed: float = 22.0
## Rolling deceleration when not on the throttle.
var friction: float = 10.0
## How fast sideways sliding is cancelled while driving normally.
var grip: float = 12.0
## Fraction of grip removed while drifting (0 = no slide, 0.98 = ice).
var drift_factor: float = 0.7
var boost_capacity: float = 100.0
var weapon_damage_multiplier: float = 1.0
var fire_rate_multiplier: float = 1.0
## Scrap within this many metres flies to the buggy (Scrap Magnet upgrade raises it).
var magnet_range: float = 7.0

var scrap_currency: int = 0
var tutorial_completed: bool = false
## Successful runs so far; this is the "depth" that makes enemies tougher.
var runs_completed: int = 0
var best_score: int = 0

## upgrade id -> purchased tier
var purchased_tiers: Dictionary = {}
## weapon slot name -> WeaponResource path
var equipped_weapons: Dictionary = {}
## mount point name -> PackedScene path
var attached_visuals: Dictionary = {}
## Feature unlocks bought in the shop (e.g. "rocket_mouse_aim") -> true
var unlocked_flags: Dictionary = {}

var _flat_modifiers: Dictionary = {}
var _percent_modifiers: Dictionary = {}


func _ready() -> void:
	load_game()
	recalculate_stats()
	heal_full()


# --------------------------------------------------------------------------
# Stats
# --------------------------------------------------------------------------

func recalculate_stats() -> void:
	for stat_name in BASE_STATS:
		var base_value: float = BASE_STATS[stat_name]
		var flat: float = _flat_modifiers.get(stat_name, 0.0)
		var percent: float = _percent_modifiers.get(stat_name, 0.0)
		set(stat_name, (base_value + flat) * (1.0 + percent))
	drift_factor = clampf(drift_factor, 0.0, 0.98)
	current_health = minf(current_health, max_health)
	stats_changed.emit()
	health_changed.emit(current_health, max_health)


func get_stat(stat_name: String) -> float:
	return float(get(stat_name))


func add_stat_modifier(stat_name: String, value: float, is_percent: bool) -> void:
	if not BASE_STATS.has(stat_name):
		push_warning("PlayerData: unknown stat '%s'." % stat_name)
		return
	var target: Dictionary = _percent_modifiers if is_percent else _flat_modifiers
	target[stat_name] = float(target.get(stat_name, 0.0)) + value
	recalculate_stats()


# --------------------------------------------------------------------------
# Health
# --------------------------------------------------------------------------

## Applies armor and returns the damage actually taken.
func take_damage(amount: float) -> float:
	if current_health <= 0.0 or amount <= 0.0:
		return 0.0
	var reduced: float = amount * (100.0 / (100.0 + maxf(armor, 0.0)))
	current_health = maxf(current_health - reduced, 0.0)
	health_changed.emit(current_health, max_health)
	if current_health <= 0.0:
		player_died.emit()
	return reduced


func heal(amount: float) -> void:
	if current_health <= 0.0:
		return
	current_health = minf(current_health + amount, max_health)
	health_changed.emit(current_health, max_health)


func heal_full() -> void:
	current_health = max_health
	health_changed.emit(current_health, max_health)


func is_dead() -> bool:
	return current_health <= 0.0


func reset_for_run() -> void:
	heal_full()


# --------------------------------------------------------------------------
# Scrap
# --------------------------------------------------------------------------

func add_scrap(amount: int) -> void:
	if amount == 0:
		return
	scrap_currency = maxi(scrap_currency + amount, 0)
	scrap_changed.emit(scrap_currency)


func can_afford(cost: int) -> bool:
	return scrap_currency >= cost


func spend_scrap(amount: int) -> bool:
	if amount <= 0:
		return true
	if not can_afford(amount):
		return false
	scrap_currency -= amount
	scrap_changed.emit(scrap_currency)
	return true


# --------------------------------------------------------------------------
# Upgrades
# --------------------------------------------------------------------------

func get_upgrade_tier(upgrade_id: String) -> int:
	return int(purchased_tiers.get(upgrade_id, 0))


func get_upgrade_cost(item: UpgradeResource) -> int:
	return item.get_cost(get_upgrade_tier(item.get_id()))


func is_upgrade_maxed(item: UpgradeResource) -> bool:
	return get_upgrade_tier(item.get_id()) >= item.max_tier


## Returns "" when the item can be bought, otherwise a short reason for the UI.
func get_purchase_block_reason(item: UpgradeResource) -> String:
	if item == null:
		return "Invalid item"
	if is_upgrade_maxed(item):
		return "Already maxed"
	if not can_afford(get_upgrade_cost(item)):
		return "Not enough scrap"
	return ""


func apply_upgrade(item: UpgradeResource) -> bool:
	if get_purchase_block_reason(item) != "":
		return false
	spend_scrap(get_upgrade_cost(item))
	purchased_tiers[item.get_id()] = get_upgrade_tier(item.get_id()) + 1

	if item.has_stat_modifier():
		var previous_max_health: float = max_health
		add_stat_modifier(item.target_stat, item.modifier_value, item.modifier_mode == UpgradeResource.ModifierMode.PERCENT)
		if max_health > previous_max_health:
			heal(max_health - previous_max_health)
	if item.weapon_unlock != null:
		if item.weapon_unlock.resource_path.contains("::"):
			push_warning("PlayerData: '%s' embeds its weapon; save the WeaponResource as its own .tres so it persists between scenes." % item.get_id())
		equipped_weapons[item.weapon_slot] = item.weapon_unlock.resource_path
	if item.visual_scene != null:
		attached_visuals[item.visual_attach_point] = item.visual_scene.resource_path
	if item.unlock_flag != "":
		unlocked_flags[item.unlock_flag] = true

	upgrade_purchased.emit(item)
	save_game()
	return true


# --------------------------------------------------------------------------
# Save / Load
# --------------------------------------------------------------------------

func save_game() -> void:
	var data: Dictionary = {
		"version": SAVE_VERSION,
		"scrap": scrap_currency,
		"tutorial_completed": tutorial_completed,
		"tiers": purchased_tiers,
		"flat_modifiers": _flat_modifiers,
		"percent_modifiers": _percent_modifiers,
		"equipped_weapons": equipped_weapons,
		"attached_visuals": attached_visuals,
		"unlocked_flags": unlocked_flags,
		"runs_completed": runs_completed,
		"best_score": best_score,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("PlayerData: could not save (%s)." % error_string(FileAccess.get_open_error()))
		return
	file.store_string(JSON.stringify(data, "\t"))


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("PlayerData: save file is corrupt, starting fresh.")
		return false
	var data: Dictionary = parsed
	scrap_currency = int(data.get("scrap", 0))
	tutorial_completed = bool(data.get("tutorial_completed", false))
	purchased_tiers = _as_dictionary(data.get("tiers"))
	_flat_modifiers = _as_dictionary(data.get("flat_modifiers"))
	_percent_modifiers = _as_dictionary(data.get("percent_modifiers"))
	equipped_weapons = _as_dictionary(data.get("equipped_weapons"))
	attached_visuals = _as_dictionary(data.get("attached_visuals"))
	unlocked_flags = _as_dictionary(data.get("unlocked_flags"))
	runs_completed = int(data.get("runs_completed", 0))
	best_score = int(data.get("best_score", 0))
	_repair_weapon_paths()
	recalculate_stats()
	scrap_changed.emit(scrap_currency)
	return true


func reset_save() -> void:
	scrap_currency = 0
	tutorial_completed = false
	purchased_tiers.clear()
	_flat_modifiers.clear()
	_percent_modifiers.clear()
	equipped_weapons.clear()
	attached_visuals.clear()
	unlocked_flags.clear()
	runs_completed = 0
	best_score = 0
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	recalculate_stats()
	heal_full()
	scrap_changed.emit(scrap_currency)


func has_flag(flag: String) -> bool:
	return bool(unlocked_flags.get(flag, false))


## Older saves stored weapons embedded inside upgrade files ("upgrade.tres::Resource_x"), which
## can't be loaded after the shop closes. Point them at the upgrade's real weapon file instead.
func _repair_weapon_paths() -> void:
	for slot in equipped_weapons.keys():
		var path := String(equipped_weapons[slot])
		if not path.contains("::"):
			continue
		var upgrade_path := path.get_slice("::", 0)
		var upgrade: UpgradeResource = null
		if ResourceLoader.exists(upgrade_path):
			upgrade = load(upgrade_path) as UpgradeResource
		if upgrade != null and upgrade.weapon_unlock != null and not upgrade.weapon_unlock.resource_path.contains("::"):
			equipped_weapons[slot] = upgrade.weapon_unlock.resource_path
		else:
			equipped_weapons.erase(slot)


func _as_dictionary(value: Variant) -> Dictionary:
	if typeof(value) == TYPE_DICTIONARY:
		return value
	return {}
