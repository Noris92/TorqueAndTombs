class_name PlayerVehicle
extends CharacterBody3D
## Arcade buggy controller for Torque & Tombs.
## Acceleration/braking, drifting with an exit boost, nitro, ramming, safe-ground respawns
## and mid-air self-righting with pitch/roll control.
## The model must face -Z. Only the root yaws; VisualRoot tilts for ramps and air control.

signal boost_changed(current: float, maximum: float)
signal drift_started
signal drift_ended(duration: float, boosted: bool)
signal landed(clean: bool)
signal respawned

@export_group("Handling")
## Yaw speed (radians/second) at full steering input.
@export var steer_speed: float = 2.4
## Steering fades in from 0 up to this speed so the buggy can't spin on the spot.
@export var full_steer_speed: float = 5.0
## Fraction of steering lost at top speed.
@export_range(0.0, 1.0) var high_speed_steer_reduction: float = 0.35
@export var brake_force: float = 45.0
@export_range(0.1, 1.0) var reverse_speed_ratio: float = 0.45
## Optional. X = current speed / top speed (0..1), Y = acceleration multiplier.
@export var acceleration_curve: Curve

@export_group("Drift")
@export var min_drift_speed: float = 7.0
@export var drift_steer_multiplier: float = 1.15
## Speed scrubbed per second while drifting.
@export var drift_speed_loss: float = 2.0
## Drifts shorter than this give no boost.
@export var drift_boost_min_time: float = 0.5
## Drifts this long (or longer) give the maximum boost.
@export var drift_boost_max_time: float = 2.0
@export var drift_boost_min_speed: float = 4.0
@export var drift_boost_max_speed: float = 10.0

@export_group("Boost")
@export var boost_speed_multiplier: float = 1.45
@export var boost_acceleration_bonus: float = 30.0
@export var boost_drain_per_second: float = 40.0
@export var boost_regen_per_second: float = 12.0
@export var boost_regen_delay: float = 1.0

@export_group("Air")
@export var gravity_multiplier: float = 1.8
@export var air_pitch_speed: float = 2.5
@export var air_roll_speed: float = 2.5
@export var air_steer_ratio: float = 0.35
@export var max_air_tilt_degrees: float = 35.0
## How quickly the buggy rights itself in the air when you let go of the controls.
@export var upright_speed: float = 1.6
@export var ground_align_speed: float = 10.0
## Landing within this angle of the ground counts as clean and refills some boost.
@export var clean_landing_angle_degrees: float = 12.0
@export var clean_landing_boost_reward: float = 20.0
@export var min_air_time_for_landing: float = 0.35

@export_group("Ramming")
@export var ram_min_speed: float = 10.0
@export var ram_damage_per_speed: float = 2.0
@export var ram_cooldown: float = 0.4
@export var ram_knockback: float = 0.6
@export var rigid_body_push: float = 0.8

@export_group("Damage & Respawn")
@export var invulnerability_time: float = 0.4
@export var respawn_invulnerability_time: float = 1.5
@export var death_effect: PackedScene
@export var hit_camera_shake: float = 0.35

@export_group("Wheels")
## Spin with speed and steer with input (rotation is set on these nodes, so use pivots).
@export var front_wheels: Array[Node3D] = []
## Spin with speed only.
@export var rear_wheels: Array[Node3D] = []
@export var wheel_radius: float = 0.45
@export var max_wheel_steer_degrees: float = 28.0

@export_group("Nodes")
## Defaults to the child named "VisualRoot".
@export var visual_root: Node3D
## Parent of named attach points for shop visuals. Defaults to "VisualRoot/Mounts".
@export var mounts_root: Node3D
@export var drift_particles: Array[GPUParticles3D] = []
@export var boost_particles: GPUParticles3D
@export var engine_audio: AudioStreamPlayer3D

