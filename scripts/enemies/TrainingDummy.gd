class_name TrainingDummy
extends StaticBody3D
## Stationary target for the tutorial (Zone D). In the "enemies" group so the turret locks on.

signal died(dummy: TrainingDummy)

@export var max_health: float = 40.0
@export var scrap_reward: int = 3
@export var scrap_pickup_scene: PackedScene
@export var destroy_effect: PackedScene
@export var hit_sound: AudioStream

var current_health: float = 0.0
var _destroyed: bool = false


func _ready() -> void:
	add_to_group("enemies")
	current_health = max_health


func take_damage(amount: float, _source: Node = null) -> void:
	if _destroyed:
		return
	current_health -= amount
	GameManager.play_sfx_3d(hit_sound, global_position)
	if current_health <= 0.0:
		_destroyed = true
		GameManager.spawn_effect(destroy_effect, global_position)
		ScrapPickup.spawn_burst(scrap_pickup_scene, get_tree().current_scene, global_position, scrap_reward)
		ComboTracker.register_kill()
		died.emit(self)
		queue_free()


func is_alive() -> bool:
	return not _destroyed
