class_name WeaponMount
extends Node3D
## Base for anything that fires a WeaponResource: cooldown, PlayerData damage/fire-rate
## multipliers, spread, muzzle flash, sound, weapon swaps bought in the shop and the weapon model.
## Use TurretController or RocketLauncher on actual nodes.

signal fired(weapon: WeaponResource)
signal weapon_changed(weapon: WeaponResource)

@export var weapon: WeaponResource
## Key in PlayerData.equipped_weapons ("turret", "rocket"...). Shop weapon unlocks for this
## slot replace `weapon`. Leave empty for mounts that should never change.
@export var slot_name: String = ""
## Projectiles spawn here travelling along its -Z. Defaults to the child named "Muzzle".
@export var muzzle: Marker3D
@export var muzzle_flash: GPUParticles3D
@export var audio_player: AudioStreamPlayer3D
## Apply PlayerData.weapon_damage_multiplier / fire_rate_multiplier.
@export var use_player_stats: bool = true

var _cooldown: float = 0.0
var _owner_body: CollisionObject3D
var _weapon_model: Node3D


func _ready() -> void:
	if muzzle == null:
		muzzle = get_node_or_null("Muzzle") as Marker3D
	_owner_body = _find_owner_body()
	refresh_weapon()


func _physics_process(delta: float) -> void:
	_cooldown = maxf(_cooldown - delta, 0.0)


func refresh_weapon() -> void:
	if slot_name != "" and PlayerData.equipped_weapons.has(slot_name):
		var path := String(PlayerData.equipped_weapons[slot_name])
		if ResourceLoader.exists(path):
			var unlocked := load(path) as WeaponResource
			if unlocked != null:
				weapon = unlocked
	_update_weapon_model()
	weapon_changed.emit(weapon)


func can_fire() -> bool:
	return weapon != null and weapon.projectile_scene != null and _cooldown <= 0.0


func get_damage() -> float:
	var multiplier: float = PlayerData.weapon_damage_multiplier if use_player_stats else 1.0
	return weapon.damage * multiplier


func get_fire_interval() -> float:
	var multiplier: float = PlayerData.fire_rate_multiplier if use_player_stats else 1.0
	return 1.0 / maxf(weapon.fire_rate * multiplier, 0.01)


## Fires along `direction` (or the muzzle's -Z when zero). Returns false while on cooldown.
func fire(direction: Vector3 = Vector3.ZERO) -> bool:
	if not can_fire():
		return false
	_cooldown = get_fire_interval()
	var origin: Transform3D = muzzle.global_transform if muzzle != null else global_transform
	var base_direction := direction.normalized() if direction != Vector3.ZERO else -origin.basis.z.normalized()
	var parent: Node = get_tree().current_scene if get_tree().current_scene != null else get_tree().root

	for _i in maxi(weapon.projectiles_per_shot, 1):
		var projectile := weapon.projectile_scene.instantiate() as Bullet
		if projectile == null:
			push_warning("WeaponMount: projectile_scene root must use Bullet.gd or Rocket.gd.")
			return false
		parent.add_child(projectile)
		projectile.global_position = origin.origin
		var spread := deg_to_rad(randf_range(-weapon.spread_degrees, weapon.spread_degrees))
		projectile.setup(base_direction.rotated(Vector3.UP, spread), weapon.projectile_speed, get_damage(), weapon.projectile_lifetime, weapon.splash_radius, _owner_body)

	if audio_player != null:
		if weapon.fire_sound != null:
			audio_player.stream = weapon.fire_sound
		audio_player.play()
	if muzzle_flash != null:
		muzzle_flash.restart()
	fired.emit(weapon)
	return true


func _update_weapon_model() -> void:
	if _weapon_model != null:
		_weapon_model.queue_free()
		_weapon_model = null
	if weapon != null and weapon.model_scene != null:
		_weapon_model = weapon.model_scene.instantiate() as Node3D
		if _weapon_model != null:
			add_child(_weapon_model)


func _find_owner_body() -> CollisionObject3D:
	var node := get_parent()
	while node != null:
		if node is CollisionObject3D:
			return node as CollisionObject3D
		node = node.get_parent()
	return null
