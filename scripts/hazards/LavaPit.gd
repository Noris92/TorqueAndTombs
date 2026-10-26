class_name LavaPit
extends Area3D
## Area3D just above a lava surface (also works as a bottomless-pit kill zone).
## The buggy takes heavy fire damage and respawns at its last safe ground position.
## Jump it with enough speed (boost pad + ramp) and you never touch it.

@export var damage: float = 30.0
@export var instant_kill: bool = false
@export var respawn_delay: float = 0.75
## > 0: buggies moving faster than this only get scorched (half damage, no respawn).
@export var skim_speed: float = 0.0
@export var kill_enemies: bool = true
@export var splash_effect: PackedScene
@export var splash_sound: AudioStream


func _ready() -> void:
	add_to_group("unsafe_ground")
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_burn_player(body)
	elif kill_enemies and body.is_in_group("enemies"):
		if body.has_method("die"):
			body.die(false)
		elif body.has_method("take_damage"):
			body.take_damage(99999.0, self)


func _burn_player(body: Node3D) -> void:
	GameManager.spawn_effect(splash_effect, body.global_position)
	GameManager.play_sfx_3d(splash_sound, body.global_position)
	if not body.has_method("take_damage"):
		return
	if instant_kill:
		body.take_damage(99999.0, self, true)
		return
	if skim_speed > 0.0 and body.has_method("get_speed") and body.get_speed() >= skim_speed:
		body.take_damage(damage * 0.5, self, true)
		return
	body.take_damage(damage, self, true)
	if body.has_method("respawn_at_safe_position"):
		body.respawn_at_safe_position(respawn_delay)
