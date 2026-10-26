class_name DungeonGenerator
extends Node3D
## Grid / socket based dungeon generator.
## 1. Random-walks a main path (Start -> ... -> Exit) on a grid, then grows side branches.
## 2. Instantiates one room scene per grid cell (the grid is the overlap check).
## 3. For each connection, aligns the child room's entry socket onto the parent's exit socket,
##    removes both wall plugs and places a Door at the threshold.
## 4. Validates room footprints for overlaps, bakes navigation (optional) and places the player.

signal generation_finished(rooms: Array)

enum RoomKind { START, MAZE, PLATFORM, ARENA, TREASURE, EXIT, GAUNTLET }

const NO_CELL: Vector2i = Vector2i(1 << 30, 1 << 30)

@export_group("Room Scenes")
@export var start_room_scene: PackedScene
@export var maze_room_scenes: Array[PackedScene] = []
@export var platform_room_scenes: Array[PackedScene] = []
@export var arena_room_scenes: Array[PackedScene] = []
## Dead-end branch rooms (loot). Falls back to maze rooms if empty.
@export var treasure_room_scenes: Array[PackedScene] = []
## Boss / exit room (root should use ExitRoom.gd). Ignored when exit_room_scenes has entries.
@export var exit_room_scene: PackedScene
## One is picked at random per run (one per boss).
@export var exit_room_scenes: Array[PackedScene] = []
## One-way rooms you can only cross with a boost jump (lava / spike trench). They are placed on
## straight stretches of the main path; pick the list whose jump points the way you travel:
## north = toward -Z (enter South, leave North), east = toward +X, etc.
@export var gauntlet_north_scenes: Array[PackedScene] = []
@export var gauntlet_south_scenes: Array[PackedScene] = []
@export var gauntlet_east_scenes: Array[PackedScene] = []
@export var gauntlet_west_scenes: Array[PackedScene] = []
@export var door_scene: PackedScene

@export_group("Layout")
## Distance between room centers. Rooms should be designed to fit inside one cell.
@export var cell_size: float = 40.0
@export_range(3, 40) var main_path_length: int = 7
@export_range(0, 10) var branch_count: int = 2
@export_range(1, 6) var branch_length: int = 2
## Chance that a side branch ends in a treasure vault (they're meant to be a rare find).
@export_range(0.0, 1.0) var treasure_chance: float = 0.3
@export_range(0.0, 1.0) var arena_chance: float = 0.35
@export_range(0.0, 1.0) var platform_chance: float = 0.3
@export var max_consecutive_arenas: int = 1
@export var min_arena_rooms: int = 1
## Chance that a straight stretch of the main path becomes a gauntlet room.
@export_range(0.0, 1.0) var gauntlet_chance: float = 0.5
## Chance the main path keeps going straight (straight stretches can hold gauntlets).
@export_range(0.0, 1.0) var straight_bias: float = 0.45
## 0 = random every run.
@export var generation_seed: int = 0
@export var generate_on_ready: bool = true
@export var max_layout_attempts: int = 50

@export_group("Player")
## Spawned if the scene has no node in group "player".
@export var player_scene: PackedScene

var rooms: Array[BaseRoom] = []
var _layout: Dictionary = {}        # Vector2i -> RoomKind
var _links: Array = []              # [from_cell: Vector2i, to_cell: Vector2i], parents first
var _room_by_cell: Dictionary = {}  # Vector2i -> BaseRoom
var _gauntlet_heading: Dictionary = {}  # Vector2i -> travel direction through that gauntlet
var _rng := RandomNumberGenerator.new()
var _rooms_root: Node3D
var _doors_root: Node3D


func _ready() -> void:
	_rooms_root = Node3D.new()
	_rooms_root.name = "Rooms"
	add_child(_rooms_root)
	_doors_root = Node3D.new()
	_doors_root.name = "Doors"
	add_child(_doors_root)
	if generate_on_ready:
		# Deferred so the rest of the level (player, HUD, camera) is ready first.
		generate.call_deferred()


func generate() -> void:
	clear()
	if start_room_scene == null or (exit_room_scene == null and exit_room_scenes.is_empty()):
		push_error("DungeonGenerator: assign start_room_scene and an exit room scene.")
		return
	if maze_room_scenes.is_empty() and platform_room_scenes.is_empty() and arena_room_scenes.is_empty():
		push_error("DungeonGenerator: assign at least one maze, platform or arena room scene.")
		return

	if generation_seed != 0:
		_rng.seed = generation_seed
	else:
		_rng.randomize()

	var success := false
	for _attempt in max_layout_attempts:
		if _build_layout():
			success = true
			break
	if not success:
		push_error("DungeonGenerator: could not build a layout. Try a shorter main_path_length.")
		return

	_instantiate_rooms()
	_connect_rooms()
	_validate_overlaps()
	for room in rooms:
		room.finalize_room()
	GameManager.set_room_grid(_rooms_root.global_position, cell_size)
	_place_player()
	generation_finished.emit(rooms)


