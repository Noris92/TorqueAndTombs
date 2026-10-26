class_name SpawnGroup
extends Resource
## "Spawn `count` of this enemy scene" — used inside WaveData.

@export var enemy_scene: PackedScene
@export_range(1, 50) var count: int = 3
