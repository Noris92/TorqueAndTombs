class_name BaseRoom
extends Node3D
## Base for every dungeon room scene (Start, Maze, Platform, Arena, Exit).
## Tracks UNVISITED / ACTIVE / CLEARED, detects the player through an entrance Area3D,
## keeps the doors at its connections and exposes the four edge sockets the generator uses.

signal player_entered(room: BaseRoom)
signal state_changed(room: BaseRoom, new_state: int)
signal cleared(room: BaseRoom)

enum RoomState { UNVISITED, ACTIVE, CLEARED }

## Socket Marker3D names under `sockets_root`, by grid direction.
## Grid -Y (Vector2i.UP) is North, which is -Z in 3D.
const SOCKET_NAMES: Dictionary = {
	Vector2i.UP: "North",
	Vector2i.RIGHT: "East",
	Vector2i.DOWN: "South",
	Vector2i.LEFT: "West",
}

## Floor footprint (X, Z) in meters. The generator warns if rooms overlap.
@export var room_footprint: Vector2 = Vector2(40.0, 40.0)
## Defaults to the child named "EntranceTrigger".
@export var entrance_trigger: Area3D
## Defaults to the child named "Sockets".
@export var sockets_root: Node3D
## Defaults to the child named "PlayerSpawn".
@export var player_spawn: Marker3D
## Defaults to the child named "NavigationRegion3D".
@export var navigation_region: NavigationRegion3D
## Bake the navmesh after the generator places the room (otherwise bake it in the editor).
@export var bake_navigation_at_runtime: bool = false
## Non-combat rooms count as cleared as soon as the player arrives.
@export var clear_on_enter: bool = true
@export var enter_message: String = ""

var state: RoomState = RoomState.UNVISITED
var grid_position: Vector2i = Vector2i.ZERO
var doors: Array[Door] = []
var neighbors: Array[BaseRoom] = []


func _ready() -> void:
	if entrance_trigger == null:
		entrance_trigger = get_node_or_null("EntranceTrigger") as Area3D
	if sockets_root == null:
		sockets_root = get_node_or_null("Sockets") as Node3D
	if player_spawn == null:
		player_spawn = get_node_or_null("PlayerSpawn") as Marker3D
	if navigation_region == null:
		navigation_region = get_node_or_null("NavigationRegion3D") as NavigationRegion3D
	if entrance_trigger != null:
		entrance_trigger.body_entered.connect(_on_entrance_body_entered)


func _on_entrance_body_entered(body: Node3D) -> void:
	if body.is_in_group("player"):
		_on_player_entered()


## Override in subclasses (ArenaRoom locks its doors here).
func _on_player_entered() -> void:
	player_entered.emit(self)
	if state != RoomState.UNVISITED:
		return
	if enter_message != "":
		GameManager.show_message(enter_message)
	set_state(RoomState.ACTIVE)
	if clear_on_enter:
		mark_cleared()


func set_state(new_state: RoomState) -> void:
	if state == new_state:
		return
	state = new_state
	state_changed.emit(self, state)


func mark_cleared() -> void:
	if state == RoomState.CLEARED:
		return
	set_state(RoomState.CLEARED)
	GameManager.register_room_cleared()
	cleared.emit(self)


func lock_doors() -> void:
	for door in doors:
		if is_instance_valid(door):
			door.lock()


func unlock_doors() -> void:
	for door in doors:
		if is_instance_valid(door):
			door.unlock()


func register_door(door: Door) -> void:
	if door != null and not doors.has(door):
		doors.append(door)


func get_socket(direction: Vector2i) -> Marker3D:
	if sockets_root == null or not SOCKET_NAMES.has(direction):
		return null
	return sockets_root.get_node_or_null(NodePath(String(SOCKET_NAMES[direction]))) as Marker3D


## Removes the wall plug(s) at a socket: children named "Blocker..." or in group "socket_blocker".
func open_socket(direction: Vector2i) -> Marker3D:
	var socket := get_socket(direction)
	if socket == null:
		return null
	for child in socket.get_children():
		if String(child.name).begins_with("Blocker") or child.is_in_group("socket_blocker"):
			socket.remove_child(child)
			child.queue_free()
	return socket


func get_player_spawn_transform() -> Transform3D:
	if player_spawn != null:
		return player_spawn.global_transform
	return global_transform.translated(Vector3.UP)


## Called by DungeonGenerator once every room is placed and connected.
func finalize_room() -> void:
	if bake_navigation_at_runtime and navigation_region != null:
		navigation_region.bake_navigation_mesh(true)


func get_footprint_rect() -> Rect2:
	var center := Vector2(global_position.x, global_position.z)
	return Rect2(center - room_footprint * 0.5, room_footprint)
