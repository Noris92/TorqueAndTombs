class_name RammerEnemy
extends BaseEnemy
## Rammer buggy / melee monster. Chases the player along the navmesh, winds up when close,
## then charges in a straight line. Contact deals damage and knocks the player away.

enum RamState { CHASE, WINDUP, CHARGE, RECOVER }

@export_group("Ramming")
@export var charge_range: float = 9.0
@export var charge_speed_multiplier: float = 2.0
@export var charge_acceleration: float = 60.0
@export var windup_time: float = 0.4
@export var charge_duration: float = 1.0
@export var recover_time: float = 1.2
@export var ram_impulse: float = 14.0
@export var ram_upward_impulse: float = 3.0
@export var recoil_impulse: float = 6.0
@export var hit_cooldown: float = 0.8

var ram_state: RamState = RamState.CHASE
var _state_timer: float = 0.0
var _charge_direction: Vector3 = Vector3.ZERO
var _hit_timer: float = 0.0


func _get_desired_velocity(delta: float) -> Vector3:
	_hit_timer = maxf(_hit_timer - delta, 0.0)
	_state_timer -= delta
	match ram_state:
		RamState.CHASE:
			if is_instance_valid(target) and distance_to_target() <= charge_range and has_line_of_sight():
				_enter_state(RamState.WINDUP)
				return Vector3.ZERO
			return get_path_velocity()
		RamState.WINDUP:
			_charge_direction = get_flat_direction_to_target()
			if _state_timer <= 0.0:
				_enter_state(RamState.CHARGE)
			return Vector3.ZERO
		RamState.CHARGE:
			if _state_timer <= 0.0:
				_enter_state(RamState.RECOVER)
			return _charge_direction * move_speed * charge_speed_multiplier
		RamState.RECOVER:
			if _state_timer <= 0.0:
				_enter_state(RamState.CHASE)
			return get_path_velocity(move_speed * 0.5)
	return Vector3.ZERO


func _after_move(_delta: float) -> void:
	if _hit_timer > 0.0:
		return
	for i in get_slide_collision_count():
		var collision := get_slide_collision(i)
		var body := collision.get_collider() as Node
		if body == null or not body.is_in_group("player"):
			continue
		# The collision normal points from the player toward us, so -normal points at the player.
		var push := -collision.get_normal()
		push.y = 0.0
		push = push.normalized()
		var damage := contact_damage * (1.5 if ram_state == RamState.CHARGE else 1.0)
		if body.has_method("take_damage"):
			body.take_damage(damage, self)
		if body.has_method("add_impulse"):
			body.add_impulse(push * ram_impulse + Vector3.UP * ram_upward_impulse)
		apply_knockback(-push * recoil_impulse)
		_hit_timer = hit_cooldown
		if ram_state == RamState.CHARGE:
			_enter_state(RamState.RECOVER)
		return


func _get_acceleration() -> float:
	return charge_acceleration if ram_state == RamState.CHARGE else acceleration


func _get_facing_direction() -> Vector3:
	if ram_state == RamState.WINDUP or ram_state == RamState.CHARGE:
		return _charge_direction
	return super()


func _enter_state(new_state: RamState) -> void:
	ram_state = new_state
	match new_state:
		RamState.WINDUP:
			_state_timer = windup_time
		RamState.CHARGE:
			_state_timer = charge_duration
		RamState.RECOVER:
			_state_timer = recover_time
		_:
			_state_timer = 0.0
