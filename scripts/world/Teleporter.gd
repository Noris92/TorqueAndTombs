class_name Teleporter
extends Area3D
## Drive into it to leave the level. Used in the Exit room (back to the Garage), in the
## Garage (start a new run) and at the end of the tutorial.

enum Destination { GARAGE, NEW_RUN, MAIN_MENU, TUTORIAL_COMPLETE }

@export var destination: Destination = Destination.GARAGE
@export var active: bool = true
## For GARAGE: counts as a successful run (pays the run bonus).
@export var counts_as_success: bool = true
## Shown while active (glow, particles). Defaults to the child named "ActiveVisual".
@export var active_visual: Node3D
## Shown while inactive. Defaults to the child named "InactiveVisual".
@export var inactive_visual: Node3D
@export var activate_sound: AudioStream
@export var teleport_sound: AudioStream
@export var activate_message: String = "The teleporter hums to life!"

var _used: bool = false


func _ready() -> void:
	if active_visual == null:
		active_visual = get_node_or_null("ActiveVisual") as Node3D
	if inactive_visual == null:
		inactive_visual = get_node_or_null("InactiveVisual") as Node3D
	body_entered.connect(_on_body_entered)
	_update_visuals()


func activate() -> void:
	if active:
		return
	active = true
	_update_visuals()
	GameManager.play_sfx_3d(activate_sound, global_position)
	if activate_message != "":
		GameManager.show_message(activate_message)
	# The player may already be standing on it.
	for body in get_overlapping_bodies():
		_on_body_entered(body)


func deactivate() -> void:
	active = false
	_update_visuals()


func _on_body_entered(body: Node3D) -> void:
	if not active or _used or not body.is_in_group("player"):
		return
	_used = true
	GameManager.play_sfx_3d(teleport_sound, global_position)
	match destination:
		Destination.GARAGE:
			GameManager.end_run(counts_as_success)
		Destination.NEW_RUN:
			GameManager.start_run()
		Destination.MAIN_MENU:
			GameManager.go_to_main_menu()
		Destination.TUTORIAL_COMPLETE:
			GameManager.complete_tutorial()


func _update_visuals() -> void:
	if active_visual != null:
		active_visual.visible = active
	if inactive_visual != null:
		inactive_visual.visible = not active