func clear() -> void:
	for child in _rooms_root.get_children():
		child.queue_free()
	for child in _doors_root.get_children():
		child.queue_free()
	rooms.clear()
	_layout.clear()
	_links.clear()
	_room_by_cell.clear()


func get_room_at(cell: Vector2i) -> BaseRoom:
	return _room_by_cell.get(cell) as BaseRoom


# --------------------------------------------------------------------------
# Layout
# --------------------------------------------------------------------------

func _build_layout() -> bool:
	_layout.clear()
	_links.clear()

	# Main path
	var path: Array[Vector2i] = [Vector2i.ZERO]
	_layout[Vector2i.ZERO] = RoomKind.START
	for _i in range(1, main_path_length):
		var current := path[path.size() - 1]
		var heading := current - path[path.size() - 2] if path.size() > 1 else Vector2i.ZERO
		var next := _random_free_neighbor(current, heading)
		if next == NO_CELL:
			return false
		_layout[next] = RoomKind.MAZE
		_links.append([current, next])
		path.append(next)
	_layout[path[path.size() - 1]] = RoomKind.EXIT

	# Room types along the main path
	var arena_streak := 0
	var arena_count := 0
	for i in range(1, path.size() - 1):
		var kind := _roll_kind(arena_streak)
		if kind == RoomKind.ARENA:
			arena_streak += 1
			arena_count += 1
		else:
			arena_streak = 0
		_layout[path[i]] = kind
	if not arena_room_scenes.is_empty() and path.size() > 2:
		var guard := 0
		while arena_count < min_arena_rooms and guard < 20:
			guard += 1
			var cell := path[_rng.randi_range(1, path.size() - 2)]
			if _layout[cell] != RoomKind.ARENA:
				_layout[cell] = RoomKind.ARENA
				arena_count += 1

	# Gauntlets on straight pass-through cells (entry and exit on opposite sides)
	_gauntlet_heading.clear()
	for i in range(1, path.size() - 1):
		var heading := path[i] - path[i - 1]
		if heading != path[i + 1] - path[i] or _layout[path[i]] == RoomKind.ARENA:
			continue
		if not _gauntlet_pool(heading).is_empty() and _rng.randf() < gauntlet_chance:
			_layout[path[i]] = RoomKind.GAUNTLET
			_gauntlet_heading[path[i]] = heading

	# Branches (never from the start, exit or a gauntlet room, which only has two exits)
	if path.size() > 2:
		var branch_origins: Array[Vector2i] = []
		for i in range(1, path.size() - 1):
			if not _is_gauntlet(_layout[path[i]]):
				branch_origins.append(path[i])
		for _b in branch_count:
			if branch_origins.is_empty():
				break
			var current := branch_origins[_rng.randi_range(0, branch_origins.size() - 1)]
			for step in branch_length:
				var next := _random_free_neighbor(current)
				if next == NO_CELL:
					break
				var is_last := step == branch_length - 1
				var treasure := is_last and not treasure_room_scenes.is_empty() and _rng.randf() < treasure_chance
				_layout[next] = RoomKind.TREASURE if treasure else _roll_kind(0)
				_links.append([current, next])
				current = next
	return true


func _roll_kind(arena_streak: int) -> RoomKind:
	var roll := _rng.randf()
	if not arena_room_scenes.is_empty() and arena_streak < max_consecutive_arenas and roll < arena_chance:
		return RoomKind.ARENA
	if not platform_room_scenes.is_empty() and roll < arena_chance + platform_chance:
		return RoomKind.PLATFORM
	return RoomKind.MAZE


func _is_gauntlet(kind: RoomKind) -> bool:
	return kind == RoomKind.GAUNTLET


func _gauntlet_pool(heading: Vector2i) -> Array[PackedScene]:
	match heading:
		Vector2i.UP:
			return gauntlet_north_scenes
		Vector2i.DOWN:
			return gauntlet_south_scenes
		Vector2i.RIGHT:
			return gauntlet_east_scenes
		_:
			return gauntlet_west_scenes


func _random_free_neighbor(cell: Vector2i, preferred: Vector2i = Vector2i.ZERO) -> Vector2i:
	if preferred != Vector2i.ZERO and not _layout.has(cell + preferred) and _rng.randf() < straight_bias:
		return cell + preferred
	for direction in _shuffled_directions():
		var neighbor := cell + direction
		if not _layout.has(neighbor):
			return neighbor
	return NO_CELL


func _shuffled_directions() -> Array[Vector2i]:
	var directions: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
	for i in range(directions.size() - 1, 0, -1):
		var j := _rng.randi_range(0, i)
		var temp := directions[i]
		directions[i] = directions[j]
		directions[j] = temp
	return directions


# --------------------------------------------------------------------------
# Instantiation
# --------------------------------------------------------------------------

