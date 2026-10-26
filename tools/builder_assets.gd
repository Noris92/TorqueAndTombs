extends "res://tools/builder_base.gd"
## Materials, sounds, low-poly models and the reusable scenes (effects, projectiles, hazards,
## doors, teleporter, weapons, player buggy, enemies) plus weapon/upgrade data.


# ==========================================================================
# Materials & sounds
# ==========================================================================

func build_materials() -> void:
	print("Materials")
	mats["main"] = _vertex_material(0.0, 0.88)
	mats["metal"] = _vertex_material(0.55, 0.38)
	mats["glow_orange"] = _glow_material(Color(1.0, 0.45, 0.08), 3.0)
	mats["glow_cyan"] = _glow_material(Color(0.25, 0.85, 1.0), 3.0)
	mats["glow_yellow"] = _glow_material(Color(1.0, 0.86, 0.45), 2.5)
	mats["glow_red"] = _glow_material(Color(1.0, 0.12, 0.08), 3.0)
	mats["glow_purple"] = _glow_material(Color(0.7, 0.3, 1.0), 3.0)

	var lava := _vertex_material(0.0, 0.5)
	lava.emission_enabled = true
	lava.emission = Color(1.0, 0.32, 0.04)
	lava.emission_energy_multiplier = 1.8
	mats["lava"] = lava

	var particle := StandardMaterial3D.new()
	particle.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	particle.vertex_color_use_as_albedo = true
	particle.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mats["particle"] = particle

	var particle_glow := particle.duplicate() as StandardMaterial3D
	particle_glow.albedo_color = Color(2.5, 2.5, 2.5, 1.0)
	mats["particle_glow"] = particle_glow

	var particle_solid := _vertex_material(0.0, 0.9)
	mats["particle_solid"] = particle_solid

	var telegraph := StandardMaterial3D.new()
	telegraph.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	telegraph.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	telegraph.albedo_color = Color(1.0, 0.15, 0.05, 0.55)
	telegraph.cull_mode = BaseMaterial3D.CULL_DISABLED
	mats["telegraph"] = telegraph

	for key in mats.keys():
		mats[key] = save_res(mats[key], "res://materials/%s.tres" % key)


