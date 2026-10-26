class_name TurretController
extends WeaponMount
## 360° roof turret. Scans its DetectionArea for bodies in `target_groups`, smoothly yaws
## toward the nearest visible one and fires automatically once lined up.

@export var detection_area: Area3D
@export var target_groups: Array[String] = ["enemies"]
@export var auto_fire: bool = true
@export var aim_tolerance_degrees: float = 10.0
@export var require_line_of_sight: bool = true
## Layers that block the turret's view (usually just World).
@export_flags_3d_physics var line_of_sight_mask: int = 1
## How fast the turret swings back to face forward with no target.
@export var idle_return_speed: float = 2.0
@export var aim_height_offset: float = 0.5

var current_target: Node3D
var _candidates: Array[Node3D] = []
var _retarget_timer: float = 0.0


func _ready() -> void:
	super()
	if detection_area == null:
		detection_area = get_node_or_null("DetectionArea") as Area3D
	if detection_area != null:
		detection_area.body_entered.connect(_on_body_entered)
		detection_area.body_exited.connect(_on_body_exited)
	_apply_detection_range()


func refresh_weapon() -> void:
	super()
	_apply_detection_range()


func _physics_process(delta: float) -> void:
	super(delta)
	_retarget_timer -= delta
	if _retarget_timer <= 0.0 or not _is_valid_target(current_target):
		_retarget_timer = 0.15
		current_target = _pick_target()

	if current_target == null:
		rotation.y = lerp_angle(rotation.y, 0.0, clampf(idle_return_speed * delta, 0.0, 1.0))
		return

	var aim_point := current_target.global_position + Vector3.UP * aim_height_offset
	# Work in the parent's space so the turret tracks correctly while the chassis tilts.
	var local_direction := aim_point - global_position
	var parent_node := get_parent() as Node3D
	if parent_node != null:
		local_direction = parent_node.global_transform.basis.inverse() * local_direction
	var desired_yaw := atan2(-local_direction.x, -local_direction.z)
	var turn_speed: float = weapon.turn_speed if weapon != null else 8.0
	rotation.y = lerp_angle(rotation.y, desired_yaw, clampf(turn_speed * delta, 0.0, 1.0))

	if auto_fire and _is_aimed_at(aim_point):
		var origin := muzzle.global_position if muzzle != null else global_position
		fire((aim_point - origin).normalized())


func _pick_target() -> Node3D:
	var best: Node3D = null
	var best_distance := INF
	for candidate in _candidates.duplicate():
		if not _is_valid_target(candidate):
			_candidates.erase(candidate)
			continue
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < best_distance and (not require_line_of_sight or _has_line_of_sight(candidate)):
			best = candidate
			best_distance = distance
	return best


func _is_valid_target(node: Node3D) -> bool:
	if not is_instance_valid(node) or not node.is_inside_tree():
		return false
	if node.has_method("is_alive") and not node.is_alive():
		return false
	for group_name in target_groups:
		if node.is_in_group(group_name):
			return true
	return false


func _is_aimed_at(point: Vector3) -> bool:
	var forward := -global_transform.basis.z
	var to_target := point - global_position
	forward.y = 0.0
	to_target.y = 0.0
	if to_target.length_squared() < 0.01:
		return true
	return rad_to_deg(forward.angle_to(to_target)) <= aim_tolerance_degrees


func _has_line_of_sight(target: Node3D) -> bool:
	var from := muzzle.global_position if muzzle != null else global_position
	var query := PhysicsRayQueryParameters3D.create(from, target.global_position + Vector3.UP * aim_height_offset, line_of_sight_mask)
	if _owner_body != null:
		query.exclude = [_owner_body.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.get("collider") == target


func _apply_detection_range() -> void:
	if detection_area == null or weapon == null:
		return
	for child in detection_area.get_children():
		var shape_node := child as CollisionShape3D
		if shape_node != null and shape_node.shape is SphereShape3D:
			(shape_node.shape as SphereShape3D).radius = weapon.detection_range


func _on_body_entered(body: Node3D) -> void:
	for group_name in target_groups:
		if body.is_in_group(group_name):
			if not _candidates.has(body):
				_candidates.append(body)
			return


func _on_body_exited(body: Node3D) -> void:
	_candidates.erase(body)
	if body == current_target:
		current_target = null