var boost_meter: float = 0.0
var is_drifting: bool = false
var is_boosting: bool = false
var controls_locked: bool = false
var is_wrecked: bool = false

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
var _throttle: float = 0.0
var _steer: float = 0.0
var _drift_held: bool = false
var _boost_held: bool = false
var _drift_time: float = 0.0
var _air_time: float = 0.0
var _was_on_floor: bool = true
var _air_pitch: float = 0.0
var _air_roll: float = 0.0
var _boost_regen_timer: float = 0.0
var _overspeed_grace: float = 0.0
var _invulnerable_timer: float = 0.0
var _slow_factor: float = 1.0
var _slow_timer: float = 0.0
var _pre_slide_velocity: Vector3 = Vector3.ZERO
var _ram_timestamps: Dictionary = {}
var _safe_transforms: Array[Transform3D] = []
var _safe_sample_timer: float = 0.0
var _respawning: bool = false
var _wheel_spin: float = 0.0
var _wheel_steer: float = 0.0


func _ready() -> void:
	add_to_group("player")
	floor_snap_length = 0.6
	floor_max_angle = deg_to_rad(50.0)
	if visual_root == null:
		visual_root = get_node_or_null("VisualRoot") as Node3D
	if mounts_root == null and visual_root != null:
		mounts_root = visual_root.get_node_or_null("Mounts") as Node3D
	boost_meter = PlayerData.boost_capacity
	PlayerData.player_died.connect(_on_player_died)
	PlayerData.stats_changed.connect(_on_stats_changed)
	refresh_attachments()
	_safe_transforms.append(global_transform)
	if engine_audio != null and engine_audio.stream != null and not engine_audio.playing:
		engine_audio.play()
	boost_changed.emit(boost_meter, PlayerData.boost_capacity)


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_read_input()
	_update_boost(delta)

	if is_on_floor():
		_apply_ground_movement(delta)
		_match_floor_slope()
	else:
		if is_drifting:
			_end_drift(false)
		_apply_air_movement(delta)

	_pre_slide_velocity = velocity
	move_and_slide()
	_handle_collisions()
	_handle_landing(delta)
	_update_visual_orientation(delta)
	_update_safe_position(delta)
	_update_effects()
	_update_wheels(delta)


# --------------------------------------------------------------------------
# Input & timers
# --------------------------------------------------------------------------

func _read_input() -> void:
	if controls_locked or is_wrecked:
		_throttle = 0.0
		_steer = 0.0
		_drift_held = false
		_boost_held = false
		return
	_throttle = Input.get_axis("brake", "accelerate")
	_steer = Input.get_axis("steer_right", "steer_left")
	_drift_held = Input.is_action_pressed("drift")
	_boost_held = Input.is_action_pressed("boost")


func _tick_timers(delta: float) -> void:
	_invulnerable_timer = maxf(_invulnerable_timer - delta, 0.0)
	_overspeed_grace = maxf(_overspeed_grace - delta, 0.0)
	if _slow_timer > 0.0:
		_slow_timer -= delta
		if _slow_timer <= 0.0:
			_slow_factor = 1.0


# --------------------------------------------------------------------------
# Ground movement
# --------------------------------------------------------------------------

