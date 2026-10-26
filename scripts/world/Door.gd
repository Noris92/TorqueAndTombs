class_name Door
extends Node3D
## Lockable door / portcullis placed at room connections.
## Model the gate in its CLOSED position; it slides by `open_offset` (into the floor) when open.
## The door's -Z should point out of the room it was placed from (it copies the socket's transform).

signal lock_state_changed(is_locked: bool)

## The moving part. An AnimatableBody3D is best so it pushes things out of the way.
## Defaults to the child named "Gate".
@export var gate: Node3D
@export var open_offset: Vector3 = Vector3(0.0, -4.5, 0.0)
@export var move_duration: float = 0.45
@export var start_locked: bool = false
## Optional: if it has "lock" / "unlock" animations they're played instead of the tween.
@export var animation_player: AnimationPlayer
@export var audio_player: AudioStreamPlayer3D
@export var lock_sound: AudioStream
@export var unlock_sound: AudioStream
## Shown only while locked (e.g. a red light or glowing runes).
@export var locked_indicator: Node3D

var is_locked: bool = false
var _closed_position: Vector3 = Vector3.ZERO
var _tween: Tween


func _ready() -> void:
	if gate == null:
		gate = get_node_or_null("Gate") as Node3D
	if gate != null:
		_closed_position = gate.position
	is_locked = start_locked
	_apply_state(true)


func lock() -> void:
	_set_locked(true)


func unlock() -> void:
	_set_locked(false)


func _set_locked(value: bool) -> void:
	if value == is_locked:
		return
	is_locked = value
	_apply_state(false)
	if audio_player != null:
		var sound := lock_sound if is_locked else unlock_sound
		if sound != null:
			audio_player.stream = sound
			audio_player.play()
	lock_state_changed.emit(is_locked)


func _apply_state(instant: bool) -> void:
	if locked_indicator != null:
		locked_indicator.visible = is_locked
	# The gate collider is taller than the bars so locked doors can't be jumped;
	# switch it off while open so it doesn't stick up out of the floor.
	if gate != null:
		for child in gate.get_children():
			if child is CollisionShape3D:
				child.set_deferred("disabled", not is_locked)
	var animation_name := "lock" if is_locked else "unlock"
	if not instant and animation_player != null and animation_player.has_animation(animation_name):
		animation_player.play(animation_name)
		return
	if gate == null:
		return
	var target := _closed_position if is_locked else _closed_position + open_offset
	if _tween != null:
		_tween.kill()
	if instant:
		gate.position = target
		return
	_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_tween.tween_property(gate, "position", target, move_duration)
