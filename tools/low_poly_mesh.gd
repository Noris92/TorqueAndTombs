extends RefCounted
## Flat-shaded low-poly mesh builder used by the project generator.
## Every primitive takes a Transform3D, a color and a material key. Faces get their own
## normal and a slightly jittered vertex color, which gives the faceted low-poly look.

var materials: Dictionary
## Random brightness variation per face (0 = none).
var jitter: float = 0.06
var rng := RandomNumberGenerator.new()
var _tools: Dictionary = {}


func _init(material_lookup: Dictionary, seed_value: int = 7) -> void:
	materials = material_lookup
	rng.seed = seed_value


func commit() -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for key in _tools:
		var st: SurfaceTool = _tools[key]
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, materials[key])
	return mesh


func is_empty() -> bool:
	return _tools.is_empty()


# --------------------------------------------------------------------------
# Low-level
# --------------------------------------------------------------------------

func shade(color: Color) -> Color:
	if jitter <= 0.0:
		return color
	var f := 1.0 + rng.randf_range(-jitter, jitter)
	return Color(clampf(color.r * f, 0.0, 1.0), clampf(color.g * f, 0.0, 1.0), clampf(color.b * f, 0.0, 1.0), color.a)


## Adds a triangle facing `outward`. Winding is fixed up automatically
## (Godot treats clockwise triangles as front faces).
func tri(a: Vector3, b: Vector3, c: Vector3, outward: Vector3, color: Color, key: String = "main") -> void:
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	if n.dot(outward) < 0.0:
		n = -n
	else:
		var swap := b
		b = c
		c = swap
	var st := _tool(key)
	for p in [a, b, c]:
		st.set_color(color)
		st.set_normal(n)
		st.add_vertex(p)


## Quad a-b-c-d (around the perimeter). `center` is any point inside the solid.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, center: Vector3, color: Color, key: String = "main") -> void:
	var col := shade(color)
	var outward := (a + b + c + d) * 0.25 - center
	tri(a, b, c, outward, col, key)
	tri(a, c, d, outward, col, key)


func _tool(key: String) -> SurfaceTool:
	if not _tools.has(key):
		if not materials.has(key):
			push_error("LowPolyMesh: unknown material '%s'" % key)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[key] = st
	return _tools[key]


# --------------------------------------------------------------------------
# Primitives
# --------------------------------------------------------------------------

static func xf(position: Vector3, rotation_degrees: Vector3 = Vector3.ZERO, scale: Vector3 = Vector3.ONE) -> Transform3D:
	var rot := Vector3(deg_to_rad(rotation_degrees.x), deg_to_rad(rotation_degrees.y), deg_to_rad(rotation_degrees.z))
	return Transform3D(Basis.from_euler(rot) * Basis.from_scale(scale), position)


## Box centered on the transform origin.
func box(t: Transform3D, size: Vector3, color: Color, key: String = "main") -> void:
	var h := size * 0.5
	var p: Array[Vector3] = []
	for i in 8:
		var local := Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z)
		p.append(t * local)
	var c := t.origin
	quad(p[0], p[2], p[6], p[4], c, color, key)
	quad(p[1], p[3], p[7], p[5], c, color, key)
	quad(p[0], p[1], p[5], p[4], c, color, key)
	quad(p[2], p[3], p[7], p[6], c, color, key)
	quad(p[0], p[1], p[3], p[2], c, color, key)
	quad(p[4], p[5], p[7], p[6], c, color, key)


## Ramp shape. Origin at the bottom center; the high end is at -Z, the low edge at +Z.
func wedge(t: Transform3D, size: Vector3, color: Color, key: String = "main") -> void:
	var hx := size.x * 0.5
	var hz := size.z * 0.5
	var b0 := t * Vector3(-hx, 0.0, -hz)
	var b1 := t * Vector3(hx, 0.0, -hz)
	var b2 := t * Vector3(hx, 0.0, hz)
	var b3 := t * Vector3(-hx, 0.0, hz)
	var t0 := t * Vector3(-hx, size.y, -hz)
	var t1 := t * Vector3(hx, size.y, -hz)
	var c := (b0 + b1 + b2 + b3 + t0 + t1) / 6.0
	quad(b0, b1, b2, b3, c, color, key)
	quad(b0, b1, t1, t0, c, color, key)
	quad(t0, t1, b2, b3, c, color, key)
	var side := shade(color)
	tri(b0, t0, b3, (b0 + t0 + b3) / 3.0 - c, side, key)
	tri(b1, t1, b2, (b1 + t1 + b2) / 3.0 - c, side, key)


