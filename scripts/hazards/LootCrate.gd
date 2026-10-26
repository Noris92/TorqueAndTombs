class_name LootCrate
extends RigidBody3D
## Breakable crate. Shoot it, blast it, or drive through it and it shatters into scrap.
## The crate doesn't physically block the player (keep the Player layer out of its mask and
## the Breakables layer out of the player's mask); a TouchArea smashes it on contact instead,
## so driving through crates never costs momentum.

signal broken(crate: LootCrate)

@export var max_health: float = 20.0
@export var scrap_value: int = 8
@export var scrap_pickup_scene: PackedScene
@export var break_effect: PackedScene
@export var break_sound: AudioStream
@export var hit_sound: AudioStream
## Optional extra drop (health kit, rare part...).
@export var bonus_drop_scene: PackedScene
@export_range(0.0, 1.0) var bonus_drop_chance: float = 0.0
## Area3D (mask: Player) that breaks the crate when the buggy touches it. Defaults to "TouchArea".
@export var touch_area: Area3D

var current_health: float = 0.0
var _broken: bool = false


func _ready() -> void:
	add_to_group("breakable")
	current_health = max_health
	if touch_area == null:
		touch_area = get_node_or_null("TouchArea") as Area3D
	if touch_area != null:
		touch_area.body_entered.connect(_on_touch_body_entered)


func _on_touch_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		break_crate()


func take_damage(amount: float, _source: Node = null) -> void:
	if _broken:
		return
	current_health -= amount
	GameManager.play_sfx_3d(hit_sound, global_position)
	if current_health <= 0.0:
		break_crate()


func break_crate() -> void:
	if _broken:
		return
	_broken = true
	var scene_root := get_tree().current_scene
	GameManager.spawn_effect(break_effect, global_position)
	GameManager.play_sfx_3d(break_sound, global_position)
	ScrapPickup.spawn_burst(scrap_pickup_scene, scene_root, global_position, scrap_value)
	if bonus_drop_scene != null and randf() < bonus_drop_chance:
		var bonus := bonus_drop_scene.instantiate() as Node3D
		if bonus != null:
			scene_root.add_child.call_deferred(bonus)
			bonus.set_deferred("global_position", global_position + Vector3.UP * 0.5)
	broken.emit(self)
	queue_free()