func _instantiate_rooms() -> void:
	for cell in _layout:
		var kind: RoomKind = _layout[cell]
		var scene := _pick_scene(kind, cell)
		if scene == null:
			push_error("DungeonGenerator: no scene for room kind %s." % RoomKind.keys()[kind])
			continue
		var room := scene.instantiate() as BaseRoom
		if room == null:
			push_error("DungeonGenerator: room scene roots must use BaseRoom.gd or a subclass.")
			continue
		room.name = "%s_%d_%d" % [RoomKind.keys()[kind], cell.x, cell.y]
		room.grid_position = cell
		room.position = Vector3(cell.x * cell_size, 0.0, cell.y * cell_size)
		_rooms_root.add_child(room)
		if room.room_footprint.x > cell_size or room.room_footprint.y > cell_size:
			push_warning("DungeonGenerator: %s footprint %s is bigger than cell_size %.1f." % [room.name, room.room_footprint, cell_size])
		rooms.append(room)
		_room_by_cell[cell] = room


func _pick_scene(kind: RoomKind, cell: Vector2i) -> PackedScene:
	match kind:
		RoomKind.START:
			return start_room_scene
		RoomKind.EXIT:
			if not exit_room_scenes.is_empty():
				# Random runs ask GameManager, which never repeats the previous run's boss.
				# Seeded runs stay reproducible.
				var index := _rng.randi_range(0, exit_room_scenes.size() - 1)
				if generation_seed == 0:
					index = GameManager.pick_boss_index(exit_room_scenes.size())
				return exit_room_scenes[index]
			return exit_room_scene
		RoomKind.GAUNTLET:
			return _pick_from(_gauntlet_pool(_gauntlet_heading.get(cell, Vector2i.UP)), maze_room_scenes)
		RoomKind.ARENA:
			return _pick_from(arena_room_scenes, maze_room_scenes)
		RoomKind.PLATFORM:
			return _pick_from(platform_room_scenes, maze_room_scenes)
		RoomKind.TREASURE:
			return _pick_from(treasure_room_scenes, maze_room_scenes)
		_:
			return _pick_from(maze_room_scenes, platform_room_scenes)


func _pick_from(primary: Array[PackedScene], fallback: Array[PackedScene]) -> PackedScene:
	var pool := primary if not primary.is_empty() else fallback
	if pool.is_empty():
		pool = arena_room_scenes
	if pool.is_empty():
		return null
	return pool[_rng.randi_range(0, pool.size() - 1)]


func _connect_rooms() -> void:
	# _links lists parents before children, so each room is aligned after the room it hangs off.
	for link in _links:
		var from_cell: Vector2i = link[0]
		var to_cell: Vector2i = link[1]
		var room_a := get_room_at(from_cell)
		var room_b := get_room_at(to_cell)
		if room_a == null or room_b == null:
			continue
		var direction := to_cell - from_cell
		var socket_a := room_a.get_socket(direction)
		var socket_b := room_b.get_socket(-direction)
		if socket_a == null or socket_b == null:
			push_warning("DungeonGenerator: %s or %s is missing a socket (North/East/South/West)." % [room_a.name, room_b.name])
		else:
			var correction := socket_a.global_position - socket_b.global_position
			if correction.length() > cell_size * 0.25:
				push_warning("DungeonGenerator: large socket correction (%.1f m) on %s; check socket positions." % [correction.length(), room_b.name])
			room_b.global_position += correction

		room_a.open_socket(direction)
		room_b.open_socket(-direction)
		room_a.neighbors.append(room_b)
		room_b.neighbors.append(room_a)

		if door_scene != null and socket_a != null:
			var door := door_scene.instantiate() as Door
			if door == null:
				push_warning("DungeonGenerator: door_scene root must use Door.gd.")
				continue
			# Place the door BEFORE it enters the tree: its gate is a physics body that keeps
			# whatever orientation it had when it was added, so rotating it afterwards left the
			# bars of East/West doors sticking out across the passage.
			door.transform = _doors_root.global_transform.affine_inverse() * socket_a.global_transform
			_doors_root.add_child(door)
			room_a.register_door(door)
			room_b.register_door(door)


func _validate_overlaps() -> void:
	for i in rooms.size():
		var rect_a := rooms[i].get_footprint_rect().grow(-0.05)
		for j in range(i + 1, rooms.size()):
			if rect_a.intersects(rooms[j].get_footprint_rect().grow(-0.05)):
				push_warning("DungeonGenerator: %s overlaps %s. Reduce room_footprint or increase cell_size." % [rooms[i].name, rooms[j].name])


func _place_player() -> void:
	var start_room := get_room_at(Vector2i.ZERO)
	if start_room == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player == null and player_scene != null:
		player = player_scene.instantiate() as Node3D
		get_parent().add_child(player)
	if player == null:
		push_warning("DungeonGenerator: no player found or player_scene assigned.")
		return
	var spawn := start_room.get_player_spawn_transform()
	if player.has_method("teleport_to"):
		player.teleport_to(spawn)
	else:
		player.global_transform = spawn