## Cylinder / cone / frustum along local Y, centered on the origin.
func cylinder(t: Transform3D, radius_bottom: float, radius_top: float, height: float, sides: int, color: Color, key: String = "main", caps: bool = true) -> void:
	var hh := height * 0.5
	var c := t.origin
	var bottom_center := t * Vector3(0.0, -hh, 0.0)
	var top_center := t * Vector3(0.0, hh, 0.0)
	var cap_bottom := shade(color)
	var cap_top := shade(color)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var pb0 := t * Vector3(cos(a0) * radius_bottom, -hh, sin(a0) * radius_bottom)
		var pb1 := t * Vector3(cos(a1) * radius_bottom, -hh, sin(a1) * radius_bottom)
		var pt0 := t * Vector3(cos(a0) * radius_top, hh, sin(a0) * radius_top)
		var pt1 := t * Vector3(cos(a1) * radius_top, hh, sin(a1) * radius_top)
		var side_outward := t.basis * Vector3(cos((a0 + a1) * 0.5), 0.0, sin((a0 + a1) * 0.5))
		if radius_top <= 0.001:
			tri(pb0, pb1, top_center, side_outward, shade(color), key)
		elif radius_bottom <= 0.001:
			tri(bottom_center, pt1, pt0, side_outward, shade(color), key)
		else:
			var col := shade(color)
			tri(pb0, pb1, pt1, side_outward, col, key)
			tri(pb0, pt1, pt0, side_outward, col, key)
		if caps and radius_bottom > 0.001:
			tri(bottom_center, pb0, pb1, bottom_center - c, cap_bottom, key)
		if caps and radius_top > 0.001:
			tri(top_center, pt1, pt0, top_center - c, cap_top, key)


## Low-poly sphere (icosahedron, optionally subdivided). `roughness` displaces vertices for rocks.
func sphere(t: Transform3D, radius: float, color: Color, key: String = "main", subdivisions: int = 0, roughness: float = 0.0) -> void:
	var g := (1.0 + sqrt(5.0)) * 0.5
	var verts: Array[Vector3] = [
		Vector3(-1, g, 0), Vector3(1, g, 0), Vector3(-1, -g, 0), Vector3(1, -g, 0),
		Vector3(0, -1, g), Vector3(0, 1, g), Vector3(0, -1, -g), Vector3(0, 1, -g),
		Vector3(g, 0, -1), Vector3(g, 0, 1), Vector3(-g, 0, -1), Vector3(-g, 0, 1),
	]
	var faces: Array = [
		[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11],
		[1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9],
		[4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1],
	]
	var tris: Array = []
	for f in faces:
		tris.append([verts[f[0]].normalized(), verts[f[1]].normalized(), verts[f[2]].normalized()])
	for _s in subdivisions:
		var next: Array = []
		for tr in tris:
			var a: Vector3 = tr[0]
			var b: Vector3 = tr[1]
			var cc: Vector3 = tr[2]
			var ab := ((a + b) * 0.5).normalized()
			var bc := ((b + cc) * 0.5).normalized()
			var ca := ((cc + a) * 0.5).normalized()
			next.append_array([[a, ab, ca], [b, bc, ab], [cc, ca, bc], [ab, bc, ca]])
		tris = next
	var offsets: Dictionary = {}
	var center := t.origin
	for tr in tris:
		var pts: Array[Vector3] = []
		for v in tr:
			var key_v: Vector3 = (v as Vector3).snapped(Vector3.ONE * 0.001)
			if not offsets.has(key_v):
				offsets[key_v] = 1.0 + rng.randf_range(-roughness, roughness)
			pts.append(t * ((v as Vector3) * radius * float(offsets[key_v])))
		tri(pts[0], pts[1], pts[2], (pts[0] + pts[1] + pts[2]) / 3.0 - center, shade(color), key)


## Flat grid facing up with jittered heights (lava, rubble ground). Centered on the origin.
func grid(t: Transform3D, size_x: float, size_z: float, cells_x: int, cells_z: int, color: Color, key: String = "main", height_jitter: float = 0.0) -> void:
	var heights: Dictionary = {}
	for ix in cells_x + 1:
		for iz in cells_z + 1:
			var edge := ix == 0 or iz == 0 or ix == cells_x or iz == cells_z
			heights[Vector2i(ix, iz)] = 0.0 if edge else rng.randf_range(-height_jitter, height_jitter)
	var up := t.basis * Vector3.UP
	for ix in cells_x:
		for iz in cells_z:
			var p: Array[Vector3] = []
			var corners: Array[Vector2i] = [Vector2i(ix, iz), Vector2i(ix + 1, iz), Vector2i(ix + 1, iz + 1), Vector2i(ix, iz + 1)]
			for corner in corners:
				var x: float = -size_x * 0.5 + size_x * corner.x / cells_x
				var z: float = -size_z * 0.5 + size_z * corner.y / cells_z
				var h: float = heights[corner]
				p.append(t * Vector3(x, h, z))
			tri(p[0], p[1], p[2], up, shade(color), key)
			tri(p[0], p[2], p[3], up, shade(color), key)
