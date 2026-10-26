class_name ScrapPickup
extends Node3D
## Scrap currency pickup. Pops out in a little arc, settles on the floor, then gets pulled
## toward the player and is collected on contact (distance check, no physics setup needed).

@export var value: int = 1
@export var collect_radius: float = 1.6
## Minimum pull range; the player's magnet_range stat is used when it's bigger.
@export var magnet_range: float = 7.0
@export var magnet_speed: float = 22.0
## Can't be collected for this long after spawning (so the pop arc is visible).
@export var pickup_delay: float = 0.35
@export var spin_speed: float = 3.0
@export var bob_height: float = 0.15
@export var lifetime: float = 60.0
## Spun and bobbed. Defaults to the child named "Visual".
@export var visual: Node3D
@export var pickup_sound: AudioStream
@export_flags_3d_physics var ground_mask: int = 1

var _velocity: Vector3 = Vector3.ZERO
var _age: float = 0.0
var _grounded: bool = true
var _magnetised: bool = false
var _collected: bool = false


## Spawns `total_value` scrap split into up to `max_pieces` pickups that burst outward.
static func spawn_burst(scene: PackedScene, parent: Node, origin: Vector3, total_value: int, max_pieces: int = 6) -> void:
	if scene == null or parent == null or total_value <= 0:
		return
	var pieces := clampi(total_value, 1, maxi(max_pieces, 1))
	var base_value := floori(float(total_value) / pieces)
	var remainder := total_value - base_value * pieces
	for i in pieces:
		var pickup := scene.instantiate() as ScrapPickup
		if pickup == null:
			push_warning("ScrapPickup.spawn_burst: scene root must use ScrapPickup.gd.")
			return
		pickup.value = base_value + (1 if i < remainder else 0)
		parent.add_child(pickup)
		pickup.global_position = origin + Vector3.UP * 0.5
		var angle := randf() * TAU
		var spread := randf_range(2.0, 5.0)
		pickup.launch(Vector3(cos(angle) * spread, randf_range(5.0, 8.0), sin(angle) * spread))


func _ready() -> void:
	if visual == null:
		visual = get_node_or_null("Visual") as Node3D


func launch(initial_velocity: Vector3) -> void:
	_velocity = initial_velocity
	_grounded = false


func _physics_process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		return
	_spin(delta)

	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null and _age >= pickup_delay:
		var to_player := player.global_position + Vector3.UP * 0.5 - global_position
		var distance := to_player.length()
		if distance <= collect_radius:
			_collect()
			return
		# Scrap Magnet raises PlayerData.magnet_range; Scrap Vacuum pulls in everything in your room.
		var vacuum := PlayerData.has_flag("scrap_vacuum") and GameManager.same_room(global_position, player.global_position)
		if _magnetised or vacuum or distance <= maxf(magnet_range, PlayerData.magnet_range):
			_magnetised = true
			global_position += to_player.normalized() * minf(magnet_speed * delta, distance)
			return

	if not _grounded:
		_fall(delta)
	elif visual != null:
		visual.position.y = sin(_age * 3.0) * bob_height


func _fall(delta: float) -> void:
	_velocity.y -= 20.0 * delta
	var from := global_position
	var to := from + _velocity * delta
	var query := PhysicsRayQueryParameters3D.create(from, to + Vector3.DOWN * 0.3, ground_mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var hit_position: Vector3 = hit["position"]
		var hit_normal: Vector3 = hit["normal"]
		if hit_normal.y > 0.6 and _velocity.y <= 0.0:
			_grounded = true
			global_position = hit_position + Vector3.UP * 0.4
		else:
			_velocity = _velocity.bounce(hit_normal) * 0.3
		return
	global_position = to
	if _age > 4.0:
		_grounded = true


func _spin(delta: float) -> void:
	if visual != null:
		visual.rotate_y(spin_speed * delta)


func _collect() -> void:
	if _collected:
		return
	_collected = true
	GameManager.add_run_scrap(value)
	GameManager.play_sfx_3d(pickup_sound, global_position)
	queue_free()
