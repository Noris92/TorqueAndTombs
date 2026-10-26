extends Node3D
## Rotates this node continuously (teleporter rings, menu showcase, pickups).

## Radians per second around each local axis.
@export var speed: Vector3 = Vector3(0.0, 1.0, 0.0)
## Optional vertical bob.
@export var bob_height: float = 0.0
@export var bob_speed: float = 2.0

var _base_y: float = 0.0
var _time: float = 0.0


func _ready() -> void:
	_base_y = position.y


func _process(delta: float) -> void:
	_time += delta
	rotate_object_local(Vector3.RIGHT, speed.x * delta)
	rotate_object_local(Vector3.UP, speed.y * delta)
	rotate_object_local(Vector3.BACK, speed.z * delta)
	if bob_height != 0.0:
		position.y = _base_y + sin(_time * bob_speed) * bob_height
