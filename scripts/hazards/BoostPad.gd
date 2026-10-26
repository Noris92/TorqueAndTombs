class_name BoostPad
extends Area3D
## Launches vehicles along the pad's forward direction (-Z, the blue gizmo arrow points
## the opposite way, so rotate until -Z faces where you want to go). Plays nitro SFX.

@export var boost_speed: float = 34.0
## Upward kick, for pads placed right before a ramp or gap.
@export var vertical_speed: float = 0.0
## Boost meter refilled on use.
@export var refill_boost: float = 15.0
@export var cooldown: float = 0.3
@export var nitro_sound: AudioStream
@export var audio_player: AudioStreamPlayer3D
@export var effect: GPUParticles3D

var _last_trigger_ms: Dictionary = {}


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if not body.has_method("apply_boost_pad"):
		return
	var now := Time.get_ticks_msec()
	var id := body.get_instance_id()
	if now - int(_last_trigger_ms.get(id, -100000)) < int(cooldown * 1000.0):
		return
	_last_trigger_ms[id] = now

	body.apply_boost_pad(-global_transform.basis.z, boost_speed, vertical_speed)
	if refill_boost > 0.0 and body.has_method("add_boost"):
		body.add_boost(refill_boost)

	if audio_player != null:
		if nitro_sound != null:
			audio_player.stream = nitro_sound
		audio_player.play()
	else:
		GameManager.play_sfx_3d(nitro_sound, global_position)
	if effect != null:
		effect.restart()
