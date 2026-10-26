class_name RangedEnemy
extends BaseEnemy
## Fireball caster / mortar buggy. Keeps its distance, stops when in range, telegraphs the
## shot (a line toward the player, or a shadow on the floor for mortar shells) and fires.

enum AttackState { REPOSITION, AIMING, COOLDOWN }

@export_group("Ranged Attack")
## Scene whose root uses Bullet.gd (fireball) or Rocket.gd (explosive / mortar shell).
@export var projectile_scene: PackedScene
@export var projectile_damage: float = 12.0
@export var projectile_speed: float = 18.0
## 0 = use the Rocket's own default radius (ignored by plain Bullets).
@export var splash_radius: float = 0.0
## Groups the projectile may damage (overrides the projectile scene's hit_groups).
@export var projectile_hit_groups: Array[String] = ["player"]
## Collision mask for the projectile (World + Player by default). 0 = keep the scene's mask.
@export_flags_3d_physics var projectile_collision_mask: int = 3
@export var preferred_range: float = 13.0
@export var min_range: float = 7.0
@export var attack_range: float = 18.0
@export var fire_cooldown: float = 2.5
@export var telegraph_time: float = 0.8
@export var lead_target: bool = true
@export var muzzle: Marker3D
## Pivot whose child is a thin BoxMesh stretching from z=0 to z=-1. It is aimed at the player
## and scaled along Z to the distance. Defaults to the child named "Telegraph".
@export var telegraph_pivot: Node3D
## Straight shots per attack, fanned across volley_spread_degrees (boss volleys).
@export_range(1, 15) var projectiles_per_volley: int = 1
@export var volley_spread_degrees: float = 0.0

@export_group("Mortar")
@export var use_mortar_arc: bool = false
@export var mortar_flight_time: float = 1.2
@export var mortar_gravity: float = 20.0
## Shadow / target decal shown where the shell will land.
@export var landing_marker_scene: PackedScene
## Shells per barrage. The first lands on the player, the rest scatter around them.
@export_range(1, 12) var shells_per_volley: int = 1
@export var mortar_scatter_radius: float = 0.0

var attack_state: AttackState = AttackState.REPOSITION
var _attack_timer: float = 0.0
var _locked_aim_points: Array[Vector3] = []


func _apply_depth_scaling() -> void:
	super()
	if GameManager.run_active:
		projectile_damage *= GameManager.enemy_damage_multiplier()
		fire_cooldown *= GameManager.enemy_fire_cooldown_multiplier()


func _ready() -> void:
	super()
	if muzzle == null:
		muzzle = get_node_or_null("Visual/Muzzle") as Marker3D
	if telegraph_pivot == null:
		telegraph_pivot = get_node_or_null("Telegraph") as Node3D
	_hide_telegraph()
	_attack_timer = randf_range(0.5, fire_cooldown)


func _get_desired_velocity(delta: float) -> Vector3:
	_attack_timer -= delta
	if not is_instance_valid(target):
		_hide_telegraph()
		return Vector3.ZERO

	if attack_state == AttackState.AIMING:
		_update_telegraph()
		if _attack_timer <= 0.0:
			_fire()
			attack_state = AttackState.COOLDOWN
			_attack_timer = fire_cooldown
		return Vector3.ZERO

	if attack_state == AttackState.COOLDOWN and _attack_timer <= 0.0:
		attack_state = AttackState.REPOSITION

	var distance := distance_to_target()
	if attack_state == AttackState.REPOSITION and distance <= attack_range and has_line_of_sight():
		_begin_aim()
		return Vector3.ZERO

	if distance > preferred_range:
		return get_path_velocity()
	if distance < min_range:
		return -get_flat_direction_to_target() * move_speed
	return Vector3.ZERO


func _get_facing_direction() -> Vector3:
	if is_instance_valid(target) and (attack_state == AttackState.AIMING or distance_to_target() <= attack_range):
		return get_flat_direction_to_target()
	return super()