func _apply_ground_movement(delta: float) -> void:
	var planar := Vector3(velocity.x, 0.0, velocity.z)
	var forward_speed := planar.dot(_flat_forward())

	_update_drift(delta, forward_speed, planar.length())

	# Rotate the body first so the velocity lags behind the heading: that lag is the slip.
	var top_speed: float = maxf(PlayerData.top_speed, 0.01)
	var speed_ratio := clampf(absf(forward_speed) / top_speed, 0.0, 1.0)
	var steer_amount := steer_speed * clampf(absf(forward_speed) / full_steer_speed, 0.0, 1.0)
	steer_amount *= 1.0 - high_speed_steer_reduction * speed_ratio
	if is_drifting:
		steer_amount *= drift_steer_multiplier
	var reverse_sign := -1.0 if forward_speed < -0.5 else 1.0
	rotate_y(_steer * steer_amount * reverse_sign * delta)

	var forward := _flat_forward()
	var right := _flat_right()
	forward_speed = planar.dot(forward)
	var lateral_speed := planar.dot(right)

	var max_speed: float = PlayerData.top_speed * _slow_factor
	var accel: float = PlayerData.acceleration
	if acceleration_curve != null:
		accel *= acceleration_curve.sample(speed_ratio)
	if is_boosting:
		max_speed *= boost_speed_multiplier
		accel += boost_acceleration_bonus

	if is_drifting:
		_apply_drift_motion(delta, planar, forward, max_speed, accel)
		return

	var target_speed := 0.0
	var rate: float = PlayerData.friction
	if _throttle > 0.0:
		if forward_speed < -0.5:
			rate = brake_force
		else:
			target_speed = max_speed * _throttle
			rate = accel * _throttle
	elif _throttle < 0.0:
		if forward_speed > 0.5:
			rate = brake_force
		else:
			target_speed = -max_speed * reverse_speed_ratio
			rate = accel * absf(_throttle)

	if forward_speed > max_speed and _throttle >= 0.0:
		# Above top speed (boost pad, drift boost): bleed off gently once the grace time ends.
		if _overspeed_grace <= 0.0:
			forward_speed = move_toward(forward_speed, max_speed, PlayerData.friction * delta)
	else:
		forward_speed = move_toward(forward_speed, target_speed, rate * delta)

	var grip: float = PlayerData.grip
	lateral_speed = lerpf(lateral_speed, 0.0, clampf(grip * delta, 0.0, 1.0))

	var new_planar := forward * forward_speed + right * lateral_speed
	velocity.x = new_planar.x
	velocity.z = new_planar.z


## Keeps the velocity parallel to the ground so ramps actually launch the buggy off their lip
## (CharacterBody3D otherwise climbs slopes with a flat velocity and just rolls off the edge).
func _match_floor_slope() -> void:
	var normal := get_floor_normal()
	if normal.y > 0.05:
		velocity.y = -(normal.x * velocity.x + normal.z * velocity.z) / normal.y


## While drifting the buggy keeps its momentum: the direction of travel swings toward the nose
## at a rate set by grip * (1 - drift_factor), so the body holds a slide angle instead of gripping.
func _apply_drift_motion(delta: float, planar: Vector3, forward: Vector3, max_speed: float, accel: float) -> void:
	var speed := planar.length()
	var direction := planar / speed if speed > 0.01 else forward
	var align_rate: float = PlayerData.grip * (1.0 - PlayerData.drift_factor)
	direction = direction.slerp(forward, clampf(align_rate * delta, 0.0, 1.0)).normalized()
	if _throttle > 0.0 and speed < max_speed:
		speed = minf(speed + accel * _throttle * delta, max_speed)
	elif _throttle < 0.0:
		speed = move_toward(speed, 0.0, brake_force * delta)
	elif speed > max_speed and _overspeed_grace <= 0.0:
		speed = move_toward(speed, max_speed, PlayerData.friction * delta)
	speed = move_toward(speed, 0.0, drift_speed_loss * delta)
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed


func _update_drift(delta: float, forward_speed: float, planar_speed: float) -> void:
	if not is_drifting:
		if _drift_held and forward_speed >= min_drift_speed and absf(_steer) > 0.2:
			is_drifting = true
			_drift_time = 0.0
			drift_started.emit()
	elif not _drift_held or planar_speed < min_drift_speed * 0.7 or forward_speed <= 0.0:
		# Releasing the button pays out the boost; spinning out or bleeding off speed does not.
		_end_drift(not _drift_held)
	else:
		_drift_time += delta


func _end_drift(award_boost: bool) -> void:
	is_drifting = false
	var boosted := false
	if award_boost and _drift_time >= drift_boost_min_time:
		var t := inverse_lerp(drift_boost_min_time, drift_boost_max_time, minf(_drift_time, drift_boost_max_time))
		velocity += _flat_forward() * lerpf(drift_boost_min_speed, drift_boost_max_speed, t)
		_overspeed_grace = 0.6
		boosted = true
	drift_ended.emit(_drift_time, boosted)
	if not is_wrecked:
		ComboTracker.register_drift(_drift_time)
	_drift_time = 0.0


