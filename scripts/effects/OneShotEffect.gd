class_name OneShotEffect
extends Node3D
## Root script for explosion / impact / spark effect scenes: restarts every particle child,
## plays an optional sound, then frees itself after `lifetime` seconds.

@export var lifetime: float = 2.0
@export var sound: AudioStream


func _ready() -> void:
	for node in find_children("*", "GPUParticles3D", true, false):
		(node as GPUParticles3D).restart()
	for node in find_children("*", "CPUParticles3D", true, false):
		(node as CPUParticles3D).restart()
	if sound != null:
		_play_sound.call_deferred()
	get_tree().create_timer(lifetime, false).timeout.connect(queue_free)


func _play_sound() -> void:
	GameManager.play_sfx_3d(sound, global_position)