func _vertex_material(metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.metallic = metallic
	m.roughness = roughness
	return m


func _glow_material(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	m.roughness = 0.5
	return m


func build_sounds() -> void:
	print("Sounds")
	var generators := {
		"shoot": AudioGen.shoot(), "rocket": AudioGen.rocket(), "explosion": AudioGen.explosion(),
		"hit": AudioGen.hit(), "pickup": AudioGen.pickup(), "boost": AudioGen.boost(),
		"door": AudioGen.door(), "engine": AudioGen.engine_loop(), "purchase": AudioGen.purchase(),
		"error": AudioGen.error_buzz(), "teleport": AudioGen.teleport(), "spike": AudioGen.spike(),
		"crate": AudioGen.crate_break(), "fireball": AudioGen.fireball(),
	}
	for key in generators:
		sounds[key] = save_res(generators[key], "res://audio/%s.tres" % key)

	# Master / Music / SFX buses for the options menu.
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
	var err := ResourceSaver.save(AudioServer.generate_bus_layout(), "res://default_bus_layout.tres")
	if err != OK:
		fail("Could not save bus layout")


# ==========================================================================
# Models
# ==========================================================================

func build_models() -> void:
	print("Models")
	_model_buggy()
	_model_weapons()
	_model_upgrades()
	_model_enemies()
	_model_props()
	_model_projectiles()


func _model_buggy() -> void:
	var m := lp(101)
	var o: Color = C.orange
	var od: Color = C.orange_dark
	var md: Color = C.metal_dark
	var ch: Color = C.chrome
	m.box(T(Vector3(0, 0.55, 0.05)), Vector3(1.7, 0.3, 3.1), md, "metal")
	m.box(T(Vector3(0, 0.9, 0.3)), Vector3(1.62, 0.42, 2.1), o)
	m.box(T(Vector3(0, 0.82, -1.05)), Vector3(1.55, 0.32, 1.0), o)
	m.wedge(T(Vector3(0, 0.98, -0.82), Vector3(0, 180, 0)), Vector3(1.4, 0.22, 0.5), od)
	m.box(T(Vector3(0, 0.55, -1.68)), Vector3(1.95, 0.25, 0.26), md, "metal")
	for x in [-0.5, 0.5]:
		m.box(T(Vector3(x, 0.82, -1.76)), Vector3(0.1, 0.5, 0.1), ch, "metal")
	m.box(T(Vector3(0, 1.06, -1.76)), Vector3(1.1, 0.1, 0.1), ch, "metal")
	for x in [-0.55, 0.55]:
		m.box(T(Vector3(x, 0.84, -1.56)), Vector3(0.32, 0.16, 0.06), Color.WHITE, "glow_yellow")
		m.box(T(Vector3(x * 1.1, 0.86, 1.36)), Vector3(0.3, 0.12, 0.05), Color.WHITE, "glow_red")
	for x in [-0.95, 0.95]:
		for z in [-1.05, 1.05]:
			m.box(T(Vector3(x, 0.98, z)), Vector3(0.52, 0.1, 1.0), od)
		m.box(T(Vector3(x * 0.86, 0.92, 0.3)), Vector3(0.03, 0.12, 1.9), C.yellow)
	# Roll cage
	for x in [-0.72, 0.72]:
		for z in [-0.25, 0.95]:
			m.box(T(Vector3(x, 1.46, z)), Vector3(0.09, 0.75, 0.09), ch, "metal")
		m.box(T(Vector3(x, 1.83, 0.35)), Vector3(0.09, 0.09, 1.29), ch, "metal")
	for z in [-0.25, 0.95]:
		m.box(T(Vector3(0, 1.83, z)), Vector3(1.53, 0.09, 0.09), ch, "metal")
	# Cockpit, engine, exhausts
	m.box(T(Vector3(0, 1.25, 0.45)), Vector3(0.75, 0.45, 0.5), C.black)
	m.box(T(Vector3(0, 1.6, 0.68)), Vector3(0.55, 0.35, 0.12), C.black)
	m.cylinder(T(Vector3(0, 1.38, -0.08), Vector3(60, 0, 0)), 0.18, 0.18, 0.05, 8, md, "metal")
	m.box(T(Vector3(0, 1.15, 1.3)), Vector3(1.1, 0.55, 0.75), md, "metal")
	m.box(T(Vector3(0, 1.5, 1.25)), Vector3(0.5, 0.2, 0.4), ch, "metal")
	for x in [-0.38, 0.38]:
		m.cylinder(T(Vector3(x, 1.4, 1.72), Vector3(60, 0, 0)), 0.08, 0.08, 0.7, 6, ch, "metal")
	save_mesh(m, "buggy_body")

	var w := lp(102)
	w.jitter = 0.03
	w.cylinder(T(Vector3.ZERO, Vector3(0, 0, 90)), 0.45, 0.45, 0.38, 8, C.tire)
	w.cylinder(T(Vector3.ZERO, Vector3(0, 0, 90)), 0.22, 0.22, 0.4, 6, C.chrome, "metal")
	for i in 8:
		var angle := TAU * i / 8.0
		w.box(T(Vector3(0, cos(angle) * 0.44, sin(angle) * 0.44), Vector3(rad_to_deg(angle), 0, 0)), Vector3(0.4, 0.06, 0.16), C.tire)
	save_mesh(w, "wheel")


func _model_weapons() -> void:
	var md: Color = C.metal_dark
	var a := lp(111)
	a.cylinder(T(Vector3(0, 0.1, 0)), 0.38, 0.32, 0.2, 6, md, "metal")
	a.box(T(Vector3(0, 0.34, 0.05)), Vector3(0.55, 0.32, 0.62), C.orange)
	a.cylinder(T(Vector3(0, 0.3, -0.7), Vector3(90, 0, 0)), 0.07, 0.07, 0.85, 6, C.metal, "metal")
	a.cylinder(T(Vector3(0, 0.3, -1.12), Vector3(90, 0, 0)), 0.11, 0.11, 0.16, 6, md, "metal")
	a.box(T(Vector3(0.38, 0.3, 0.05)), Vector3(0.22, 0.22, 0.3), C.moss)
	save_mesh(a, "autocannon")

	var t := lp(112)
	t.cylinder(T(Vector3(0, 0.1, 0)), 0.42, 0.36, 0.2, 6, md, "metal")
	t.box(T(Vector3(0, 0.36, 0.05)), Vector3(0.78, 0.36, 0.72), C.orange)
	for x in [-0.16, 0.16]:
		t.cylinder(T(Vector3(x, 0.32, -0.78), Vector3(90, 0, 0)), 0.075, 0.075, 1.0, 6, C.metal, "metal")
		t.cylinder(T(Vector3(x, 0.32, -1.25), Vector3(90, 0, 0)), 0.11, 0.11, 0.16, 6, md, "metal")
	t.cylinder(T(Vector3(0.52, 0.34, 0.05), Vector3(0, 0, 90)), 0.22, 0.22, 0.2, 8, C.moss)
	t.box(T(Vector3(0, 0.58, 0.1)), Vector3(0.3, 0.1, 0.3), C.yellow)
	save_mesh(t, "twin_cannon")

	var r := lp(113)
	r.box(T(Vector3(0, 0.19, 0)), Vector3(0.72, 0.38, 0.72), md, "metal")
	r.box(T(Vector3(0, 0.39, 0)), Vector3(0.74, 0.04, 0.74), C.orange)
	for x in [-0.17, 0.17]:
		for y in [0.1, 0.28]:
			r.cylinder(T(Vector3(x, y, -0.38), Vector3(90, 0, 0)), 0.11, 0.11, 0.1, 6, C.metal, "metal")
			r.box(T(Vector3(x, y, -0.43)), Vector3(0.1, 0.1, 0.03), Color.WHITE, "glow_red")
	save_mesh(r, "rocket_pod")


func _model_upgrades() -> void:
	var md: Color = C.metal_dark
	var a := lp(121)
	for x in [-1.0, 1.0]:
		a.box(T(Vector3(x, 0.0, 0.2)), Vector3(0.08, 0.44, 2.2), md, "metal")
		for z in [-0.6, 0.2, 1.0]:
			a.box(T(Vector3(x * 1.04, 0.12, z)), Vector3(0.05, 0.07, 0.07), C.chrome, "metal")
	save_mesh(a, "armor_plates")

	var s := lp(122)
	for x in [-0.55, 0.55]:
		s.box(T(Vector3(x, 0.17, 0)), Vector3(0.08, 0.35, 0.08), md, "metal")
		s.box(T(Vector3(x * 1.72, 0.33, 0.05)), Vector3(0.06, 0.26, 0.5), md, "metal")
	s.box(T(Vector3(0, 0.38, 0.05)), Vector3(1.9, 0.07, 0.45), C.orange)
	save_mesh(s, "spoiler")

	var p := lp(123)
	for side in [-1.0, 1.0]:
		p.box(T(Vector3(side * 0.5, 0.0, -0.15), Vector3(0, side * 25.0, 0)), Vector3(1.15, 0.5, 0.12), md, "metal")
	for x in [-0.8, -0.3, 0.3, 0.8]:
		p.cylinder(T(Vector3(x, 0.0, -0.45 + absf(x) * 0.42), Vector3(-90, 0, 0)), 0.08, 0.0, 0.35, 5, C.bone)
	save_mesh(p, "ram_plow")

	var n := lp(124)
	for x in [-0.75, 0.75]:
		n.cylinder(T(Vector3(x, 0, 0), Vector3(90, 0, 0)), 0.15, 0.15, 0.9, 8, C.blue, "metal")
		n.cylinder(T(Vector3(x, 0, -0.48), Vector3(90, 0, 0)), 0.08, 0.08, 0.08, 6, Color.WHITE, "glow_cyan")
	save_mesh(n, "nitro_tanks")


func _model_enemies() -> void:
	var r := lp(131)
	r.box(T(Vector3(0, 0.5, 0)), Vector3(1.6, 0.35, 2.4), C.red_dark, "metal")
	r.box(T(Vector3(0, 0.86, 0.3)), Vector3(1.4, 0.45, 1.6), C.red)
	r.box(T(Vector3(0, 0.68, -1.3), Vector3(-20, 0, 0)), Vector3(1.85, 0.6, 0.25), C.bone)
	for x in [-0.6, 0.0, 0.6]:
		r.cylinder(T(Vector3(x, 0.72, -1.62), Vector3(-90, 0, 0)), 0.13, 0.0, 0.55, 5, C.bone)
	for x in [-0.85, 0.85]:
		for z in [-0.8, 0.85]:
			r.cylinder(T(Vector3(x, 0.38, z), Vector3(0, 0, 90)), 0.38, 0.38, 0.3, 7, C.tire)
	for x in [-0.32, 0.32]:
		r.box(T(Vector3(x, 1.0, -0.51)), Vector3(0.2, 0.08, 0.05), Color.WHITE, "glow_red")
		r.cylinder(T(Vector3(x, 1.3, 0.95)), 0.08, 0.0, 0.45, 5, C.bone)
	r.sphere(T(Vector3(0, 1.15, -0.25)), 0.22, C.bone)
	save_mesh(r, "rammer")

	var c := lp(132)
	c.cylinder(T(Vector3(0, 0.8, 0)), 0.7, 0.32, 1.6, 7, C.purple)
	c.cylinder(T(Vector3(0, 1.97, 0.02)), 0.42, 0.0, 0.75, 7, C.purple_dark)
	c.sphere(T(Vector3(0, 1.75, -0.08)), 0.28, C.black)
	for x in [-0.09, 0.09]:
		c.box(T(Vector3(x, 1.78, -0.35)), Vector3(0.07, 0.05, 0.04), Color.WHITE, "glow_orange")
	c.cylinder(T(Vector3(0, 1.1, 0)), 0.53, 0.53, 0.1, 7, C.gold, "metal")
	c.box(T(Vector3(0.45, 1.35, -0.15), Vector3(0, 0, -30)), Vector3(0.18, 0.6, 0.18), C.purple_dark)
	c.cylinder(T(Vector3(0.55, 1.1, -0.25)), 0.05, 0.05, 2.2, 5, C.wood)
	c.sphere(T(Vector3(0.55, 2.25, -0.25)), 0.2, Color.WHITE, "glow_orange", 1)
	save_mesh(c, "caster")

	var b := lp(133)
	b.box(T(Vector3(0, 0.5, 0)), Vector3(1.8, 0.35, 2.6), C.purple_dark, "metal")
	b.box(T(Vector3(0, 0.92, 0.5)), Vector3(1.5, 0.5, 1.4), C.purple)
	b.cylinder(T(Vector3(0, 1.22, -0.45)), 0.42, 0.42, 0.3, 8, C.metal_dark, "metal")
	b.cylinder(T(Vector3(0, 1.7, -0.7), Vector3(-35, 0, 0)), 0.23, 0.2, 1.1, 8, C.metal, "metal")
	b.cylinder(T(Vector3(0, 2.12, -1.0), Vector3(-35, 0, 0)), 0.28, 0.28, 0.12, 8, C.metal_dark, "metal")
	for x in [-0.95, 0.95]:
		for z in [-0.85, 0.9]:
			b.cylinder(T(Vector3(x, 0.42, z), Vector3(0, 0, 90)), 0.42, 0.42, 0.32, 7, C.tire)
	for x in [-0.4, 0.4]:
		b.box(T(Vector3(x, 1.0, -0.21)), Vector3(0.2, 0.08, 0.05), Color.WHITE, "glow_purple")
	b.sphere(T(Vector3(0.55, 1.35, 0.9)), 0.2, Color.WHITE, "glow_purple")
	save_mesh(b, "mortar_buggy")

	var d := lp(134)
	d.box(T(Vector3(0, 0.1, 0)), Vector3(1.1, 0.2, 1.1), C.stone_dark)
	d.cylinder(T(Vector3(0, 0.85, 0)), 0.12, 0.12, 1.5, 6, C.wood)
	d.box(T(Vector3(0, 1.1, 0)), Vector3(1.2, 0.12, 0.12), C.wood)
	var rings := [[0.7, C.white, 0.12], [0.5, C.red, 0.14], [0.3, C.white, 0.16], [0.13, C.red, 0.18]]
	for ring in rings:
		d.cylinder(T(Vector3(0, 1.7, 0), Vector3(90, 0, 0)), ring[0], ring[0], ring[2], 10, ring[1])
	for x in [-0.35, 0.35]:
		d.sphere(T(Vector3(x, 0.32, 0.2), Vector3.ZERO, Vector3(1, 0.6, 1)), 0.25, C.sand)
	save_mesh(d, "dummy")


func _model_props() -> void:
	var cr := lp(141)
	cr.box(T(Vector3.ZERO), Vector3(1.38, 1.38, 1.38), C.wood)
	var e := 0.63
	for a in [-e, e]:
		for b in [-e, e]:
			cr.box(T(Vector3(0, a, b)), Vector3(1.44, 0.16, 0.16), C.wood_dark)
			cr.box(T(Vector3(a, 0, b)), Vector3(0.16, 1.44, 0.16), C.wood_dark)
			cr.box(T(Vector3(a, b, 0)), Vector3(0.16, 0.16, 1.44), C.wood_dark)
	for side in [-1.0, 1.0]:
		cr.box(T(Vector3(0, 0, side * 0.7), Vector3(0, 0, 45)), Vector3(1.6, 0.14, 0.04), C.wood_dark)
	save_mesh(cr, "crate")

	var gc := lp(159)
	gc.box(T(Vector3.ZERO), Vector3(1.38, 1.38, 1.38), C.gold, "metal")
	for a in [-e, e]:
		for b in [-e, e]:
			gc.box(T(Vector3(0, a, b)), Vector3(1.44, 0.16, 0.16), C.wood_dark)
			gc.box(T(Vector3(a, 0, b)), Vector3(0.16, 1.44, 0.16), C.wood_dark)
			gc.box(T(Vector3(a, b, 0)), Vector3(0.16, 0.16, 1.44), C.wood_dark)
	gc.sphere(T(Vector3(0, 0, -0.72)), 0.22, Color.WHITE, "glow_cyan")
	gc.sphere(T(Vector3(0, 0.72, 0)), 0.22, Color.WHITE, "glow_cyan")
	save_mesh(gc, "gold_crate")

	var g := lp(142)
	g.cylinder(T(Vector3.ZERO), 0.28, 0.28, 0.12, 8, C.gold, "metal")
	for i in 8:
		var angle := TAU * i / 8.0
		g.box(T(Vector3(cos(angle) * 0.33, 0, sin(angle) * 0.33), Vector3(0, -rad_to_deg(angle), 0)), Vector3(0.12, 0.1, 0.13), C.gold, "metal")
	g.cylinder(T(Vector3.ZERO), 0.1, 0.1, 0.14, 6, C.metal_dark, "metal")
	save_mesh(g, "scrap")

	var sb := lp(143)
	sb.box(T(Vector3(0, -0.04, 0)), Vector3(3.0, 0.12, 3.0), C.metal_dark, "metal")
	for x in [-1.35, 1.35]:
		for z in [-1.35, 1.35]:
			sb.box(T(Vector3(x, 0.03, z)), Vector3(0.18, 0.06, 0.18), C.yellow)
	save_mesh(sb, "spike_base")
	var sp := lp(144)
	for x in [-0.9, 0.0, 0.9]:
		for z in [-0.9, 0.0, 0.9]:
			sp.cylinder(T(Vector3(x, 0.4, z)), 0.15, 0.0, 0.8, 5, C.chrome, "metal")
	save_mesh(sp, "spikes")

	var bp := lp(145)
	bp.box(T(Vector3(0, 0.04, 0)), Vector3(4.0, 0.08, 5.0), C.metal_dark, "metal")
	for x in [-1.9, 1.9]:
		bp.box(T(Vector3(x, 0.07, 0)), Vector3(0.2, 0.08, 5.0), C.yellow)
	for tip_z in [-1.9, -0.5, 0.9]:
		for side in [-1.0, 1.0]:
			var center := Vector3(side * 0.45, 0.1, tip_z + 0.54)
			bp.box(T(center, Vector3(0, side * 40.0, 0)), Vector3(0.34, 0.05, 1.4), Color.WHITE, "glow_cyan")
	save_mesh(bp, "boost_pad")

	var rp := lp(146)
	rp.wedge(T(Vector3.ZERO), Vector3(8.0, 1.2, 4.5), C.stone_light)
	for x in [-3.85, 3.85]:
		rp.box(T(Vector3(x, 0.65, -0.3)), Vector3(0.3, 1.3, 3.9), C.stone_dark)
	for i in 5:
		var z := -1.8 + i * 0.9
		var height := 1.2 * (0.5 - z / 4.5)
		rp.box(T(Vector3(0, height + 0.02, z), Vector3(-15, 0, 0)), Vector3(7.4, 0.04, 0.3), C.yellow if i % 2 == 0 else C.black)
	save_mesh(rp, "ramp")

	var tc := lp(147)
	tc.box(T(Vector3(0, 0, 0.04)), Vector3(0.3, 0.42, 0.08), C.metal_dark, "metal")
	tc.box(T(Vector3(0, -0.05, 0.2), Vector3(-35, 0, 0)), Vector3(0.08, 0.08, 0.35), C.metal_dark, "metal")
	tc.cylinder(T(Vector3(0, 0.12, 0.33)), 0.05, 0.11, 0.35, 6, C.wood)
	tc.cylinder(T(Vector3(0, 0.45, 0.33)), 0.13, 0.0, 0.36, 5, Color.WHITE, "glow_orange")
	save_mesh(tc, "torch")

	var br := lp(148)
	br.cylinder(T(Vector3(0, 0.5, 0)), 0.18, 0.12, 1.0, 6, C.metal_dark, "metal")
	br.cylinder(T(Vector3(0, 1.15, 0)), 0.32, 0.62, 0.4, 8, C.metal_dark, "metal")
	br.sphere(T(Vector3(0, 1.32, 0), Vector3.ZERO, Vector3(1, 0.4, 1)), 0.5, Color.WHITE, "glow_orange", 1)
	save_mesh(br, "brazier")

	var df := lp(149)
	for x in [-4.55, 4.55]:
		df.box(T(Vector3(x, 2.6, 0)), Vector3(1.3, 5.2, 1.6), C.stone_dark)
		df.box(T(Vector3(x, 0.2, 0)), Vector3(1.55, 0.4, 1.9), C.stone)
	df.box(T(Vector3(0, 5.6, 0)), Vector3(10.4, 1.0, 1.8), C.stone)
	for z in [-0.95, 0.95]:
		df.sphere(T(Vector3(0, 5.6, z)), 0.38, C.bone)
	for x in [-4.6, 4.6]:
		df.cylinder(T(Vector3(x, 6.45, 0)), 0.3, 0.0, 0.7, 5, C.bone)
	save_mesh(df, "door_frame")

	var dg := lp(150)
	for i in 9:
		dg.cylinder(T(Vector3(-3.6 + i * 0.9, 2.1, 0)), 0.1, 0.1, 4.2, 6, C.metal_dark, "metal")
		dg.cylinder(T(Vector3(-3.6 + i * 0.9, -0.1, 0), Vector3(180, 0, 0)), 0.12, 0.0, 0.35, 5, C.metal, "metal")
	for y in [0.9, 3.2]:
		dg.box(T(Vector3(0, y, 0)), Vector3(8.0, 0.16, 0.16), C.metal, "metal")
	save_mesh(dg, "door_gate")

	var tb := lp(151)
	tb.cylinder(T(Vector3(0, 0.15, 0)), 2.3, 2.3, 0.3, 6, C.stone_dark)
	tb.cylinder(T(Vector3(0, 0.17, 0)), 1.85, 1.85, 0.32, 6, C.stone)
	for i in 3:
		var angle := TAU * i / 3.0 + PI * 0.5
		tb.cylinder(T(Vector3(cos(angle) * 2.0, 1.1, sin(angle) * 2.0)), 0.26, 0.13, 1.6, 4, C.stone_dark)
	save_mesh(tb, "teleporter_base")
	var tg := lp(152)
	tg.cylinder(T(Vector3(0, 0.18, 0)), 1.5, 1.5, 0.34, 6, Color.WHITE, "glow_cyan")
	for i in 3:
		var angle := TAU * i / 3.0 + PI * 0.5
		tg.sphere(T(Vector3(cos(angle) * 2.0, 2.05, sin(angle) * 2.0)), 0.22, Color.WHITE, "glow_cyan")
	save_mesh(tg, "teleporter_active")
	var tn := lp(153)
	tn.cylinder(T(Vector3(0, 0.18, 0)), 1.5, 1.5, 0.34, 6, C.teal)
	for i in 3:
		var angle := TAU * i / 3.0 + PI * 0.5
		tn.sphere(T(Vector3(cos(angle) * 2.0, 2.05, sin(angle) * 2.0)), 0.22, C.teal)
	save_mesh(tn, "teleporter_inactive")
	var ring := lp(154)
	for i in 14:
		var angle := TAU * i / 14.0
		ring.box(T(Vector3(cos(angle) * 1.4, 0, sin(angle) * 1.4), Vector3(0, -rad_to_deg(angle), 0)), Vector3(0.12, 0.12, 0.55), Color.WHITE, "glow_cyan")
	save_mesh(ring, "teleporter_ring")

	var bl := lp(155)
	var x_pos := -3.6
	for row in 4:
		x_pos = -4.0 + (0.5 if row % 2 == 1 else 0.0)
		while x_pos < 3.99:
			var length := minf(1.6 + bl.rng.randf() * 0.8, 4.0 - x_pos)
			var col: Color = C.stone_dark.lerp(C.stone, bl.rng.randf() * 0.6)
			bl.box(T(Vector3(x_pos + length * 0.5, row + 0.5, 0)), Vector3(length - 0.06, 0.94, 0.9 + bl.rng.randf() * 0.15), col)
			x_pos += length
	save_mesh(bl, "blocker")

	var mk := lp(156)
	mk.cylinder(T(Vector3(0, 0.02, 0)), 1.7, 1.7, 0.03, 16, Color.WHITE, "telegraph")
	mk.cylinder(T(Vector3(0, 0.04, 0)), 0.5, 0.5, 0.04, 10, Color.WHITE, "telegraph")
	save_mesh(mk, "landing_marker")
	var tl := lp(157)
	tl.box(T(Vector3(0, 0, -0.5)), Vector3(0.16, 0.04, 1.0), Color.WHITE, "telegraph")
	save_mesh(tl, "telegraph_line")

	var reticle := lp(158)
	for i in 12:
		var angle := TAU * i / 12.0
		reticle.box(T(Vector3(cos(angle) * 0.9, 0.02, sin(angle) * 0.9), Vector3(0, -rad_to_deg(angle), 0)), Vector3(0.08, 0.04, 0.4), Color.WHITE, "glow_cyan")
	for i in 4:
		var angle := TAU * i / 4.0
		reticle.box(T(Vector3(cos(angle) * 1.25, 0.02, sin(angle) * 1.25), Vector3(0, -rad_to_deg(angle), 0)), Vector3(0.45, 0.04, 0.1), Color.WHITE, "glow_cyan")
	reticle.cylinder(T(Vector3(0, 0.02, 0)), 0.15, 0.15, 0.04, 8, Color.WHITE, "glow_cyan")
	save_mesh(reticle, "aim_reticle")


func _model_projectiles() -> void:
	var b := lp(161)
	b.cylinder(T(Vector3.ZERO, Vector3(90, 0, 0)), 0.08, 0.08, 0.6, 5, Color.WHITE, "glow_yellow")
	save_mesh(b, "bullet")
	var r := lp(162)
	r.cylinder(T(Vector3.ZERO, Vector3(90, 0, 0)), 0.11, 0.11, 0.6, 6, C.chrome, "metal")
	r.cylinder(T(Vector3(0, 0, -0.42), Vector3(-90, 0, 0)), 0.11, 0.0, 0.25, 6, C.red)
	r.cylinder(T(Vector3(0, 0, 0.33), Vector3(90, 0, 0)), 0.09, 0.09, 0.08, 6, Color.WHITE, "glow_orange")
	for angle in [0.0, 90.0]:
		r.box(T(Vector3(0, 0, 0.22), Vector3(0, 0, angle)), Vector3(0.42, 0.03, 0.18), C.red)
	save_mesh(r, "rocket")
	var f := lp(163)
	f.sphere(T(Vector3.ZERO), 0.34, Color.WHITE, "glow_orange", 1, 0.15)
	save_mesh(f, "fireball")
	var s := lp(164)
	s.sphere(T(Vector3.ZERO), 0.3, C.metal_dark, "metal", 1)
	s.cylinder(T(Vector3.ZERO), 0.31, 0.31, 0.08, 10, Color.WHITE, "glow_purple")
	save_mesh(s, "mortar_shell")


# ==========================================================================
# Effects
# ==========================================================================

func build_effects() -> void:
	print("Effects")
	_explosion("Explosion", 1.0, sounds["explosion"])
	_explosion("BigExplosion", 1.8, sounds["explosion"])

	var impact := with_script(node3d("SmallImpact"), "effects/OneShotEffect.gd", {"lifetime": 0.6})
	particles("Sparks", impact, {"amount": 8, "lifetime": 0.3, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"spread": 70.0, "vel_min": 3.0, "vel_max": 6.0, "gravity": Vector3(0, -12, 0), "size": 0.1,
		"color": Color(1, 0.9, 0.4), "color_end": Color(1, 0.4, 0.05, 0), "mat": "particle_glow"})
	save_scene(impact, "res://scenes/effects/SmallImpact.tscn", "SmallImpact")

	var fire := with_script(node3d("FireImpact"), "effects/OneShotEffect.gd", {"lifetime": 0.8})
	particles("Flames", fire, {"amount": 14, "lifetime": 0.45, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"spread": 180.0, "vel_min": 1.5, "vel_max": 4.0, "gravity": Vector3(0, 2, 0), "size": 0.3, "damping": 3.0,
		"color": Color(1, 0.75, 0.2), "color_end": Color(0.9, 0.15, 0.02, 0), "mat": "particle_glow"})
	_fade_light(fire, Color(1, 0.5, 0.15), 2.0, 5.0, 0.3)
	save_scene(fire, "res://scenes/effects/FireImpact.tscn", "FireImpact")

	var puff := with_script(node3d("SpawnPuff"), "effects/OneShotEffect.gd", {"lifetime": 1.2})
	particles("Smoke", puff, {"amount": 24, "lifetime": 0.9, "one_shot": true, "explosiveness": 0.9, "emitting": false,
		"radius": 1.0, "vel_min": 1.0, "vel_max": 2.5, "gravity": Vector3(0, 3, 0), "size": 0.4, "spread": 180.0,
		"color": Color(0.7, 0.35, 1.0), "color_end": Color(0.2, 0.1, 0.3, 0), "mat": "particle_glow"})
	save_scene(puff, "res://scenes/effects/SpawnPuff.tscn", "SpawnPuff")

	var chips := with_script(node3d("CrateBreak"), "effects/OneShotEffect.gd", {"lifetime": 1.3})
	particles("Chips", chips, {"amount": 14, "lifetime": 1.0, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"spread": 75.0, "vel_min": 3.0, "vel_max": 7.0, "gravity": Vector3(0, -18, 0), "size": 0.24, "radius": 0.5,
		"color": C.wood, "mat": "particle_solid", "shrink": false})
	particles("Dust", chips, {"amount": 8, "lifetime": 0.9, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"spread": 180.0, "vel_min": 0.5, "vel_max": 1.5, "gravity": Vector3(0, 1, 0), "size": 0.6, "radius": 0.5,
		"color": Color(0.75, 0.65, 0.5, 0.6), "color_end": Color(0.75, 0.65, 0.5, 0), "mat": "particle"})
	save_scene(chips, "res://scenes/effects/CrateBreak.tscn", "CrateBreak")

	var sparkle := with_script(node3d("Sparkle"), "effects/OneShotEffect.gd", {"lifetime": 1.5})
	particles("Sparks", sparkle, {"amount": 30, "lifetime": 1.0, "one_shot": true, "explosiveness": 0.8, "emitting": false,
		"radius": 1.6, "vel_min": 2.0, "vel_max": 4.0, "gravity": Vector3(0, 1, 0), "size": 0.15, "spread": 40.0,
		"color": Color(0.4, 0.95, 1.0), "color_end": Color(0.2, 0.6, 1.0, 0), "mat": "particle_glow"})
	save_scene(sparkle, "res://scenes/effects/Sparkle.tscn", "Sparkle")

	var landing := node3d("LandingMarker")
	mesh_node("Mesh", meshes["landing_marker"], landing)
	save_scene(landing, "res://scenes/effects/LandingMarker.tscn", "LandingMarker")


func _explosion(key: String, scale: float, sound: AudioStream) -> void:
	var root := with_script(node3d(key), "effects/OneShotEffect.gd", {"lifetime": 1.6, "sound": sound})
	particles("Fire", root, {"amount": int(28 * scale), "lifetime": 0.55, "one_shot": true, "explosiveness": 0.95, "emitting": false,
		"spread": 180.0, "vel_min": 3.0 * scale, "vel_max": 8.0 * scale, "gravity": Vector3(0, 1, 0), "damping": 6.0,
		"size": 0.45 * scale, "radius": 0.4 * scale, "color": Color(1, 0.85, 0.3), "color_end": Color(0.9, 0.2, 0.02, 0), "mat": "particle_glow"})
	particles("Smoke", root, {"amount": int(16 * scale), "lifetime": 1.3, "one_shot": true, "explosiveness": 0.9, "emitting": false,
		"spread": 180.0, "vel_min": 1.0, "vel_max": 3.0 * scale, "gravity": Vector3(0, 2.5, 0), "damping": 2.0,
		"size": 0.7 * scale, "radius": 0.5 * scale, "color": Color(0.25, 0.22, 0.2, 0.85), "color_end": Color(0.15, 0.15, 0.15, 0), "mat": "particle"})
	particles("Debris", root, {"amount": int(10 * scale), "lifetime": 1.0, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"spread": 70.0, "vel_min": 4.0, "vel_max": 9.0 * scale, "gravity": Vector3(0, -18, 0), "size": 0.18 * scale,
		"color": C.metal_dark, "mat": "particle_solid", "shrink": false})
	_fade_light(root, Color(1.0, 0.55, 0.2), 5.0 * scale, 9.0 * scale, 0.45)
	save_scene(root, "res://scenes/effects/%s.tscn" % key, key)


func _fade_light(parent: Node, color: Color, energy: float, light_range: float, duration: float) -> void:
	var light := omni(parent, Vector3(0, 1, 0), color, energy, light_range, "Flash")
	with_script(light, "effects/LightFade.gd", {"duration": duration})


# ==========================================================================
# Projectiles
# ==========================================================================

func build_projectiles() -> void:
	print("Projectiles")
	var bullet := with_script(make_area("Bullet", null, L_PLAYER_PROJ, L_WORLD | L_ENEMY | L_BREAKABLE), "projectiles/Bullet.gd",
		{"impact_effect": scenes["SmallImpact"]})
	bullet.set("monitorable", false)
	collision(bullet, sphere_shape(0.15))
	mesh_node("Mesh", meshes["bullet"], bullet)
	save_scene(bullet, "res://scenes/projectiles/Bullet.tscn", "Bullet")

	var rocket := with_script(make_area("Rocket", null, L_PLAYER_PROJ, L_WORLD | L_ENEMY | L_BREAKABLE), "projectiles/Rocket.gd",
		{"impact_effect": scenes["Explosion"], "default_splash_radius": 3.5})
	rocket.set("monitorable", false)
	collision(rocket, sphere_shape(0.25))
	mesh_node("Mesh", meshes["rocket"], rocket)
	particles("Trail", rocket, {"amount": 24, "lifetime": 0.4, "spread": 10.0, "direction": Vector3(0, 0, 1), "vel_min": 1.0, "vel_max": 2.0,
		"gravity": Vector3(0, 1, 0), "size": 0.22, "color": Color(1, 0.8, 0.4), "color_end": Color(0.4, 0.4, 0.4, 0), "mat": "particle_glow"}, Vector3(0, 0, 0.35))
	var splash := make_area("SplashArea", rocket, 0, L_ENEMY | L_BREAKABLE)
	collision(splash, sphere_shape(3.5))
	save_scene(rocket, "res://scenes/projectiles/Rocket.tscn", "Rocket")

	var groups: Array[String] = ["player"]
	var fireball := with_script(make_area("EnemyFireball", null, L_ENEMY_PROJ, L_WORLD | L_PLAYER), "projectiles/Bullet.gd",
		{"impact_effect": scenes["FireImpact"], "hit_groups": groups})
	fireball.set("monitorable", false)
	collision(fireball, sphere_shape(0.3))
	mesh_node("Mesh", meshes["fireball"], fireball)
	particles("Trail", fireball, {"amount": 20, "lifetime": 0.35, "spread": 25.0, "vel_min": 0.3, "vel_max": 0.8,
		"gravity": Vector3(0, 2, 0), "size": 0.25, "color": Color(1, 0.6, 0.15), "color_end": Color(0.6, 0.1, 0.02, 0), "mat": "particle_glow"})
	omni(fireball, Vector3.ZERO, Color(1, 0.5, 0.15), 1.5, 4.0)
	save_scene(fireball, "res://scenes/projectiles/EnemyFireball.tscn", "EnemyFireball")

	var shell := with_script(make_area("MortarShell", null, L_ENEMY_PROJ, L_WORLD | L_PLAYER), "projectiles/Rocket.gd",
		{"impact_effect": scenes["Explosion"], "hit_groups": groups, "default_splash_radius": 3.2, "knockback_force": 8.0, "align_to_velocity": false})
	shell.set("monitorable", false)
	collision(shell, sphere_shape(0.3))
	mesh_node("Mesh", meshes["mortar_shell"], shell)
	particles("Trail", shell, {"amount": 20, "lifetime": 0.5, "spread": 15.0, "vel_min": 0.2, "vel_max": 0.6,
		"gravity": Vector3(0, 1, 0), "size": 0.25, "color": Color(0.7, 0.35, 1.0), "color_end": Color(0.2, 0.1, 0.3, 0), "mat": "particle_glow"})
	var shell_splash := make_area("SplashArea", shell, 0, L_PLAYER)
	collision(shell_splash, sphere_shape(3.2))
	save_scene(shell, "res://scenes/projectiles/MortarShell.tscn", "MortarShell")


# ==========================================================================
# Pickups, hazards and world pieces
# ==========================================================================

func build_hazards() -> void:
	print("Pickups & hazards")
	var scrap := with_script(node3d("ScrapPickup"), "hazards/ScrapPickup.gd", {"pickup_sound": sounds["pickup"]})
	var scrap_visual := node3d("Visual", scrap)
	mesh_node("Mesh", meshes["scrap"], scrap_visual, Vector3.ZERO, Vector3(65, 0, 0))
	save_scene(scrap, "res://scenes/hazards/ScrapPickup.tscn", "ScrapPickup")

	var crate := RigidBody3D.new()
	crate.name = "LootCrate"
	crate.collision_layer = L_BREAKABLE
	crate.collision_mask = L_WORLD | L_ENEMY | L_BREAKABLE
	crate.mass = 12.0
	with_script(crate, "hazards/LootCrate.gd", {"max_health": 20.0, "scrap_value": 3, "scrap_pickup_scene": scenes["ScrapPickup"],
		"break_effect": scenes["CrateBreak"], "break_sound": sounds["crate"], "hit_sound": sounds["hit"]})
	collision(crate, box_shape(Vector3(1.4, 1.4, 1.4)))
	var touch := make_area("TouchArea", crate, 0, L_PLAYER)
	collision(touch, box_shape(Vector3(1.7, 1.7, 1.7)))
	mesh_node("Mesh", meshes["crate"], crate)
	save_scene(crate, "res://scenes/hazards/LootCrate.tscn", "LootCrate")

	# Treasure-vault only: a gold crate worth roughly half an upgrade.
	var gold := RigidBody3D.new()
	gold.name = "GoldCrate"
	gold.collision_layer = L_BREAKABLE
	gold.collision_mask = L_WORLD | L_ENEMY | L_BREAKABLE
	gold.mass = 20.0
	with_script(gold, "hazards/LootCrate.gd", {"max_health": 30.0, "scrap_value": 25, "scrap_pickup_scene": scenes["ScrapPickup"],
		"break_effect": scenes["Sparkle"], "break_sound": sounds["purchase"], "hit_sound": sounds["hit"]})
	collision(gold, box_shape(Vector3(1.4, 1.4, 1.4)))
	var gold_touch := make_area("TouchArea", gold, 0, L_PLAYER)
	collision(gold_touch, box_shape(Vector3(1.7, 1.7, 1.7)))
	mesh_node("Mesh", meshes["gold_crate"], gold)
	omni(gold, Vector3(0, 1.2, 0), Color(1.0, 0.8, 0.3), 1.2, 4.0)
	save_scene(gold, "res://scenes/hazards/GoldCrate.tscn", "GoldCrate")

	var spikes := with_script(node3d("SpikeTrap"), "hazards/SpikeTrap.gd", {"extend_sound": sounds["spike"], "damage": 15.0,
		"retracted_offset": Vector3(0, -0.85, 0), "warning_offset": Vector3(0, -0.62, 0)})
	mesh_node("Base", meshes["spike_base"], spikes)
	var spike_node := node3d("Spikes", spikes)
	mesh_node("Mesh", meshes["spikes"], spike_node)
	var hurt := make_area("HurtArea", spikes, L_TRIGGER, L_PLAYER | L_ENEMY)
	collision(hurt, box_shape(Vector3(2.8, 1.0, 2.8)), Vector3(0, 0.5, 0))
	var trigger := make_area("TriggerArea", spikes, L_TRIGGER, L_PLAYER)
	collision(trigger, box_shape(Vector3(4.6, 2.0, 4.6)), Vector3(0, 1, 0))
	var spike_audio := audio3d(spikes, "Audio", null, -4.0)
	spikes.set("audio_player", spike_audio)
	save_scene(spikes, "res://scenes/hazards/SpikeTrap.tscn", "SpikeTrap")

	var pad := with_script(make_area("BoostPad", null, L_TRIGGER, L_PLAYER), "hazards/BoostPad.gd", {"boost_speed": 30.0, "nitro_sound": sounds["boost"]})
	collision(pad, box_shape(Vector3(4.0, 0.8, 5.0)), Vector3(0, 0.4, 0))
	mesh_node("Mesh", meshes["boost_pad"], pad)
	var pad_fx := particles("Effect", pad, {"amount": 24, "lifetime": 0.6, "one_shot": true, "explosiveness": 0.8, "emitting": false,
		"direction": Vector3(0, 0.5, -1), "spread": 20.0, "vel_min": 4.0, "vel_max": 8.0, "gravity": Vector3.ZERO, "radius": 1.2,
		"size": 0.15, "color": Color(0.4, 0.95, 1.0), "color_end": Color(0.2, 0.5, 1.0, 0), "mat": "particle_glow", "local_coords": true}, Vector3(0, 0.3, 0))
	pad.set("effect", pad_fx)
	pad.set("audio_player", audio3d(pad, "Audio"))
	omni(pad, Vector3(0, 0.8, 0), Color(0.3, 0.8, 1.0), 1.2, 5.0)
	save_scene(pad, "res://scenes/hazards/BoostPad.tscn", "BoostPad")

	var ramp := static_body("Ramp", null)
	mesh_node("Mesh", meshes["ramp"], ramp)
	var ramp_shape := ConvexPolygonShape3D.new()
	ramp_shape.points = PackedVector3Array([
		Vector3(-4, 0, -2.25), Vector3(4, 0, -2.25), Vector3(4, 0, 2.25), Vector3(-4, 0, 2.25),
		Vector3(-4, 1.2, -2.25), Vector3(4, 1.2, -2.25)])
	collision(ramp, ramp_shape)
	save_scene(ramp, "res://scenes/hazards/Ramp.tscn", "Ramp")

	var torch := node3d("Torch")
	mesh_node("Mesh", meshes["torch"], torch)
	var torch_light := omni(torch, Vector3(0, 0.6, 0.45), Color(1.0, 0.62, 0.3), 2.2, 11.0)
	with_script(torch_light, "effects/Flicker.gd")
	save_scene(torch, "res://scenes/world/props/Torch.tscn", "Torch")

	var brazier := node3d("Brazier")
	mesh_node("Mesh", meshes["brazier"], brazier)
	var brazier_light := omni(brazier, Vector3(0, 1.9, 0), Color(1.0, 0.55, 0.25), 2.8, 13.0)
	with_script(brazier_light, "effects/Flicker.gd")
	particles("Embers", brazier, {"amount": 10, "lifetime": 1.2, "spread": 20.0, "vel_min": 0.5, "vel_max": 1.5,
		"gravity": Vector3(0, 1, 0), "size": 0.08, "radius": 0.3, "color": Color(1, 0.7, 0.2), "color_end": Color(1, 0.2, 0.0, 0), "mat": "particle_glow"}, Vector3(0, 1.4, 0))
	save_scene(brazier, "res://scenes/world/props/Brazier.tscn", "Brazier")

	_build_door()
	_build_teleporter()


func _build_door() -> void:
	var door := with_script(node3d("Door"), "world/Door.gd", {"lock_sound": sounds["door"], "unlock_sound": sounds["door"],
		"open_offset": Vector3(0, -4.4, 0), "move_duration": 0.45})
	mesh_node("Frame", meshes["door_frame"], door)
	var gate := AnimatableBody3D.new()
	gate.collision_layer = L_WORLD
	gate.collision_mask = 0
	attach(door, gate, "Gate")
	# Tall so a locked gate can't be jumped; Door.gd disables it while the gate is open.
	collision(gate, box_shape(Vector3(8.0, 16.0, 0.5)), Vector3(0, 8.0, 0))
	mesh_node("Mesh", meshes["door_gate"], gate)
	var indicator := node3d("LockedLight", door, Vector3(0, 4.7, 0))
	var orb := lp(171)
	orb.sphere(T(Vector3.ZERO), 0.25, Color.WHITE, "glow_red", 1)
	mesh_node("Orb", orb.commit(), indicator)
	omni(indicator, Vector3.ZERO, Color(1, 0.15, 0.1), 2.5, 7.0)
	var audio := audio3d(door, "Audio", null, -2.0)
	set_props(door, {"gate": gate, "locked_indicator": indicator, "audio_player": audio})
	save_scene(door, "res://scenes/world/Door.tscn", "Door")


func _build_teleporter() -> void:
	var tp := with_script(make_area("Teleporter", null, L_TRIGGER, L_PLAYER), "world/Teleporter.gd",
		{"activate_sound": sounds["teleport"], "teleport_sound": sounds["teleport"]})
	var shape := CylinderShape3D.new()
	shape.radius = 1.7
	shape.height = 2.0
	collision(tp, shape, Vector3(0, 1, 0))
	mesh_node("Base", meshes["teleporter_base"], tp)
	var active := node3d("ActiveVisual", tp)
	mesh_node("Glow", meshes["teleporter_active"], active)
	var ring := node3d("Ring", active, Vector3(0, 1.3, 0))
	with_script(ring, "effects/Spin.gd", {"speed": Vector3(0, 1.6, 0), "bob_height": 0.2})
	mesh_node("Mesh", meshes["teleporter_ring"], ring)
	omni(active, Vector3(0, 1.5, 0), Color(0.3, 0.85, 1.0), 3.0, 10.0)
	particles("Motes", active, {"amount": 24, "lifetime": 1.4, "spread": 5.0, "vel_min": 1.0, "vel_max": 2.5, "gravity": Vector3.ZERO,
		"radius": 1.3, "size": 0.12, "color": Color(0.4, 0.95, 1.0), "color_end": Color(0.3, 0.7, 1.0, 0), "mat": "particle_glow"}, Vector3(0, 0.3, 0))
	var inactive := node3d("InactiveVisual", tp)
	mesh_node("Dim", meshes["teleporter_inactive"], inactive)
	save_scene(tp, "res://scenes/world/Teleporter.tscn", "Teleporter")


# ==========================================================================
# Weapons, player and enemies
# ==========================================================================

func build_weapons() -> void:
	print("Weapons")
	for key in ["autocannon", "twin_cannon", "rocket_pod"]:
		var model := node3d(key.to_pascal_case() + "Model")
		mesh_node("Mesh", meshes[key], model)
		save_scene(model, "res://scenes/weapons/%sModel.tscn" % key.to_pascal_case(), key + "_model")

	var autocannon := WeaponResource.new()
	set_props(autocannon, {"weapon_name": "Autocannon", "projectile_scene": scenes["Bullet"], "damage": 8.0, "fire_rate": 6.0,
		"projectile_speed": 45.0, "projectile_lifetime": 0.6, "spread_degrees": 2.0, "detection_range": 16.0,
		"turn_speed": 10.0, "fire_sound": sounds["shoot"], "model_scene": scenes["autocannon_model"]})
	scenes["weapon_autocannon"] = save_res(autocannon, "res://data/weapons/autocannon.tres")

	var twin := WeaponResource.new()
	set_props(twin, {"weapon_name": "Twin Cannon", "projectile_scene": scenes["Bullet"], "damage": 7.0, "fire_rate": 9.0,
		"projectile_speed": 50.0, "projectile_lifetime": 0.6, "projectiles_per_shot": 2, "spread_degrees": 4.0,
		"detection_range": 18.0, "turn_speed": 12.0, "fire_sound": sounds["shoot"], "model_scene": scenes["twin_cannon_model"]})
	scenes["weapon_twin"] = save_res(twin, "res://data/weapons/twin_cannon.tres")

	var rockets := WeaponResource.new()
	set_props(rockets, {"weapon_name": "Rocket Pod", "projectile_scene": scenes["Rocket"], "damage": 40.0, "fire_rate": 0.9,
		"projectile_speed": 30.0, "projectile_lifetime": 1.4, "spread_degrees": 0.0, "splash_radius": 3.5,
		"fire_sound": sounds["rocket"], "model_scene": scenes["rocket_pod_model"]})
	scenes["weapon_rockets"] = save_res(rockets, "res://data/weapons/rocket_pod.tres")

	for key in ["armor_plates", "spoiler", "ram_plow", "nitro_tanks"]:
		var visual := node3d(key.to_pascal_case())
		mesh_node("Mesh", meshes[key], visual)
		save_scene(visual, "res://scenes/upgrades/%s.tscn" % key.to_pascal_case(), key + "_visual")


func build_player() -> void:
	print("Player")
	var root := CharacterBody3D.new()
	root.name = "PlayerVehicle"
	root.collision_layer = L_PLAYER
	root.collision_mask = L_WORLD | L_ENEMY
	with_script(root, "player/PlayerVehicle.gd")
	collision(root, box_shape(Vector3(1.9, 1.0, 3.3)), Vector3(0, 0.5, 0))

	var visual := node3d("VisualRoot", root)
	mesh_node("Body", meshes["buggy_body"], visual)
	var front: Array[Node3D] = []
	var rear: Array[Node3D] = []
	for z in [-1.05, 1.05]:
		for x in [-0.95, 0.95]:
			var wheel_name := ("WheelF" if z < 0 else "WheelR") + ("L" if x < 0 else "R")
			var pivot := node3d(wheel_name, visual, Vector3(x, 0.45, z))
			mesh_node("Mesh", meshes["wheel"], pivot)
			if z < 0:
				front.append(pivot)
			else:
				rear.append(pivot)

	var drift: Array[GPUParticles3D] = []
	for x in [-0.95, 0.95]:
		drift.append(particles("DriftSmoke" + ("L" if x < 0 else "R"), visual, {"amount": 40, "lifetime": 0.9, "emitting": false,
			"spread": 40.0, "vel_min": 0.5, "vel_max": 1.5, "gravity": Vector3(0, 1.2, 0), "size": 0.45, "radius": 0.2,
			"color": Color(0.8, 0.75, 0.7, 0.7), "color_end": Color(0.5, 0.48, 0.45, 0), "mat": "particle"}, Vector3(x, 0.15, 1.1)))
	var boost := particles("BoostFlame", visual, {"amount": 36, "lifetime": 0.3, "emitting": false, "direction": Vector3(0, 0.4, 1),
		"spread": 12.0, "vel_min": 4.0, "vel_max": 7.0, "gravity": Vector3.ZERO, "size": 0.22, "radius": 0.08,
		"color": Color(0.5, 0.9, 1.0), "color_end": Color(1.0, 0.4, 0.1, 0), "mat": "particle_glow"}, Vector3(0, 1.45, 1.95))

	var mounts := node3d("Mounts", visual)
	node3d("FrontMount", mounts, Vector3(0, 0.62, -1.75))
	node3d("SideMounts", mounts, Vector3(0, 0.82, 0))
	node3d("RearMount", mounts, Vector3(0, 1.5, 1.6))
	node3d("TankMount", mounts, Vector3(0, 1.1, 1.3))

	var turret := TurretController.new()
	turret.name = "RoofTurret"
	turret.position = Vector3(0, 1.88, 0.35)
	visual.add_child(turret)
	var muzzle := marker("Muzzle", turret, Vector3(0, 0.3, -1.3))
	var flash := particles("MuzzleFlash", muzzle, {"amount": 6, "lifetime": 0.08, "one_shot": true, "explosiveness": 1.0, "emitting": false,
		"direction": Vector3(0, 0, -1), "spread": 25.0, "vel_min": 2.0, "vel_max": 4.0, "gravity": Vector3.ZERO, "size": 0.18,
		"color": Color(1, 0.85, 0.4), "color_end": Color(1, 0.4, 0.1, 0), "mat": "particle_glow", "local_coords": true})
	var detection := make_area("DetectionArea", turret, 0, L_ENEMY)
	collision(detection, sphere_shape(16.0))
	var gun_audio := audio3d(turret, "FireSound", sounds["shoot"], -8.0)
	set_props(turret, {"weapon": scenes["weapon_autocannon"], "slot_name": "turret", "muzzle": muzzle, "muzzle_flash": flash,
		"audio_player": gun_audio, "detection_area": detection})

	var launcher := RocketLauncher.new()
	launcher.name = "RocketLauncher"
	launcher.position = Vector3(0, 0.97, -1.0)
	visual.add_child(launcher)
	var rocket_muzzle := marker("Muzzle", launcher, Vector3(0, 0.2, -0.6))
	var reticle := node3d("AimReticle", launcher)
	reticle.visible = false
	mesh_node("Mesh", meshes["aim_reticle"], reticle)
	set_props(launcher, {"weapon": scenes["weapon_rockets"], "slot_name": "rocket", "muzzle": rocket_muzzle,
		"audio_player": audio3d(launcher, "FireSound", sounds["rocket"], -3.0)})

	var engine := audio3d(root, "EngineAudio", sounds["engine"], -16.0)
	set_props(root, {"visual_root": visual, "mounts_root": mounts, "drift_particles": drift, "boost_particles": boost,
		"engine_audio": engine, "front_wheels": front, "rear_wheels": rear, "death_effect": scenes["BigExplosion"]})
	save_scene(root, "res://scenes/player/PlayerVehicle.tscn", "PlayerVehicle")


func build_enemies() -> void:
	print("Enemies")
	var rammer := _enemy("RammerEnemy", "enemies/RammerEnemy.gd", "rammer", box_shape(Vector3(1.8, 1.1, 2.8)), Vector3(0, 0.6, 0),
		{"max_health": 35.0, "move_speed": 8.0, "acceleration": 14.0, "scrap_reward": 2, "contact_damage": 14.0, "charge_range": 10.0})
	save_scene(rammer, "res://scenes/enemies/RammerEnemy.tscn", "RammerEnemy")

	var boss := _enemy("Juggernaut", "enemies/RammerEnemy.gd", "rammer", box_shape(Vector3(3.2, 2.0, 5.0)), Vector3(0, 1.0, 0),
		{"max_health": 260.0, "armor": 4.0, "move_speed": 6.5, "acceleration": 10.0, "scrap_reward": 20, "contact_damage": 25.0,
		"charge_range": 14.0, "charge_speed_multiplier": 2.3, "ram_impulse": 22.0, "windup_time": 0.7, "recover_time": 1.6}, 1.8)
	omni(boss, Vector3(0, 2.5, 0), Color(1, 0.2, 0.1), 2.0, 8.0)
	save_scene(boss, "res://scenes/enemies/Juggernaut.tscn", "Juggernaut")

	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.6
	capsule.height = 2.2
	var caster := _enemy("FireCaster", "enemies/RangedEnemy.gd", "caster", capsule, Vector3(0, 1.1, 0),
		{"max_health": 28.0, "move_speed": 5.0, "scrap_reward": 3, "projectile_scene": scenes["EnemyFireball"], "projectile_damage": 12.0,
		"projectile_speed": 16.0, "preferred_range": 12.0, "min_range": 6.0, "attack_range": 17.0, "fire_cooldown": 2.4, "telegraph_time": 0.8})
	var caster_visual := caster.get_node("Visual")
	caster.set("muzzle", marker("Muzzle", caster_visual, Vector3(0.55, 2.25, -0.45)))
	var caster_tele := node3d("Telegraph", caster, Vector3(0, 1.2, 0))
	mesh_node("Line", meshes["telegraph_line"], caster_tele)
	caster.set("telegraph_pivot", caster_tele)
	omni(caster_visual, Vector3(0.55, 2.3, -0.25), Color(1, 0.5, 0.15), 1.2, 4.0)
	save_scene(caster, "res://scenes/enemies/FireCaster.tscn", "FireCaster")

	var mortar := _enemy("MortarBuggy", "enemies/RangedEnemy.gd", "mortar_buggy", box_shape(Vector3(1.9, 1.2, 2.8)), Vector3(0, 0.65, 0),
		{"max_health": 40.0, "move_speed": 6.0, "scrap_reward": 4, "projectile_scene": scenes["MortarShell"], "projectile_damage": 18.0,
		"preferred_range": 16.0, "min_range": 9.0, "attack_range": 24.0, "fire_cooldown": 3.2, "telegraph_time": 1.0,
		"use_mortar_arc": true, "mortar_flight_time": 1.3, "landing_marker_scene": scenes["LandingMarker"]})
	mortar.set("muzzle", marker("Muzzle", mortar.get_node("Visual"), Vector3(0, 2.2, -1.1)))
	save_scene(mortar, "res://scenes/enemies/MortarBuggy.tscn", "MortarBuggy")

	# Boss: a giant fire caster that sprays 5-fireball fans.
	var archon_shape := CapsuleShape3D.new()
	archon_shape.radius = 1.2
	archon_shape.height = 4.4
	var archon := _enemy("PyreArchon", "enemies/RangedEnemy.gd", "caster", archon_shape, Vector3(0, 2.2, 0),
		{"max_health": 230.0, "armor": 3.0, "move_speed": 4.5, "scrap_reward": 20, "projectile_scene": scenes["EnemyFireball"],
		"projectile_damage": 14.0, "projectile_speed": 18.0, "preferred_range": 13.0, "min_range": 7.0, "attack_range": 24.0,
		"fire_cooldown": 1.7, "telegraph_time": 0.7, "projectiles_per_volley": 5, "volley_spread_degrees": 55.0}, 2.1)
	var archon_visual := archon.get_node("Visual")
	archon.set("muzzle", marker("Muzzle", archon_visual, Vector3(0.55, 2.25, -0.45)))
	var archon_tele := node3d("Telegraph", archon, Vector3(0, 2.4, 0))
	mesh_node("Line", meshes["telegraph_line"], archon_tele, Vector3.ZERO, Vector3.ZERO, Vector3(3, 1, 1))
	archon.set("telegraph_pivot", archon_tele)
	omni(archon, Vector3(1.2, 4.8, -0.5), Color(1, 0.45, 0.1), 3.5, 12.0)
	particles("Flames", archon_visual, {"amount": 30, "lifetime": 0.9, "spread": 25.0, "vel_min": 0.5, "vel_max": 1.5, "gravity": Vector3(0, 2, 0),
		"radius": 0.6, "size": 0.25, "color": Color(1, 0.6, 0.15), "color_end": Color(0.7, 0.1, 0.02, 0), "mat": "particle_glow"}, Vector3(0, 0.3, 0))
	save_scene(archon, "res://scenes/enemies/PyreArchon.tscn", "PyreArchon")

	# Boss: a giant mortar buggy that drops 5-shell barrages around the player.
	var siege := _enemy("SiegeCrawler", "enemies/RangedEnemy.gd", "mortar_buggy", box_shape(Vector3(3.5, 2.4, 5.2)), Vector3(0, 1.2, 0),
		{"max_health": 250.0, "armor": 4.0, "move_speed": 4.5, "scrap_reward": 20, "projectile_scene": scenes["MortarShell"],
		"projectile_damage": 16.0, "preferred_range": 17.0, "min_range": 9.0, "attack_range": 30.0, "fire_cooldown": 2.6,
		"telegraph_time": 1.1, "use_mortar_arc": true, "mortar_flight_time": 1.4, "landing_marker_scene": scenes["LandingMarker"],
		"shells_per_volley": 5, "mortar_scatter_radius": 5.0}, 1.9)
	siege.set("muzzle", marker("Muzzle", siege.get_node("Visual"), Vector3(0, 2.2, -1.1)))
	omni(siege, Vector3(0, 3.5, 0), Color(0.7, 0.3, 1.0), 3.0, 10.0)
	save_scene(siege, "res://scenes/enemies/SiegeCrawler.tscn", "SiegeCrawler")

	var dummy := StaticBody3D.new()
	dummy.name = "TrainingDummy"
	dummy.collision_layer = L_ENEMY
	dummy.collision_mask = 0
	with_script(dummy, "enemies/TrainingDummy.gd", {"max_health": 40.0, "scrap_reward": 2, "scrap_pickup_scene": scenes["ScrapPickup"],
		"destroy_effect": scenes["CrateBreak"], "hit_sound": sounds["hit"]})
	collision(dummy, box_shape(Vector3(1.4, 2.4, 0.8)), Vector3(0, 1.2, 0))
	mesh_node("Mesh", meshes["dummy"], dummy)
	save_scene(dummy, "res://scenes/enemies/TrainingDummy.tscn", "TrainingDummy")


func _enemy(node_name: String, script_file: String, mesh_key: String, shape: Shape3D, shape_position: Vector3, props: Dictionary, visual_scale: float = 1.0) -> CharacterBody3D:
	var root := CharacterBody3D.new()
	root.name = node_name
	root.collision_layer = L_ENEMY
	root.collision_mask = L_WORLD | L_PLAYER | L_ENEMY | L_BREAKABLE
	with_script(root, script_file, {"scrap_pickup_scene": scenes["ScrapPickup"], "death_effect": scenes["Explosion"],
		"hit_sound": sounds["hit"]})
	set_props(root, props)
	collision(root, shape, shape_position)
	var visual := node3d("Visual", root)
	visual.scale = Vector3.ONE * visual_scale
	mesh_node("Mesh", meshes[mesh_key], visual)
	var agent := NavigationAgent3D.new()
	agent.path_desired_distance = 1.0
	agent.target_desired_distance = 1.5
	agent.radius = 1.0
	agent.height = 1.5
	attach(root, agent, "NavigationAgent3D")
	return root


# ==========================================================================
# Shop upgrades
# ==========================================================================

func build_upgrades() -> void:
	print("Upgrades")
	var cat := UpgradeResource.Category
	var flat := UpgradeResource.ModifierMode.FLAT
	var percent := UpgradeResource.ModifierMode.PERCENT
	var list := [
		["engine_turbo", "Turbo Charger", "Bigger turbo, higher top speed.", cat.ENGINES, "top_speed", 2.5, flat, 70, 5, "bolt", C.orange, {"visual_scene": scenes["spoiler_visual"], "visual_attach_point": "RearMount"}],
		["engine_torque", "Torque Tune", "Faster acceleration out of corners.", cat.ENGINES, "acceleration", 4.0, flat, 60, 5, "bars_h", C.orange, {}],
		["nitro_tank", "Nitro Tanks", "Store more boost.", cat.ENGINES, "boost_capacity", 25.0, flat, 75, 3, "tank", C.blue, {"visual_scene": scenes["nitro_tanks_visual"], "visual_attach_point": "TankMount"}],
		["armor_plating", "Armor Plating", "More hull points.", cat.ARMOR, "max_health", 25.0, flat, 75, 5, "plus", C.red, {"visual_scene": scenes["armor_plates_visual"], "visual_attach_point": "SideMounts"}],
		["reactive_armor", "Bone Ram Plow", "Spiked plow. Shrugs off damage.", cat.ARMOR, "armor", 15.0, flat, 90, 4, "shield", C.bone, {"visual_scene": scenes["ram_plow_visual"], "visual_attach_point": "FrontMount"}],
		["grippy_tires", "Grippy Tires", "Corner harder with less slide.", cat.TIRES, "grip", 2.0, flat, 55, 4, "ring", C.metal, {}],
		["drift_tires", "Drift Compound", "Longer, looser drifts.", cat.TIRES, "drift_factor", 0.03, flat, 55, 3, "drift", C.yellow, {}],
		["hot_rounds", "Hot Rounds", "Every weapon hits harder.", cat.WEAPONS, "weapon_damage_multiplier", 0.15, flat, 85, 5, "flame", C.orange, {}],
		["rapid_loader", "Rapid Loader", "Weapons fire faster.", cat.WEAPONS, "fire_rate_multiplier", 0.1, percent, 85, 5, "bars_v", C.yellow, {}],
		["twin_cannon_unlock", "Twin Cannon", "Swap the roof gun for a twin-barrel cannon.", cat.WEAPONS, "none", 0.0, flat, 180, 1, "twin", C.chrome, {"weapon_unlock": scenes["weapon_twin"], "weapon_slot": "turret"}],
		["targeting_computer", "Targeting Computer", "The rocket pod swivels to fire wherever you aim: the mouse, or the right stick on a gamepad.", cat.WEAPONS, "none", 0.0, flat, 150, 1, "crosshair", C.teal, {"unlock_flag": "rocket_mouse_aim", "unlock_label": "Mouse-aimed rockets"}],
		["scrap_magnet", "Scrap Magnet", "Scrap flies to you from farther away.", cat.UTILITY, "magnet_range", 12.0, flat, 50, 2, "magnet", C.red, {}],
		["scrap_vacuum", "Scrap Vacuum", "Every piece of scrap in the room you're in flies straight to you.", cat.UTILITY, "none", 0.0, flat, 130, 1, "magnet", C.purple, {"unlock_flag": "scrap_vacuum", "unlock_label": "Auto-collect scrap in your room"}],
	]
	for entry in list:
		var item := UpgradeResource.new()
		var icon := save_res(_icon(entry[10], entry[9]), "res://data/upgrade_icons/%s.tres" % entry[0])
		set_props(item, {"id": entry[0], "display_name": entry[1], "description": entry[2], "category": entry[3],
			"target_stat": entry[4], "modifier_value": entry[5], "modifier_mode": entry[6], "base_cost": entry[7],
			"max_tier": entry[8], "icon": icon})
		set_props(item, entry[11])
		save_res(item, "res://data/upgrades/%s.tres" % entry[0])


## 64x64 flat icon: colored rounded tile with a simple white symbol.
func _icon(color: Color, symbol: String) -> ImageTexture:
	var size := 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var bg := color.darkened(0.35)
	for x in size:
		for y in size:
			var dx := maxf(absf(x - 31.5) - 24.0, 0.0)
			var dy := maxf(absf(y - 31.5) - 24.0, 0.0)
			if dx * dx + dy * dy <= 49.0:
				img.set_pixel(x, y, bg.lerp(color, float(size - y) / size * 0.6))
	var w := Color(1, 1, 1, 0.95)
	match symbol:
		"plus":
			img.fill_rect(Rect2i(27, 14, 10, 36), w)
			img.fill_rect(Rect2i(14, 27, 36, 10), w)
		"bars_v":
			for i in 3:
				img.fill_rect(Rect2i(16 + i * 12, 40 - i * 10, 8, 10 + i * 10), w)
		"bars_h":
			for i in 3:
				img.fill_rect(Rect2i(14, 16 + i * 12, 16 + i * 8, 7), w)
		"tank":
			img.fill_rect(Rect2i(22, 14, 20, 38), w)
			img.fill_rect(Rect2i(27, 9, 10, 6), w)
		"shield", "ring", "drift", "flame", "bolt", "twin", "crosshair", "magnet":
			for x in size:
				for y in size:
					var p := Vector2(x - 31.5, y - 31.5)
					var on := false
					match symbol:
						"shield":
							on = absf(p.x) < 15.0 - maxf(p.y, 0.0) * 0.5 and p.y > -16.0 and p.y < 20.0
						"ring":
							on = p.length() < 18.0 and p.length() > 10.0
						"drift":
							on = absf(p.x + p.y) < 5.0 and p.length() < 20.0 or absf(p.x + p.y - 14.0) < 4.0 and p.length() < 16.0
						"flame":
							on = p.y > -18.0 and p.y < 16.0 and absf(p.x) < (p.y + 18.0) * 0.42
						"bolt":
							on = (absf(p.x - p.y * 0.4 + 4.0) < 5.0 and p.y < 2.0 and p.y > -18.0) or (absf(p.x - p.y * 0.4 - 4.0) < 5.0 and p.y >= -2.0 and p.y < 18.0)
						"twin":
							on = (absf(p.y + 6.0) < 3.5 or absf(p.y - 6.0) < 3.5) and p.x > -18.0 and p.x < 18.0 or (p.x < -6.0 and p.x > -18.0 and absf(p.y) < 12.0)
						"magnet":
							on = (p.y > -6.0 and p.y < 12.0 and absf(p.x) > 6.0 and absf(p.x) < 15.0) or (p.y >= 12.0 and p.y < 19.0 and absf(p.x) > 6.0 and absf(p.x) < 15.0) or (p.y <= -6.0 and p.length() < 15.0 and p.length() > 6.0)
						"crosshair":
							on = (p.length() < 17.0 and p.length() > 12.5) or (absf(p.x) < 2.5 and absf(p.y) < 21.0 and absf(p.y) > 6.0) or (absf(p.y) < 2.5 and absf(p.x) < 21.0 and absf(p.x) > 6.0) or p.length() < 2.5
					if on:
						img.set_pixel(x, y, w)
	return ImageTexture.create_from_image(img)
