class_name Rocket
extends Bullet
## Explosive projectile. On impact (or when its lifetime runs out) it damages everything in
## `hit_groups` overlapping its SplashArea, with distance falloff and knockback.
## Also used for enemy mortar shells (set hit_groups to ["player"]).

## Area3D with a SphereShape3D; resized to the splash radius. Defaults to child "SplashArea".
## Without one, an instant sphere query using this projectile's collision_mask is used.
@export var splash_area: Area3D
## Used when the weapon/enemy passes a splash radius of 0.
@export var default_splash_radius: float = 3.5
## Damage multiplier at the very edge of the blast.
@export_range(0.0, 1.0) var edge_damage_ratio: float = 0.4
@export var knockback_force: float = 10.0
@export var camera_shake: float = 0.35


func _ready() -> void:
	super()
	explode_on_expire = true
	if splash_area == null:
		splash_area = get_node_or_null("SplashArea") as Area3D


func setup(direction: Vector3, speed: float, projectile_damage: float, lifetime: float, splash: float = 0.0, source: Node = null) -> void:
	super(direction, speed, projectile_damage, lifetime, splash, source)
	if splash_radius <= 0.0:
		splash_radius = default_splash_radius
	_resize_splash_area()


func _apply_impact(direct_hit: Node) -> void:
	var victims: Array[Node] = _get_bodies_in_radius()
	if direct_hit != null and not victims.has(direct_hit):
		victims.append(direct_hit)
	var source := _get_valid_shooter()

	for victim in victims:
		if not _is_valid_target(victim):
			continue
		var falloff := 1.0
		var push_direction := Vector3.UP
		var victim_3d := victim as Node3D
		if victim_3d != null:
			var offset := victim_3d.global_position - global_position
			if victim != direct_hit and splash_radius > 0.0:
				falloff = lerpf(1.0, edge_damage_ratio, clampf(offset.length() / splash_radius, 0.0, 1.0))
			offset.y = 0.0
			if offset.length_squared() > 0.001:
				push_direction = (offset.normalized() + Vector3.UP * 0.3).normalized()
		victim.take_damage(damage * falloff, source)
		if knockback_force > 0.0:
			var impulse := push_direction * knockback_force * falloff
			if victim.has_method("apply_knockback"):
				victim.apply_knockback(impulse)
			elif victim.has_method("add_impulse"):
				victim.add_impulse(impulse)
			elif victim is RigidBody3D:
				(victim as RigidBody3D).apply_central_impulse(impulse)

	var camera := get_viewport().get_camera_3d()
	if camera != null and camera.has_method("add_trauma"):
		camera.add_trauma(camera_shake)


func _get_bodies_in_radius() -> Array[Node]:
	var result: Array[Node] = []
	if splash_area != null:
		for body in splash_area.get_overlapping_bodies():
			result.append(body)
		return result
	var shape := SphereShape3D.new()
	shape.radius = maxf(splash_radius, 0.1)
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = shape
	params.transform = Transform3D(Basis.IDENTITY, global_position)
	params.collision_mask = collision_mask
	for hit in get_world_3d().direct_space_state.intersect_shape(params, 32):
		var collider := hit.get("collider") as Node
		if collider != null and not result.has(collider):
			result.append(collider)
	return result


func _resize_splash_area() -> void:
	if splash_area == null:
		return
	for child in splash_area.get_children():
		var shape_node := child as CollisionShape3D
		if shape_node != null and shape_node.shape is SphereShape3D:
			(shape_node.shape as SphereShape3D).radius = splash_radius