# --------------------------------------------------------------------------
# Air movement & landing
# --------------------------------------------------------------------------

func _apply_air_movement(delta: float) -> void:
	velocity.y -= _gravity * gravity_multiplier * delta
	var max_tilt := deg_to_rad(max_air_tilt_degrees)
	# Accelerate = nose down, brake = nose up; steering rolls the chassis.
	_air_pitch = clampf(_air_pitch - _throttle * air_pitch_speed * delta, -max_tilt, max_tilt)
	_air_roll = clampf(_air_roll + _steer * air_roll_speed * delta, -max_tilt, max_tilt)
	# Self-righting whenever the player lets go.
	var upright_weight := clampf(upright_speed * delta, 0.0, 1.0)
	if absf(_throttle) < 0.1:
		_air_pitch = lerpf(_air_pitch, 0.0, upright_weight)
	if absf(_steer) < 0.1:
		_air_roll = lerpf(_air_roll, 0.0, upright_weight)
	rotate_y(_steer * steer_speed * air_steer_ratio * delta)
	if is_boosting:
		velocity += _flat_forward() * boost_acceleration_bonus * 0.5 * delta


func _handle_landing(delta: float) -> void:
	var on_floor := is_on_floor()
	if on_floor:
		if not _was_on_floor and _air_time >= min_air_time_for_landing:
			var visual_up := Basis.from_euler(Vector3(_air_pitch, 0.0, _air_roll)).y
			var local_normal := (global_transform.basis.inverse() * get_floor_normal()).normalized()
			var clean := rad_to_deg(visual_up.angle_to(local_normal)) <= clean_landing_angle_degrees
			if clean:
				add_boost(clean_landing_boost_reward)
			landed.emit(clean)
			if not is_wrecked:
				ComboTracker.register_air(_air_time, clean)
		_air_time = 0.0
	else:
		if _was_on_floor:
			_capture_takeoff_tilt()
		_air_time += delta
	_was_on_floor = on_floor


func _capture_takeoff_tilt() -> void:
	# Leaving a ramp keeps its angle, so the player has something to correct in the air.
	if visual_root == null:
		_air_pitch = 0.0
		_air_roll = 0.0
		return
	var euler := visual_root.basis.get_euler()
	_air_pitch = euler.x
	_air_roll = euler.z


func _update_visual_orientation(delta: float) -> void:
	if visual_root == null:
		return
	if is_on_floor():
		var local_normal := (global_transform.basis.inverse() * get_floor_normal()).normalized()
		var target := Quaternion(Vector3.UP, local_normal)
		var current := visual_root.basis.get_rotation_quaternion()
		visual_root.basis = Basis(current.slerp(target, clampf(ground_align_speed * delta, 0.0, 1.0)))
	else:
		visual_root.basis = Basis.from_euler(Vector3(_air_pitch, 0.0, _air_roll))


# --------------------------------------------------------------------------
# Boost
# --------------------------------------------------------------------------

func _update_boost(delta: float) -> void:
	var capacity: float = PlayerData.boost_capacity
	var previous := boost_meter
	is_boosting = _boost_held and boost_meter > 0.0
	if is_boosting:
		boost_meter = maxf(boost_meter - boost_drain_per_second * delta, 0.0)
		_boost_regen_timer = boost_regen_delay
	elif _boost_regen_timer > 0.0:
		_boost_regen_timer -= delta
	else:
		boost_meter = minf(boost_meter + boost_regen_per_second * delta, capacity)
	if not is_equal_approx(previous, boost_meter):
		boost_changed.emit(boost_meter, capacity)


