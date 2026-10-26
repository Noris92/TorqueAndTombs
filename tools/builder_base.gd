extends Node
## Shared helpers for the Torque & Tombs project generator.
## Run it with tools/build.gd (see README.md). It (re)creates every model, scene and data file.

const LowPolyMesh := preload("res://tools/low_poly_mesh.gd")
const AudioGen := preload("res://tools/audio_gen.gd")
const SCRIPTS := "res://scripts/"

# Physics layer bits (see Project Settings > Layer Names).
const L_WORLD := 1
const L_PLAYER := 2
const L_ENEMY := 4
const L_PLAYER_PROJ := 8
const L_ENEMY_PROJ := 16
const L_TRIGGER := 32
const L_BREAKABLE := 64

const C := {
	"stone": Color(0.56, 0.47, 0.36), "stone_dark": Color(0.33, 0.29, 0.25), "stone_light": Color(0.7, 0.62, 0.48),
	"floor": Color(0.44, 0.38, 0.30), "grout": Color(0.15, 0.13, 0.11), "sand": Color(0.72, 0.6, 0.42),
	"moss": Color(0.33, 0.42, 0.22), "orange": Color(0.95, 0.48, 0.1), "orange_dark": Color(0.68, 0.3, 0.07),
	"metal": Color(0.34, 0.35, 0.38), "metal_dark": Color(0.16, 0.16, 0.18), "chrome": Color(0.8, 0.8, 0.83),
	"tire": Color(0.07, 0.07, 0.08), "red": Color(0.72, 0.13, 0.1), "red_dark": Color(0.38, 0.07, 0.06),
	"purple": Color(0.45, 0.22, 0.6), "purple_dark": Color(0.24, 0.12, 0.32), "bone": Color(0.9, 0.86, 0.74),
	"wood": Color(0.58, 0.38, 0.19), "wood_dark": Color(0.36, 0.22, 0.11), "gold": Color(0.92, 0.7, 0.22),
	"white": Color(0.93, 0.93, 0.9), "concrete": Color(0.47, 0.47, 0.49), "concrete_dark": Color(0.3, 0.3, 0.32),
	"yellow": Color(0.96, 0.78, 0.14), "blue": Color(0.2, 0.36, 0.72), "teal": Color(0.12, 0.45, 0.5),
	"black": Color(0.05, 0.05, 0.06), "green": Color(0.24, 0.5, 0.26),
}

var mats: Dictionary = {}
var meshes: Dictionary = {}
var sounds: Dictionary = {}
var scenes: Dictionary = {}
var error_count: int = 0


func fail(message: String) -> void:
	error_count += 1
	push_error(message)
	printerr("BUILD ERROR: ", message)


# --------------------------------------------------------------------------
# Saving
# --------------------------------------------------------------------------

func ensure_dir(dir_path: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_path))


## Saves `res` and returns the copy loaded back from disk. Always use the returned resource:
## it has a real file path, so anything that references it links to the file instead of
## embedding its own copy (an embedded weapon can't be found again after a scene change).
func save_res(res: Resource, path: String) -> Resource:
	ensure_dir(path.get_base_dir())
	var err := ResourceSaver.save(res, path)
	if err != OK:
		fail("Could not save %s (%s)" % [path, error_string(err)])
		return res
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE)
	if loaded == null:
		fail("Could not reload %s" % path)
		return res
	return loaded


## Packs `root` into a .tscn, frees the in-memory tree and returns the loaded PackedScene.
func save_scene(root: Node, path: String, key: String = "") -> PackedScene:
	_assign_owners(root, root)
	var packed := PackedScene.new()
	var err := packed.pack(root)
	if err != OK:
		fail("Could not pack %s (%s)" % [path, error_string(err)])
	ensure_dir(path.get_base_dir())
	err = ResourceSaver.save(packed, path)
	if err != OK:
		fail("Could not save %s (%s)" % [path, error_string(err)])
	root.free()
	var loaded := ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_REPLACE) as PackedScene
	if loaded == null:
		fail("Could not reload %s" % path)
	if key != "":
		scenes[key] = loaded
	print("  scene  ", path)
	return loaded


func _assign_owners(node: Node, owner_node: Node) -> void:
	for child in node.get_children():
		child.owner = owner_node
		if child.scene_file_path == "":
			_assign_owners(child, owner_node)


func save_mesh(builder: LowPolyMesh, key: String) -> ArrayMesh:
	var mesh := save_res(builder.commit(), "res://models/%s.tres" % key) as ArrayMesh
	meshes[key] = mesh
	return mesh


# --------------------------------------------------------------------------
# Node helpers
# --------------------------------------------------------------------------

func lp(seed_value: int = 7) -> LowPolyMesh:
	return LowPolyMesh.new(mats, seed_value)