func _begin_aim() -> void:
	attack_state = AttackState.AIMING
	_attack_timer = telegraph_time
	_locked_aim_points.clear()
	var center := _get_ground_point(target.global_position)
	var count := shells_per_volley if use_mortar_arc else 1
	for i in count:
		var point := center
		if i > 0 and mortar_scatter_radius > 0.0:
			# Extra shells ring the player so standing still is never safe.
			var angle := TAU * float(i) / float(count - 1) + randf_range(-0.4, 0.4)
			var distance := mortar_scatter_radius * randf_range(0.55, 1.0)
			point = _get_ground_point(center + Vector3(cos(angle) * distance, 0.0, sin(angle) * distance))
		_locked_aim_points.append(point)
		if use_mortar_arc and landing_marker_scene != null:
			var marker := landing_marker_scene.instantiate() as Node3D
			if marker != null:
				get_tree().current_scene.add_child(marker)
				marker.global_position = point + Vector3.UP * 0.05
				get_tree().create_timer(telegraph_time + mortar_flight_time, false).timeout.connect(marker.queue_free)
	_update_telegraph()


func _fire() -> void:
	_hide_telegraph()
	if projectile_scene == null:
		return
	var origin := muzzle.global_position if muzzle != null else global_position + Vector3.UP
	if use_mortar_arc:
		for point in _locked_aim_points:
			_launch_shell(origin, point)
		return
	var aim_direction := _get_live_aim_point() - origin
	var count := maxi(projectiles_per_volley, 1)
	for i in count:
		var offset := 0.0 if count == 1 else lerpf(-volley_spread_degrees * 0.5, volley_spread_degrees * 0.5, float(i) / float(count - 1))
		var projectile := _spawn_projectile(origin)
		if projectile == null:
			return
		var lifetime := attack_range * 1.5 / maxf(projectile_speed, 0.1)
		projectile.setup(aim_direction.rotated(Vector3.UP, deg_to_rad(offset)), projectile_speed, projectile_damage, lifetime, splash_radius, self)


func _launch_shell(origin: Vector3, point: Vector3) -> void:
	var projectile := _spawn_projectile(origin)
	if projectile == null:
		return
	# Solve for the launch velocity that lands on the locked point after `flight_time`.
	var to_target := point - origin
	var flight_time := maxf(mortar_flight_time, 0.1)
	var launch := Vector3(to_target.x / flight_time, (to_target.y + 0.5 * mortar_gravity * flight_time * flight_time) / flight_time, to_target.z / flight_time)
	projectile.projectile_gravity = mortar_gravity
	projectile.setup(launch, launch.length(), projectile_damage, flight_time + 1.5, splash_radius, self)


func _spawn_projectile(origin: Vector3) -> Bullet:
	var projectile := projectile_scene.instantiate() as Bullet
	if projectile == null:
		push_warning("RangedEnemy: projectile_scene root must use Bullet.gd or Rocket.gd.")
		return null
	projectile.hit_groups = projectile_hit_groups.duplicate()
	if projectile_collision_mask != 0:
		projectile.collision_mask = projectile_collision_mask
	get_tree().current_scene.add_child(projectile)
	projectile.global_position = origin
	return projectile


func _get_live_aim_point() -> Vector3:
	var aim := target.global_position + Vector3.UP * 0.5
	var body := target as CharacterBody3D
	if lead_target and body != null:
		var travel_time := global_position.distance_to(aim) / maxf(projectile_speed, 0.1)
		aim += Vector3(body.velocity.x, 0.0, body.velocity.z) * travel_time * 0.6
	return aim


func _get_ground_point(point: Vector3) -> Vector3:
	var query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.0, point + Vector3.DOWN * 10.0, sight_mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit["position"] if not hit.is_empty() else point


func _update_telegraph() -> void:
	if telegraph_pivot == null or use_mortar_arc or not is_instance_valid(target):
		return
	var aim := _get_live_aim_point()
	aim.y = telegraph_pivot.global_position.y
	var distance := telegraph_pivot.global_position.distance_to(aim)
	if distance < 0.1:
		return
	telegraph_pivot.visible = true
	telegraph_pivot.scale = Vector3.ONE
	telegraph_pivot.look_at(aim, Vector3.UP)
	telegraph_pivot.scale = Vector3(1.0, 1.0, distance)


func _hide_telegraph() -> void:
	if telegraph_pivot != null:
		telegraph_pivot.visible = false
