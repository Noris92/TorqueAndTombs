class_name WaveEnemyOption
extends Resource
## One enemy type a WaveSpawner may roll when it builds random waves.

@export var enemy_scene: PackedScene
## Threat points this enemy uses from the wave's budget.
@export var cost: float = 2.0
## Relative chance of being picked among the affordable options.
@export var weight: float = 1.0
## Only appears from this depth level on (0 = first run).
@export var min_depth: int = 0
