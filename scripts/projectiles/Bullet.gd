class_name Bullet
extends Area3D
## Fast projectile. Moves itself every physics frame and sweeps a ray along its path
## (using this Area3D's collision_mask) so it never tunnels through walls or enemies.
## Damages bodies in `hit_groups` that have take_damage(amount, source).

@export var hit_groups: Array[String] = ["enemies", "breakable"]
@export var impact_effect: PackedScene
@export var impact_sound: AudioStream
## Downward acceleration (0 = straight line). Mortar shells use this for their arc.
@export var projectile_gravity: float = 0.0
@export var explode_on_expire: bool = false
@export var align_to_velocity: bool = true

var velocity: Vector3 = Vector3.ZERO
var damage: float = 10.0
var splash_radius: float = 0.0
var shooter: Node = null

var _life: float = 2.0
var _has_hit: bool = false


func _ready() -> void:
	body_entered.connect(_on_body_entered)


## Called by whoever spawns the projectile, right after add_child().
func setup(direction: Vector3, speed: float, projectile_damage: float, lifetime: float, splash: float = 0.0, source: Node = null) -> void:
	velocity = direction.normalized() * speed
	damage = projectile_damage
	_life = lifetime
	splash_radius = splash
	shooter = source
	_align()


func _physics_process(delta: float) -> void:
	if _has_hit:
		return
	_life -= delta
	if _life <= 0.0:
		if explode_on_expire:
			_on_hit(null)
		else:
			queue_free()
		return

	velocity.y -= projectile_gravity * delta
	var from := global_position
	var to := from + velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask)
	if is_instance_valid(shooter) and shooter is CollisionObject3D:
		query.exclude = [(shooter as CollisionObject3D).get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		global_position = hit["position"]
		_on_hit(hit["collider"] as Node)
		return
	global_position = to
	if projectile_gravity != 0.0:
		_align()


func _on_body_entered(body: Node3D) -> void:
	if is_instance_valid(shooter) and body == shooter:
		return
	_on_hit(body)


func _on_hit(body: Node) -> void:
	if _has_hit:
		return
	_has_hit = true
	_apply_impact(body)
	GameManager.spawn_effect(impact_effect, global_position)
	GameManager.play_sfx_3d(impact_sound, global_position)
	queue_free()


## Direct-hit damage. Rocket overrides this with splash damage.
func _apply_impact(body: Node) -> void:
	if _is_valid_target(body):
		body.take_damage(damage, _get_valid_shooter())


func _is_valid_target(body: Node) -> bool:
	if body == null or not is_instance_valid(body) or not body.has_method("take_damage"):
		return false
	if is_instance_valid(shooter) and body == shooter:
		return false
	for group_name in hit_groups:
		if body.is_in_group(group_name):
			return true
	return false


func _get_valid_shooter() -> Node:
	return shooter if is_instance_valid(shooter) else null


func _align() -> void:
	if not align_to_velocity or not is_inside_tree() or velocity.length_squared() < 0.0001:
		return
	var up := Vector3.UP if absf(velocity.normalized().dot(Vector3.UP)) < 0.99 else Vector3.FORWARD
	look_at(global_position + velocity, up)