func add_boost(amount: float) -> void:
	boost_meter = clampf(boost_meter + amount, 0.0, PlayerData.boost_capacity)
	boost_changed.emit(boost_meter, PlayerData.boost_capacity)


# --------------------------------------------------------------------------
# Collisions / ramming
# --------------------------------------------------------------------------

func _handle_collisions() -> void:
	var now := Time.get_ticks_msec()
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var collider := collision.get_collider() as Node
		if collider == null:
			continue
		var normal := collision.get_normal()
		var impact_speed := maxf(-_pre_slide_velocity.dot(normal), 0.0)
		if collider is RigidBody3D:
			(collider as RigidBody3D).apply_central_impulse(-normal * impact_speed * rigid_body_push)
		if impact_speed < ram_min_speed or not collider.has_method("take_damage"):
			continue
		if not (collider.is_in_group("enemies") or collider.is_in_group("breakable")):
			continue
		var id := collider.get_instance_id()
		if now - int(_ram_timestamps.get(id, -100000)) < int(ram_cooldown * 1000.0):
			continue
		_ram_timestamps[id] = now
		collider.take_damage(impact_speed * ram_damage_per_speed, self)
		if collider.has_method("apply_knockback"):
			collider.apply_knockback(-normal * impact_speed * ram_knockback)
		_shake_camera(0.2)


# --------------------------------------------------------------------------
# Public API used by hazards, enemies and pickups
# --------------------------------------------------------------------------

func take_damage(amount: float, _source: Node = null, ignore_invulnerability: bool = false) -> void:
	if is_wrecked:
		return
	if _invulnerable_timer > 0.0 and not ignore_invulnerability:
		return
	_invulnerable_timer = invulnerability_time
	PlayerData.take_damage(amount)
	_shake_camera(hit_camera_shake)


func apply_slow(factor: float, duration: float) -> void:
	factor = clampf(factor, 0.05, 1.0)
	_slow_factor = minf(_slow_factor, factor)
	_slow_timer = maxf(_slow_timer, duration)
	velocity.x *= factor
	velocity.z *= factor


func add_impulse(impulse: Vector3, overspeed_grace: float = 0.5) -> void:
	velocity += impulse
	_overspeed_grace = maxf(_overspeed_grace, overspeed_grace)


## Called by BoostPad: guarantees at least `target_speed` along `direction`.
func apply_boost_pad(direction: Vector3, target_speed: float, vertical_speed: float = 0.0) -> void:
	var flat_direction := Vector3(direction.x, 0.0, direction.z).normalized()
	if flat_direction == Vector3.ZERO:
		return
	var along := velocity.dot(flat_direction)
	if along < target_speed:
		velocity += flat_direction * (target_speed - along)
	if vertical_speed > 0.0:
		velocity.y = maxf(velocity.y, vertical_speed)
	_overspeed_grace = maxf(_overspeed_grace, 1.0)
	_shake_camera(0.15)


func get_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


func teleport_to(target: Transform3D) -> void:
	global_transform = Transform3D(Basis(Vector3.UP, target.basis.get_euler().y), target.origin)
	velocity = Vector3.ZERO
	_safe_transforms.clear()
	_safe_transforms.append(global_transform)
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.has_method("snap_to_target"):
		camera.snap_to_target()


func respawn_at_safe_position(delay: float = 0.6) -> void:
	if _respawning or is_wrecked:
		return
	_respawning = true
	controls_locked = true
	velocity = Vector3.ZERO
	set_physics_process(false)
	if visual_root != null:
		visual_root.visible = false
	get_tree().create_timer(delay, false).timeout.connect(_finish_respawn)


func _finish_respawn() -> void:
	_respawning = false
	if is_wrecked:
		return
	var target: Transform3D = _safe_transforms[0] if not _safe_transforms.is_empty() else global_transform
	teleport_to(target)
	controls_locked = false
	_invulnerable_timer = respawn_invulnerability_time
	if visual_root != null:
		visual_root.visible = true
	set_physics_process(true)
	respawned.emit()


