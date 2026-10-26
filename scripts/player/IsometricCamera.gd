class_name IsometricCamera
extends Camera3D
## High-angle follow camera with velocity look-ahead and trauma-based screen shake.
## Put it anywhere in the level; it sets top_level so it never inherits the buggy's rotation.

@export var target: Node3D
## Camera position relative to the target. The viewing angle comes from this offset.
@export var offset: Vector3 = Vector3(0.0, 25.0, 18.0)
@export var follow_speed: float = 6.0
@export var look_ahead_distance: float = 5.0
@export var look_ahead_speed: float = 2.5
## Jump straight to the target if it's farther than this (teleports, respawns).
@export var snap_distance: float = 40.0
@export var use_orthographic: bool = false
@export var orthographic_size: float = 30.0

@export_group("Shake")
@export var max_shake_offset: float = 0.5
@export var trauma_decay: float = 1.8

var _trauma: float = 0.0
var _look_ahead: Vector3 = Vector3.ZERO


func _ready() -> void:
	top_level = true
	if use_orthographic:
		projection = Camera3D.PROJECTION_ORTHOGONAL
		size = orthographic_size
	if target != null:
		snap_to_target()


func _physics_process(delta: float) -> void:
	if not is_instance_valid(target):
		target = get_tree().get_first_node_in_group("player") as Node3D
		if target == null:
			return
		snap_to_target()

	var planar_velocity := Vector3.ZERO
	var body := target as CharacterBody3D
	if body != null:
		planar_velocity = Vector3(body.velocity.x, 0.0, body.velocity.z)
	var desired_look_ahead := (planar_velocity / 20.0).limit_length(1.0) * look_ahead_distance
	_look_ahead = _look_ahead.lerp(desired_look_ahead, clampf(look_ahead_speed * delta, 0.0, 1.0))

	var desired_position := target.global_position + _look_ahead + offset
	if global_position.distance_to(desired_position) > snap_distance:
		global_position = desired_position
	else:
		global_position = global_position.lerp(desired_position, 1.0 - exp(-follow_speed * delta))
	_update_shake(delta)


func snap_to_target() -> void:
	if not is_instance_valid(target) or not is_inside_tree():
		return
	_look_ahead = Vector3.ZERO
	global_position = target.global_position + offset
	look_at(target.global_position, Vector3.UP)


## 0..1. Shake strength is trauma squared, so small hits stay subtle.
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _update_shake(delta: float) -> void:
	if _trauma <= 0.0:
		h_offset = 0.0
		v_offset = 0.0
		return
	_trauma = maxf(_trauma - trauma_decay * delta, 0.0)
	var strength := _trauma * _trauma * max_shake_offset
	h_offset = randf_range(-1.0, 1.0) * strength
	v_offset = randf_range(-1.0, 1.0) * strength
