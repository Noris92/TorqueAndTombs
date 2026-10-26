class_name SpikeTrap
extends Node3D
## Spike trap state machine: RETRACTED -> WARNING (telegraph) -> EXTENDED -> RETRACTED.
## PERIODIC cycles forever, TRIGGERED fires when the player enters `trigger_area`.
## While extended, damages and slows anything in `hurt_area`.

signal state_changed(new_state: int)

enum TrapMode { PERIODIC, TRIGGERED, ALWAYS_EXTENDED }
enum TrapState { RETRACTED, WARNING, EXTENDED }

@export var mode: TrapMode = TrapMode.PERIODIC
@export var damage: float = 15.0
@export_range(0.05, 1.0) var slow_factor: float = 0.4
@export var slow_duration: float = 1.0
## Minimum time between hits on the same body.
@export var damage_interval: float = 0.6
@export var damage_enemies: bool = true

@export_group("Timing")
@export var retracted_time: float = 2.0
@export var warning_time: float = 0.5
@export var extended_time: float = 1.2
## Offsets the periodic cycle so rows of traps can ripple.
@export var start_delay: float = 0.0
## TRIGGERED mode: time before the trap can fire again.
@export var trigger_rearm_time: float = 1.5

@export_group("Nodes")
## Defaults to the child named "HurtArea".
@export var hurt_area: Area3D
## Defaults to the child named "TriggerArea" (TRIGGERED mode only).
@export var trigger_area: Area3D
## Spike mesh, modelled in the EXTENDED position. Defaults to the child named "Spikes".
@export var spikes: Node3D
@export var retracted_offset: Vector3 = Vector3(0.0, -0.8, 0.0)
@export var warning_offset: Vector3 = Vector3(0.0, -0.5, 0.0)
@export var move_time: float = 0.08
@export var audio_player: AudioStreamPlayer3D
@export var warning_sound: AudioStream
@export var extend_sound: AudioStream

var state: TrapState = TrapState.RETRACTED
var _timer: float = 0.0
var _extended_position: Vector3 = Vector3.ZERO
var _last_hit_ms: Dictionary = {}
var _tween: Tween


func _ready() -> void:
	if hurt_area == null:
		hurt_area = get_node_or_null("HurtArea") as Area3D
	if trigger_area == null:
		trigger_area = get_node_or_null("TriggerArea") as Area3D
	if spikes == null:
		spikes = get_node_or_null("Spikes") as Node3D
	if spikes != null:
		_extended_position = spikes.position
	if trigger_area != null:
		trigger_area.body_entered.connect(_on_trigger_body_entered)

	if mode == TrapMode.ALWAYS_EXTENDED:
		_set_state(TrapState.EXTENDED, true)
	else:
		_set_state(TrapState.RETRACTED, true)
		_timer = (retracted_time if mode == TrapMode.PERIODIC else 0.0) + start_delay


func _physics_process(delta: float) -> void:
	if mode != TrapMode.ALWAYS_EXTENDED:
		_timer -= delta
		match state:
			TrapState.RETRACTED:
				if mode == TrapMode.PERIODIC and _timer <= 0.0:
					_set_state(TrapState.WARNING)
			TrapState.WARNING:
				if _timer <= 0.0:
					_set_state(TrapState.EXTENDED)
			TrapState.EXTENDED:
				if _timer <= 0.0:
					_set_state(TrapState.RETRACTED)
	if state == TrapState.EXTENDED:
		_damage_overlapping()


func _on_trigger_body_entered(body: Node3D) -> void:
	if mode == TrapMode.TRIGGERED and state == TrapState.RETRACTED and _timer <= 0.0 and body.is_in_group("player"):
		_set_state(TrapState.WARNING)


func _set_state(new_state: TrapState, instant: bool = false) -> void:
	state = new_state
	match new_state:
		TrapState.RETRACTED:
			_timer = retracted_time if mode == TrapMode.PERIODIC else trigger_rearm_time
			_move_spikes(retracted_offset, instant)
		TrapState.WARNING:
			_timer = warning_time
			_move_spikes(warning_offset, instant)
			_play(warning_sound)
		TrapState.EXTENDED:
			_timer = extended_time
			_move_spikes(Vector3.ZERO, instant)
			_play(extend_sound)
	state_changed.emit(state)


func _damage_overlapping() -> void:
	if hurt_area == null:
		return
	var now := Time.get_ticks_msec()
	for body in hurt_area.get_overlapping_bodies():
		var is_valid := body.is_in_group("player") or (damage_enemies and body.is_in_group("enemies"))
		if not is_valid or not body.has_method("take_damage"):
			continue
		var id := body.get_instance_id()
		if now - int(_last_hit_ms.get(id, -100000)) < int(damage_interval * 1000.0):
			continue
		_last_hit_ms[id] = now
		body.take_damage(damage, self)
		if body.has_method("apply_slow"):
			body.apply_slow(slow_factor, slow_duration)


func _move_spikes(offset: Vector3, instant: bool) -> void:
	if spikes == null:
		return
	if _tween != null:
		_tween.kill()
	var target := _extended_position + offset
	if instant:
		spikes.position = target
		return
	_tween = create_tween()
	_tween.tween_property(spikes, "position", target, move_time)


func _play(stream: AudioStream) -> void:
	if audio_player != null and stream != null:
		audio_player.stream = stream
		audio_player.play()
