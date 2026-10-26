class_name UpgradeResource
extends Resource
## One item in the Garage shop. Save .tres files in the ShopUI's upgrades_folder
## (default res://data/upgrades) and they appear in the shop automatically.

enum Category { WEAPONS, ENGINES, ARMOR, TIRES, UTILITY }
enum ModifierMode { FLAT, PERCENT }

## Unique key used in the save file. Leave empty to use the file name.
@export var id: String = ""
@export var display_name: String = "New Upgrade"
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var category: Category = Category.ENGINES

@export_group("Stat Modifier")
@export_enum("none", "max_health", "armor", "acceleration", "top_speed", "friction", "grip", "drift_factor", "boost_capacity", "weapon_damage_multiplier", "fire_rate_multiplier", "magnet_range") var target_stat: String = "top_speed"
## FLAT adds this value per tier. PERCENT adds this fraction per tier (0.1 = +10%).
@export var modifier_value: float = 2.0
@export var modifier_mode: ModifierMode = ModifierMode.FLAT

@export_group("Cost")
@export var base_cost: int = 50
@export_range(1, 10) var max_tier: int = 3
@export var cost_multiplier_per_tier: float = 1.5

@export_group("Unlocks")
## Optional weapon that replaces the weapon in `weapon_slot` when bought.
@export var weapon_unlock: WeaponResource
## Matches the slot_name on a TurretController / RocketLauncher ("turret", "rocket").
@export var weapon_slot: String = "turret"
## Optional mesh scene attached to the buggy (in the garage and during runs).
@export var visual_scene: PackedScene
## Name of a Node3D under PlayerVehicle's Mounts node (e.g. "RoofMount", "FrontMount", "SideMounts").
@export var visual_attach_point: String = "RoofMount"
## Optional feature switch stored in PlayerData.unlocked_flags (e.g. "rocket_mouse_aim").
@export var unlock_flag: String = ""
## Shown in the shop for flag unlocks, e.g. "Mouse-aimed rockets".
@export var unlock_label: String = ""


func get_id() -> String:
	if id != "":
		return id
	return resource_path.get_file().get_basename()


func get_cost(current_tier: int) -> int:
	return int(round(base_cost * pow(cost_multiplier_per_tier, current_tier)))


func has_stat_modifier() -> bool:
	return target_stat != "" and target_stat != "none" and not is_zero_approx(modifier_value)


func get_effect_text() -> String:
	var parts: PackedStringArray = []
	if has_stat_modifier():
		var stat_label := target_stat.capitalize()
		if modifier_mode == ModifierMode.PERCENT:
			parts.append("%+d%% %s" % [roundi(modifier_value * 100.0), stat_label])
		elif absf(modifier_value) < 1.0:
			parts.append("%+.2f %s" % [modifier_value, stat_label])
		else:
			parts.append("%+.1f %s" % [modifier_value, stat_label])
	if weapon_unlock != null:
		parts.append("Equips %s" % weapon_unlock.weapon_name)
	if unlock_label != "":
		parts.append("Unlocks: %s" % unlock_label)
	return " | ".join(parts)
