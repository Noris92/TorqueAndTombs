class_name WaveData
extends Resource
## One combat wave for a WaveSpawner: a list of SpawnGroups plus timing.

@export var groups: Array[SpawnGroup] = []
## Pause before the first enemy of this wave appears.
@export var delay_before_wave: float = 1.5
## Seconds between individual enemy spawns.
@export var spawn_interval: float = 0.6
@export var shuffle_spawn_order: bool = true


func get_total_enemies() -> int:
	var total := 0
	for group in groups:
		if group != null:
			total += group.count
	return total
