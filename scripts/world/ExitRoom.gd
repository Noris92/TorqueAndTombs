class_name ExitRoom
extends ArenaRoom
## Boss / exit room. If it has waves (a boss fight) the teleporter only activates once they're
## cleared, and a heavy pile of scrap drops. With no waves it's simply an open exit.

@export var teleporter: Teleporter
@export var heavy_scrap_value: int = 60


func _ready() -> void:
	super()
	if teleporter == null:
		teleporter = get_node_or_null("Teleporter") as Teleporter
	if teleporter != null and wave_spawner != null and wave_spawner.has_waves():
		teleporter.deactivate()


func _complete_arena() -> void:
	super()
	GameManager.register_boss_defeated()
	if teleporter != null:
		teleporter.activate()
	var drop_point := teleporter.global_position if teleporter != null else global_position
	ScrapPickup.spawn_burst(scrap_pickup_scene, get_tree().current_scene, drop_point + Vector3.UP, heavy_scrap_value, 12)
