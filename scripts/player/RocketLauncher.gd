class_name RocketLauncher
extends WeaponMount
## Front-mounted launcher. Fires straight ahead when `fire_action` is pressed, or, once the
## player owns the `mouse_aim_flag` upgrade, swivels to fire wherever the mouse points
## (or the right stick, on a gamepad). A reticle shows the aim spot on the ground.

@export var fire_action: StringName = &"fire_rocket"
@export var hold_to_fire: bool = false
## Keep rockets level so they don't plough into the floor when the buggy noses down.
@export var flatten_aim: bool = true

@export_group("Aiming Upgrade")
## PlayerData flag that turns on mouse / right-stick aiming.
@export var mouse_aim_flag: String = "rocket_mouse_aim"
## Ground reticle shown while aiming. Defaults to the child named "AimReticle".
@export var aim_reticle: Node3D
@export var aim_turn_speed: float = 14.0
@export var stick_deadzone: float = 0.35

var _aim_direction: Vector3 = Vector3.ZERO


func _ready() -> void:
	super()
	if aim_reticle == null:
		aim_reticle = get_node_or_null("AimReticle") as Node3D
	if aim_reticle != null:
		aim_reticle.top_level = true
		aim_reticle.visible = false


func _physics_process(delta: float) -> void:
	super(delta)
	var vehicle := _owner_body as PlayerVehicle
	var can_act := vehicle == null or not (vehicle.controls_locked or vehicle.is_wrecked)
	_update_aim(delta, can_act)
	if not can_act or not _wants_to_fire():
		return
	var direction := _aim_direction
	if direction == Vector3.ZERO:
		direction = -(muzzle.global_transform.basis.z if muzzle != null else global_transform.basis.z)
		if flatten_aim:
			direction.y = 0.0
	fire(direction.normalized())


func is_aiming_enabled() -> bool:
	return mouse_aim_flag != "" and PlayerData.has_flag(mouse_aim_flag)


func _update_aim(delta: float, can_act: bool) -> void:
	_aim_direction = Vector3.ZERO
	var aim_point := Vector3.ZERO
	if is_aiming_enabled() and can_act:
		var result := _get_aim_target()
		if not result.is_empty():
			aim_point = result["point"]
			_aim_direction = result["direction"]
	if aim_reticle != null:
		aim_reticle.visible = _aim_direction != Vector3.ZERO
		if aim_reticle.visible:
			aim_reticle.global_position = aim_point
	# Swivel the pod toward the aim (or back to straight ahead), in the parent's space.
	var desired_yaw := 0.0
	var parent_node := get_parent() as Node3D
	if _aim_direction != Vector3.ZERO and parent_node != null:
		var local := parent_node.global_transform.basis.inverse() * _aim_direction
		desired_yaw = atan2(-local.x, -local.z)
	rotation.y = lerp_angle(rotation.y, desired_yaw, clampf(aim_turn_speed * delta, 0.0, 1.0))


## Returns {"point": ground aim point, "direction": flat unit direction} or {} if there's no aim.
func _get_aim_target() -> Dictionary:
	var origin := muzzle.global_position if muzzle != null else global_position
	var ground_y := _owner_body.global_position.y if _owner_body != null else origin.y - 1.0
	# Right stick wins when it's pushed (screen up = -Z, because the camera looks north).
	var stick := Vector2(Input.get_joy_axis(0, JOY_AXIS_RIGHT_X), Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y))
	if stick.length() > stick_deadzone:
		var stick_direction := Vector3(stick.x, 0.0, stick.y).normalized()
		return {"point": Vector3(origin.x, ground_y, origin.z) + stick_direction * 12.0, "direction": stick_direction}
	var camera := get_viewport().get_camera_3d()
	if camera == null:
		return {}
	var mouse := get_viewport().get_mouse_position()
	var hit: Variant = Plane(Vector3.UP, ground_y).intersects_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
	if hit == null:
		return {}
	var point: Vector3 = hit
	var flat := Vector3(point.x - origin.x, 0.0, point.z - origin.z)
	if flat.length() < 1.5:
		return {}
	return {"point": point + Vector3.UP * 0.05, "direction": flat.normalized()}


func _wants_to_fire() -> bool:
	if not InputMap.has_action(fire_action):
		return false
	if hold_to_fire:
		return Input.is_action_pressed(fire_action)
	return Input.is_action_just_pressed(fire_action)
