class_name BaseEnemy
extends CharacterBody3D
## Base class for dungeon enemies: health/armor, NavigationAgent3D pathing toward the player,
## knockback, slow, hit flash, scrap drops and the `died` signal WaveSpawner listens for.
## Subclasses override _get_desired_velocity() and optionally _after_move().

signal died(enemy: BaseEnemy)
signal health_changed(current: float, maximum: float)

@export_group("Stats")
@export var max_health: float = 30.0
## Flat damage removed from each hit (a hit always deals at least 20%).
@export var armor: float = 0.0
@export var move_speed: float = 6.0
@export var acceleration: float = 14.0
@export var turn_speed: float = 8.0
@export var scrap_reward: int = 5
@export var contact_damage: float = 10.0

@export_group("Navigation")
@export var path_update_interval: float = 0.25
## Enemies ignore the player beyond this distance.
@export var aggro_range: float = 45.0
## Layers that block line of sight (usually just World).
@export_flags_3d_physics var sight_mask: int = 1

@export_group("Presentation")
## Rotated to face the movement direction. Defaults to the child named "Visual".
@export var visual_root: Node3D
@export var scrap_pickup_scene: PackedScene
@export var death_effect: PackedScene
@export var hit_sound: AudioStream
@export var death_sound: AudioStream
@export var hit_flash_color: Color = Color(1.0, 1.0, 1.0, 0.7)

var current_health: float = 0.0
var target: Node3D
var nav_agent: NavigationAgent3D

var _is_dead: bool = false
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _path_timer: float = 0.0
var _slow_factor: float = 1.0
var _slow_timer: float = 0.0
var _flash_material: StandardMaterial3D
var _flash_meshes: Array[GeometryInstance3D] = []


func _ready() -> void:
	add_to_group("enemies")
	_apply_depth_scaling()
	current_health = max_health
	nav_agent = get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	if visual_root == null:
		visual_root = get_node_or_null("Visual") as Node3D
	_setup_hit_flash()
	# Spread path queries across frames when a whole wave spawns at once.
	_path_timer = randf() * path_update_interval


func _physics_process(delta: float) -> void:
	if _is_dead:
		return
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_factor = 1.0
	_acquire_target()
	_path_timer -= delta
	if _path_timer <= 0.0:
		_path_timer = path_update_interval
		_update_navigation_target()

	var desired := _get_desired_velocity(delta) * _slow_factor
	var horizontal := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3(desired.x, 0.0, desired.z), _get_acceleration() * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()
	_after_move(delta)
	_update_facing(delta)


## During runs, enemies get tougher with every successful run (see GameManager depth scaling).
## Subclasses extend this to scale their own attacks.
func _apply_depth_scaling() -> void:
	if not GameManager.run_active:
		return
	max_health *= GameManager.enemy_health_multiplier()
	contact_damage *= GameManager.enemy_damage_multiplier()
	move_speed *= GameManager.enemy_speed_multiplier()
	scrap_reward = roundi(scrap_reward * GameManager.scrap_multiplier())


# --------------------------------------------------------------------------
# Overridable behaviour
# --------------------------------------------------------------------------

## Return the horizontal velocity this enemy wants this frame.
func _get_desired_velocity(_delta: float) -> Vector3:
	return get_path_velocity()


## Called right after move_and_slide() (check slide collisions here).
func _after_move(_delta: float) -> void:
	pass


func _get_acceleration() -> float:
	return acceleration


func _get_facing_direction() -> Vector3:
	return Vector3(velocity.x, 0.0, velocity.z)


# --------------------------------------------------------------------------
# Navigation helpers
# --------------------------------------------------------------------------

func _acquire_target() -> void:
	if is_instance_valid(target) and target.is_inside_tree():
		return
	target = get_tree().get_first_node_in_group("player") as Node3D


func _update_navigation_target() -> void:
	if nav_agent != null and is_instance_valid(target):
		nav_agent.target_position = target.global_position


## Velocity along the navmesh path toward the player. Falls back to a straight line
## when there is no navmesh, so enemies still work in rooms you haven't baked yet.
func get_path_velocity(speed: float = -1.0) -> Vector3:
	if not is_instance_valid(target) or distance_to_target() > aggro_range:
		return Vector3.ZERO
	var move := move_speed if speed < 0.0 else speed
	var next_point := target.global_position
	if nav_agent != null and not nav_agent.is_navigation_finished():
		next_point = nav_agent.get_next_path_position()
	var direction := next_point - global_position
	direction.y = 0.0
	if direction.length() < 0.1:
		direction = target.global_position - global_position
		direction.y = 0.0
	return direction.normalized() * move


func distance_to_target() -> float:
	if not is_instance_valid(target):
		return INF
	return global_position.distance_to(target.global_position)


func get_flat_direction_to_target() -> Vector3:
	if not is_instance_valid(target):
		return Vector3.ZERO
	var direction := target.global_position - global_position
	direction.y = 0.0
	return direction.normalized()


func has_line_of_sight() -> bool:
	if not is_instance_valid(target):
		return false
	var query := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.8, target.global_position + Vector3.UP * 0.5, sight_mask)
	query.exclude = [get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == target


func _update_facing(delta: float) -> void:
	if visual_root == null:
		return
	var direction := _get_facing_direction()
	if direction.length_squared() < 0.01:
		return
	var yaw := atan2(-direction.x, -direction.z)
	visual_root.rotation.y = lerp_angle(visual_root.rotation.y, yaw, clampf(turn_speed * delta, 0.0, 1.0))


# --------------------------------------------------------------------------
# Damage
# --------------------------------------------------------------------------

func take_damage(amount: float, _source: Node = null) -> void:
	if _is_dead or amount <= 0.0:
		return
	current_health -= maxf(amount - armor, amount * 0.2)
	health_changed.emit(maxf(current_health, 0.0), max_health)
	_flash()
	GameManager.play_sfx_3d(hit_sound, global_position)
	if current_health <= 0.0:
		die()


func die(drop_loot: bool = true) -> void:
	if _is_dead:
		return
	_is_dead = true
	GameManager.spawn_effect(death_effect, global_position)
	GameManager.play_sfx_3d(death_sound, global_position)
	if drop_loot:
		ScrapPickup.spawn_burst(scrap_pickup_scene, get_tree().current_scene, global_position, scrap_reward)
	ComboTracker.register_kill()
	GameManager.register_kill()
	died.emit(self)
	queue_free()


func is_alive() -> bool:
	return not _is_dead


func apply_knockback(impulse: Vector3) -> void:
	velocity += impulse


func apply_slow(factor: float, duration: float) -> void:
	_slow_factor = minf(_slow_factor, clampf(factor, 0.05, 1.0))
	_slow_timer = maxf(_slow_timer, duration)


func _setup_hit_flash() -> void:
	_flash_material = StandardMaterial3D.new()
	_flash_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_flash_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_flash_material.albedo_color = hit_flash_color
	var search_root: Node = visual_root if visual_root != null else self
	for node in search_root.find_children("*", "MeshInstance3D", true, false):
		_flash_meshes.append(node as GeometryInstance3D)


func _flash() -> void:
	for mesh in _flash_meshes:
		if is_instance_valid(mesh):
			mesh.material_overlay = _flash_material
	get_tree().create_timer(0.08, false).timeout.connect(_clear_flash)


func _clear_flash() -> void:
	for mesh in _flash_meshes:
		if is_instance_valid(mesh):
			mesh.material_overlay = null