func T(position: Vector3, rotation_degrees: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE) -> Transform3D:
	return LowPolyMesh.xf(position, rotation_degrees, scale)


func attach(parent: Node, child: Node, node_name: String = "") -> Node:
	if node_name != "":
		child.name = node_name
	if parent != null:
		parent.add_child(child, true)
	return child


func node3d(node_name: String, parent: Node = null, position: Vector3 = Vector3.ZERO, rotation_degrees: Vector3 = Vector3.ZERO) -> Node3D:
	var node := Node3D.new()
	node.position = position
	node.rotation_degrees = rotation_degrees
	attach(parent, node, node_name)
	return node


func marker(node_name: String, parent: Node, position: Vector3, rotation_degrees: Vector3 = Vector3.ZERO) -> Marker3D:
	var m := Marker3D.new()
	m.position = position
	m.rotation_degrees = rotation_degrees
	attach(parent, m, node_name)
	return m


func mesh_node(node_name: String, mesh: Mesh, parent: Node, position: Vector3 = Vector3.ZERO, rotation_degrees: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = position
	mi.rotation_degrees = rotation_degrees
	mi.scale = scale
	attach(parent, mi, node_name)
	return mi


func set_props(obj: Object, props: Dictionary) -> void:
	for key in props:
		if not (key in obj):
			fail("%s has no property '%s'" % [obj, key])
			continue
		obj.set(key, props[key])


func with_script(node: Node, script_file: String, props: Dictionary = {}) -> Node:
	var script := load(SCRIPTS + script_file) as Script
	if script == null:
		fail("Missing script " + script_file)
		return node
	node.set_script(script)
	set_props(node, props)
	return node


func instance(key: String, parent: Node, position: Vector3 = Vector3.ZERO, rotation_degrees: Vector3 = Vector3.ZERO, props: Dictionary = {}, node_name: String = "") -> Node3D:
	var packed: PackedScene = scenes.get(key)
	if packed == null:
		fail("No scene '%s' built yet" % key)
		return node3d("Missing_" + key, parent, position)
	var inst := packed.instantiate() as Node3D
	inst.position = position
	inst.rotation_degrees = rotation_degrees
	set_props(inst, props)
	attach(parent, inst, node_name)
	return inst


func box_shape(size: Vector3) -> BoxShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	return shape


func sphere_shape(radius: float) -> SphereShape3D:
	var shape := SphereShape3D.new()
	shape.radius = radius
	return shape


func collision(parent: Node, shape: Shape3D, position: Vector3 = Vector3.ZERO, rotation_degrees: Vector3 = Vector3.ZERO, node_name: String = "CollisionShape3D") -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = position
	cs.rotation_degrees = rotation_degrees
	attach(parent, cs, node_name)
	return cs


func make_area(node_name: String, parent: Node, layer: int, mask: int, position: Vector3 = Vector3.ZERO) -> Area3D:
	var a := Area3D.new()
	a.collision_layer = layer
	a.collision_mask = mask
	a.monitorable = layer != 0
	a.position = position
	attach(parent, a, node_name)
	return a


func static_body(node_name: String, parent: Node, layer: int = L_WORLD) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	attach(parent, body, node_name)
	return body


func omni(parent: Node, position: Vector3, color: Color, energy: float, light_range: float, node_name: String = "Light") -> OmniLight3D:
	var light := OmniLight3D.new()
	light.position = position
	light.light_color = color
	light.light_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 1.2
	attach(parent, light, node_name)
	return light


func audio3d(parent: Node, node_name: String, stream: AudioStream = null, volume_db: float = 0.0) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.stream = stream
	player.volume_db = volume_db
	player.bus = &"SFX"
	player.unit_size = 12.0
	player.max_distance = 70.0
	attach(parent, player, node_name)
	return player


func label3d(parent: Node, text: String, position: Vector3, rotation_degrees: Vector3, font_size: int, color: Color, node_name: String = "Label3D") -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = position
	label.rotation_degrees = rotation_degrees
	label.font_size = font_size
	label.pixel_size = 0.01
	label.modulate = color
	label.outline_size = 12
	label.outline_modulate = Color(0, 0, 0, 0.85)
	label.shaded = false
	label.double_sided = true
	attach(parent, label, node_name)
	return label


## GPU particles with a small box draw mesh. Keys: amount, lifetime, one_shot, explosiveness,
## emitting, local_coords, direction, spread, vel_min, vel_max, gravity, scale_min, scale_max,
## color, color_end, radius, size, mat, damping.
func particles(node_name: String, parent: Node, cfg: Dictionary, position: Vector3 = Vector3.ZERO) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = cfg.get("amount", 16)
	p.lifetime = cfg.get("lifetime", 1.0)
	p.one_shot = cfg.get("one_shot", false)
	p.explosiveness = cfg.get("explosiveness", 0.0)
	p.emitting = cfg.get("emitting", true)
	p.local_coords = cfg.get("local_coords", false)
	p.position = position
	p.visibility_aabb = AABB(Vector3(-10, -10, -10), Vector3(20, 20, 20))
	var pm := ParticleProcessMaterial.new()
	pm.direction = cfg.get("direction", Vector3.UP)
	pm.spread = cfg.get("spread", 30.0)
	pm.initial_velocity_min = cfg.get("vel_min", 1.0)
	pm.initial_velocity_max = cfg.get("vel_max", 3.0)
	pm.gravity = cfg.get("gravity", Vector3(0, -9.8, 0))
	pm.scale_min = cfg.get("scale_min", 0.6)
	pm.scale_max = cfg.get("scale_max", 1.2)
	pm.damping_min = cfg.get("damping", 0.0)
	pm.damping_max = cfg.get("damping", 0.0)
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = cfg.get("radius", 0.2)
	pm.color = cfg.get("color", Color.WHITE)
	if cfg.has("color_end"):
		var gradient := Gradient.new()
		gradient.set_color(0, cfg.get("color", Color.WHITE))
		gradient.set_color(1, cfg["color_end"])
		var ramp := GradientTexture1D.new()
		ramp.gradient = gradient
		pm.color = Color.WHITE
		pm.color_ramp = ramp
	if cfg.get("shrink", true):
		var curve := Curve.new()
		curve.add_point(Vector2(0.0, 1.0))
		curve.add_point(Vector2(1.0, 0.05))
		var curve_texture := CurveTexture.new()
		curve_texture.curve = curve
		pm.scale_curve = curve_texture
	p.process_material = pm
	var draw := BoxMesh.new()
	var s: float = cfg.get("size", 0.25)
	draw.size = Vector3(s, s, s)
	draw.material = mats[cfg.get("mat", "particle")]
	p.draw_pass_1 = draw
	attach(parent, p, node_name)
	return p


func environment_node(parent: Node, background: Color, ambient: Color, ambient_energy: float, fog_density: float, glow: float = 0.7) -> WorldEnvironment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = background
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient
	env.ambient_light_energy = ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = glow > 0.0
	env.glow_intensity = glow
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.ssao_enabled = true
	env.ssao_intensity = 1.5
	if fog_density > 0.0:
		env.fog_enabled = true
		env.fog_light_color = background.lerp(Color(0.3, 0.25, 0.2), 0.4)
		env.fog_density = fog_density
		env.fog_sky_affect = 0.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	attach(parent, world_env, "WorldEnvironment")
	return world_env


func sun(parent: Node, color: Color, energy: float, rotation_degrees: Vector3 = Vector3(-58, -35, 0)) -> DirectionalLight3D:
	var light := DirectionalLight3D.new()
	light.light_color = color
	light.light_energy = energy
	light.rotation_degrees = rotation_degrees
	light.shadow_enabled = true
	light.directional_shadow_max_distance = 80.0
	attach(parent, light, "Sun")
	return light


## Bakes a NavigationRegion3D from its static colliders (temporarily added to the tree).
func bake_region(region: NavigationRegion3D) -> int:
	var holder := Node3D.new()
	add_child(holder)
	holder.add_child(region)
	region.bake_navigation_mesh(false)
	holder.remove_child(region)
	holder.free()
	return region.navigation_mesh.get_polygon_count()


func new_navmesh() -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = L_WORLD
	nm.agent_radius = 1.0
	nm.agent_height = 1.5
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 30.0
	nm.cell_size = 0.25
	nm.cell_height = 0.25
	return nm


## Control anchors/offsets helper: anchors (l, t, r, b) and offsets (l, t, r, b).
func place(control: Control, anchors: Vector4, offsets: Vector4) -> Control:
	control.anchor_left = anchors.x
	control.anchor_top = anchors.y
	control.anchor_right = anchors.z
	control.anchor_bottom = anchors.w
	control.offset_left = offsets.x
	control.offset_top = offsets.y
	control.offset_right = offsets.z
	control.offset_bottom = offsets.w
	return control


func full_rect(control: Control) -> Control:
	return place(control, Vector4(0, 0, 1, 1), Vector4.ZERO)


func label(parent: Node, text: String, font_size: int = 20, node_name: String = "Label") -> Label:
	var l := Label.new()
	l.text = text
	if font_size != 20:
		l.add_theme_font_size_override("font_size", font_size)
	attach(parent, l, node_name)
	return l


func button(parent: Node, text: String, node_name: String) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(280, 52)
	attach(parent, b, node_name)
	return b
