extends Light3D
## Fades a light out after it appears (explosion flashes).

@export var duration: float = 0.5


func _ready() -> void:
	var tween := create_tween()
	tween.tween_property(self, "light_energy", 0.0, duration).set_ease(Tween.EASE_IN)