## Re-attaches shop visuals and reloads weapons from PlayerData (call after a purchase).
func refresh_attachments() -> void:
	if mounts_root != null:
		for mount in mounts_root.get_children():
			for child in mount.get_children():
				if child.has_meta("upgrade_visual"):
					child.queue_free()
		for point_name in PlayerData.attached_visuals:
			var mount := mounts_root.get_node_or_null(NodePath(String(point_name)))
			var path := String(PlayerData.attached_visuals[point_name])
			if mount == null or not ResourceLoader.exists(path):
				continue
			var scene := load(path) as PackedScene
			if scene == null:
				continue
			var instance := scene.instantiate()
			instance.set_meta("upgrade_visual", true)
			mount.add_child(instance)
	_refresh_weapon_mounts(self)


func _refresh_weapon_mounts(node: Node) -> void:
	for child in node.get_children():
		if child is WeaponMount:
			(child as WeaponMount).refresh_weapon()
		_refresh_weapon_mounts(child)


# --------------------------------------------------------------------------
# Safe ground tracking (for lava / kill zones)
# --------------------------------------------------------------------------

func _update_safe_position(delta: float) -> void:
	_safe_sample_timer -= delta
	if _safe_sample_timer > 0.0 or _respawning:
		return
	_safe_sample_timer = 0.25
	if not is_on_floor() or _is_on_unsafe_ground():
		return
	_safe_transforms.append(global_transform)
	# Respawn uses the oldest sample (~1.5 s ago) so we don't land right at the pit's edge.
	if _safe_transforms.size() > 6:
		_safe_transforms.pop_front()


func _is_on_unsafe_ground() -> bool:
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider() as Node
		if collider != null and collider.is_in_group("unsafe_ground"):
			return true
	return false


# --------------------------------------------------------------------------
# Effects / helpers
# --------------------------------------------------------------------------

func _update_effects() -> void:
	var on_floor := is_on_floor()
	for particles in drift_particles:
		if particles != null:
			particles.emitting = is_drifting and on_floor
	if boost_particles != null:
		boost_particles.emitting = is_boosting
	if engine_audio != null:
		var ratio := clampf(get_speed() / maxf(PlayerData.top_speed, 0.01), 0.0, 1.5)
		engine_audio.pitch_scale = lerpf(0.8, 1.9, ratio / 1.5)


func _update_wheels(delta: float) -> void:
	if front_wheels.is_empty() and rear_wheels.is_empty():
		return
	# Rolling toward -Z is a negative rotation around the axle (X).
	var forward_speed := velocity.dot(_flat_forward())
	_wheel_spin = wrapf(_wheel_spin - forward_speed / maxf(wheel_radius, 0.05) * delta, -PI, PI)
	_wheel_steer = lerpf(_wheel_steer, deg_to_rad(max_wheel_steer_degrees) * _steer, clampf(12.0 * delta, 0.0, 1.0))
	for wheel in front_wheels:
		if wheel != null:
			wheel.rotation = Vector3(_wheel_spin, _wheel_steer, 0.0)
	for wheel in rear_wheels:
		if wheel != null:
			wheel.rotation = Vector3(_wheel_spin, 0.0, 0.0)


func _flat_forward() -> Vector3:
	var forward := -global_transform.basis.z
	forward.y = 0.0
	return forward.normalized()


func _flat_right() -> Vector3:
	var right := global_transform.basis.x
	right.y = 0.0
	return right.normalized()


func _shake_camera(amount: float) -> void:
	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.has_method("add_trauma"):
		camera.add_trauma(amount)


func _on_stats_changed() -> void:
	boost_meter = minf(boost_meter, PlayerData.boost_capacity)
	boost_changed.emit(boost_meter, PlayerData.boost_capacity)


func _on_player_died() -> void:
	is_wrecked = true
	controls_locked = true
	is_drifting = false
	is_boosting = false
	GameManager.spawn_effect(death_effect, global_position)
	_shake_camera(0.8)
