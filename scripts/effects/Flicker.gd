extends Light3D
## Gentle torch flicker.

@export var flicker_amount: float = 0.25
@export var flicker_speed: float = 9.0

var _base_energy: float = 1.0
var _time: float = 0.0


func _ready() -> void:
	_base_energy = light_energy
	_time = randf() * 100.0


func _process(delta: float) -> void:
	_time += delta * flicker_speed
	var noise := sin(_time) * 0.5 + sin(_time * 2.7 + 1.3) * 0.3 + sin(_time * 5.1) * 0.2
	light_energy = _base_energy * (1.0 + noise * flicker_amount)
