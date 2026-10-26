extends "res://tools/builder_assets.gd"
## UI scenes, dungeon rooms, and the Dungeon / Garage / Tutorial levels. Entry point: build_all().

## Rooms are ROOM_HALF * 2 metres square (56 m). The DungeonGenerator cell size matches.
const ROOM_HALF := 28.0
const DOOR_GAP := 8.0
const WALL_HEIGHT := 4.0
const LOW_WALL_HEIGHT := 2.0
const TUTORIAL_HALF_WIDTH := 10.0
const WALL_COLLIDER_EXTRA := 12.0

var theme: Theme


func build_all() -> bool:
	var start := Time.get_ticks_msec()
	build_materials()
	build_sounds()
	build_models()
	build_effects()
	build_projectiles()
	build_hazards()
	build_weapons()
	build_player()
	build_enemies()
	build_upgrades()
	build_ui()
	build_rooms()
	build_dungeon()
	build_garage()
	build_tutorial()
	verify()
	print("BUILD FINISHED in %.1f s with %d error(s)" % [(Time.get_ticks_msec() - start) / 1000.0, error_count])
	return error_count == 0


# ==========================================================================
# UI
# ==========================================================================

func build_ui() -> void:
	print("UI")
	theme = _build_theme()
	_build_options_menu()
	_build_pause_menu()
	_build_hud()
	_build_shop_ui()
	_build_run_summary()
	_build_main_menu()


func _flat(bg: Color, border: Color, border_width: int, radius: int, margin: float) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	return sb


func _build_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 20
	var panel := _flat(Color(0.09, 0.07, 0.06, 0.94), Color(0.85, 0.5, 0.15), 2, 8, 18)
	t.set_stylebox("panel", "PanelContainer", panel)
	t.set_stylebox("panel", "Panel", panel)
	t.set_stylebox("normal", "Button", _flat(Color(0.2, 0.13, 0.08), Color(0.55, 0.32, 0.12), 2, 6, 10))
	t.set_stylebox("hover", "Button", _flat(Color(0.34, 0.2, 0.1), Color(1.0, 0.6, 0.2), 2, 6, 10))
	t.set_stylebox("pressed", "Button", _flat(Color(0.5, 0.28, 0.08), Color(1.0, 0.75, 0.3), 2, 6, 10))
	t.set_stylebox("disabled", "Button", _flat(Color(0.14, 0.12, 0.11), Color(0.3, 0.28, 0.26), 2, 6, 10))
	var focus := _flat(Color(0, 0, 0, 0), Color(1.0, 0.85, 0.35), 3, 6, 10)
	focus.draw_center = false
	t.set_stylebox("focus", "Button", focus)
	t.set_color("font_color", "Button", Color(0.98, 0.9, 0.75))
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_focus_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(0.5, 0.47, 0.44))
	t.set_color("font_color", "Label", Color(0.96, 0.9, 0.8))
	t.set_color("font_outline_color", "Label", Color(0.05, 0.03, 0.02))
	t.set_constant("outline_size", "Label", 4)
	t.set_stylebox("background", "ProgressBar", _flat(Color(0, 0, 0, 0.6), Color(0.4, 0.3, 0.2), 1, 4, 0))
	t.set_stylebox("fill", "ProgressBar", _flat(Color(1.0, 0.55, 0.15), Color(0, 0, 0, 0), 0, 4, 0))
	t.set_stylebox("panel", "TabContainer", _flat(Color(0.12, 0.09, 0.07), Color(0.4, 0.25, 0.1), 1, 6, 12))
	t.set_stylebox("tab_selected", "TabContainer", _flat(Color(0.5, 0.27, 0.08), Color(1.0, 0.6, 0.2), 1, 4, 10))
	t.set_stylebox("tab_unselected", "TabContainer", _flat(Color(0.18, 0.12, 0.08), Color(0.35, 0.22, 0.1), 1, 4, 10))
	t.set_stylebox("tab_hovered", "TabContainer", _flat(Color(0.3, 0.18, 0.08), Color(0.8, 0.5, 0.2), 1, 4, 10))
	t.set_stylebox("slider", "HSlider", _flat(Color(0.2, 0.15, 0.1), Color(0, 0, 0, 0), 0, 3, 3))
	t.set_stylebox("grabber_area", "HSlider", _flat(Color(1.0, 0.55, 0.15), Color(0, 0, 0, 0), 0, 3, 3))
	t.set_stylebox("grabber_area_highlight", "HSlider", _flat(Color(1.0, 0.7, 0.3), Color(0, 0, 0, 0), 0, 3, 3))
	return save_res(t, "res://ui/ui_theme.tres") as Theme


func _dimmer(parent: Node) -> ColorRect:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	full_rect(dim)
	attach(parent, dim, "Dim")
	return dim


func _centered_panel(parent: Node, min_size: Vector2) -> VBoxContainer:
	var center := CenterContainer.new()
	full_rect(center)
	attach(parent, center, "Center")
	var panel := PanelContainer.new()
	panel.custom_minimum_size = min_size
	attach(center, panel, "Panel")
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 14)
	attach(panel, vbox, "VBox")
	return vbox


func _title(parent: Node, text: String, size: int) -> Label:
	var l := label(parent, text, size, "Title")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", Color(1.0, 0.65, 0.2))
	return l


func _build_options_menu() -> void:
	var root := with_script(Control.new(), "ui/OptionsMenu.gd") as Control
	root.name = "OptionsMenu"
	root.theme = theme
	full_rect(root)
	_dimmer(root)
	var vbox := _centered_panel(root, Vector2(480, 0))
	_title(vbox, "OPTIONS", 32)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 12)
	attach(vbox, grid, "Grid")
	var sliders := {}
	for bus in ["Master", "Music", "SFX"]:
		label(grid, bus, 20, bus + "Label")
		var slider := HSlider.new()
		slider.custom_minimum_size = Vector2(260, 28)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		attach(grid, slider, bus + "Slider")
		sliders[bus] = slider
	var fullscreen := CheckButton.new()
	fullscreen.text = "Fullscreen"
	attach(vbox, fullscreen, "Fullscreen")
	var vsync := CheckButton.new()
	vsync.text = "V-Sync"
	attach(vbox, vsync, "VSync")
	var back := button(vbox, "Back", "BackButton")
	set_props(root, {"master_slider": sliders["Master"], "music_slider": sliders["Music"], "sfx_slider": sliders["SFX"],
		"fullscreen_toggle": fullscreen, "vsync_toggle": vsync, "back_button": back})
	save_scene(root, "res://scenes/ui/OptionsMenu.tscn", "OptionsMenu")


func _build_pause_menu() -> void:
	var root := with_script(CanvasLayer.new(), "ui/PauseMenu.gd")
	root.name = "PauseMenu"
	var panel_root := Control.new()
	panel_root.theme = theme
	full_rect(panel_root)
	attach(root, panel_root, "Root")
	_dimmer(panel_root)
	var vbox := _centered_panel(panel_root, Vector2(360, 0))
	_title(vbox, "PAUSED", 36)
	var resume := button(vbox, "Resume", "ResumeButton")
	var options := button(vbox, "Options", "OptionsButton")
	var abandon := button(vbox, "Abandon Run", "AbandonButton")
	var menu := button(vbox, "Main Menu", "MainMenuButton")
	var options_menu := instance_control("OptionsMenu", root)
	set_props(root, {"panel": panel_root, "resume_button": resume, "options_button": options, "abandon_button": abandon,
		"main_menu_button": menu, "options_menu": options_menu})
	save_scene(root, "res://scenes/ui/PauseMenu.tscn", "PauseMenu")


func instance_control(key: String, parent: Node) -> Node:
	var node: Node = (scenes[key] as PackedScene).instantiate()
	attach(parent, node)
	return node


func _build_hud() -> void:
	var root := with_script(CanvasLayer.new(), "ui/HUD.gd")
	root.name = "HUD"
	var ui := Control.new()
	ui.theme = theme
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full_rect(ui)
	attach(root, ui, "Root")

	var stats := PanelContainer.new()
	place(stats, Vector4(0, 0, 0, 0), Vector4(16, 16, 420, 110))
	stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	attach(ui, stats, "Stats")
	var rows := VBoxContainer.new()
	attach(stats, rows, "Rows")
	var bars := {}
	for entry in [["HULL", Color(0.9, 0.2, 0.15)], ["NITRO", Color(0.3, 0.85, 1.0)]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		attach(rows, row, entry[0] + "Row")
		var name_label := label(row, entry[0], 18, "Name")
		name_label.custom_minimum_size = Vector2(70, 0)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(220, 22)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		bar.value = 100
		bar.add_theme_stylebox_override("fill", _flat(entry[1], Color(0, 0, 0, 0), 0, 4, 0))
		attach(row, bar, "Bar")
		bars[entry[0]] = bar
		if entry[0] == "HULL":
			bars["HULL_LABEL"] = label(row, "100 / 100", 18, "Value")

	var scrap_panel := PanelContainer.new()
	place(scrap_panel, Vector4(1, 0, 1, 0), Vector4(-240, 16, -16, 70))
	attach(ui, scrap_panel, "ScrapPanel")
	var scrap := label(scrap_panel, "Scrap: 0", 26, "ScrapLabel")
	scrap.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	scrap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var combo_panel := PanelContainer.new()
	place(combo_panel, Vector4(1, 0, 1, 0), Vector4(-380, 100, -16, 214))
	combo_panel.visible = false
	attach(ui, combo_panel, "ComboPanel")
	var combo_box := VBoxContainer.new()
	attach(combo_panel, combo_box, "VBox")
	var combo_label := label(combo_box, "x1 COMBO", 36, "ComboLabel")
	combo_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	combo_label.add_theme_color_override("font_color", Color(1.0, 0.62, 0.15))
	combo_label.add_theme_constant_override("outline_size", 8)
	var combo_detail := label(combo_box, "", 18, "ComboDetail")
	combo_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var combo_bar := ProgressBar.new()
	combo_bar.custom_minimum_size = Vector2(0, 8)
	combo_bar.show_percentage = false
	combo_bar.add_theme_stylebox_override("fill", _flat(Color(1.0, 0.8, 0.25), Color(0, 0, 0, 0), 0, 3, 0))
	attach(combo_box, combo_bar, "ComboBar")

	var speed := label(ui, "0 km/h", 28, "SpeedLabel")
	speed.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	place(speed, Vector4(1, 1, 1, 1), Vector4(-260, -64, -24, -20))

	var message := label(ui, "", 32, "MessageLabel")
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_constant_override("outline_size", 10)
	message.add_theme_color_override("font_color", Color(1.0, 0.92, 0.75))
	place(message, Vector4(0, 0, 1, 0), Vector4(160, 120, -160, 230))

	var hint := label(ui, "W/S drive  |  A/D steer  |  SPACE drift  |  SHIFT nitro  |  E rocket  |  ESC pause", 16, "Hint")
	hint.modulate = Color(1, 1, 1, 0.65)
	place(hint, Vector4(0, 1, 0, 1), Vector4(20, -44, 1000, -16))

	for node in ui.find_children("*", "Control", true, false):
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_props(root, {"health_bar": bars["HULL"], "health_label": bars["HULL_LABEL"], "boost_bar": bars["NITRO"],
		"scrap_label": scrap, "speed_label": speed, "message_label": message,
		"combo_panel": combo_panel, "combo_label": combo_label, "combo_detail_label": combo_detail, "combo_bar": combo_bar})
	save_scene(root, "res://scenes/ui/HUD.tscn", "HUD")


func _build_shop_ui() -> void:
	var root := with_script(Control.new(), "ui/ShopUI.gd") as Control
	root.name = "ShopUI"
	root.theme = theme
	full_rect(root)
	_dimmer(root)
	var vbox := _centered_panel(root, Vector2(960, 620))
	var header := HBoxContainer.new()
	attach(vbox, header, "Header")
	var title := _title(header, "GARAGE SHOP", 32)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	var scrap := label(header, "Scrap: 0", 26, "ScrapLabel")
	scrap.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(0, 440)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	attach(vbox, tabs, "Tabs")
	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 16)
	attach(vbox, footer, "Footer")
	var feedback := label(footer, "", 22, "FeedbackLabel")
	feedback.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hint := label(footer, "ESC / TAB to close", 16, "Hint")
	hint.modulate = Color(1, 1, 1, 0.6)
	var close := button(footer, "Close", "CloseButton")
	close.custom_minimum_size = Vector2(160, 46)
	var ui_audio := AudioStreamPlayer.new()
	ui_audio.bus = &"SFX"
	attach(root, ui_audio, "UIAudio")
	set_props(root, {"tab_container": tabs, "scrap_label": scrap, "feedback_label": feedback, "close_button": close,
		"ui_audio_player": ui_audio, "purchase_sound": sounds["purchase"], "error_sound": sounds["error"]})
	save_scene(root, "res://scenes/ui/ShopUI.tscn", "ShopUI")


func _build_run_summary() -> void:
	var root := with_script(Control.new(), "ui/RunSummary.gd") as Control
	root.name = "RunSummary"
	root.theme = theme
	full_rect(root)
	_dimmer(root)
	var vbox := _centered_panel(root, Vector2(540, 0))
	var title := _title(vbox, "RUN COMPLETE", 42)
	var subtitle := label(vbox, "Depth 1", 22, "Subtitle")
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.modulate = Color(1, 1, 1, 0.75)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	grid.add_theme_constant_override("v_separation", 8)
	attach(vbox, grid, "Stats")
	var score := label(vbox, "SCORE 0", 40, "Score")
	score.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score.add_theme_color_override("font_color", Color(1.0, 0.65, 0.2))
	score.add_theme_constant_override("outline_size", 8)
	var best := label(vbox, "", 22, "Best")
	best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var continue_button := button(vbox, "Continue", "ContinueButton")
	set_props(root, {"title_label": title, "subtitle_label": subtitle, "stats_grid": grid, "score_label": score,
		"best_label": best, "continue_button": continue_button})
	save_scene(root, "res://scenes/ui/RunSummary.tscn", "RunSummary")


func _build_main_menu() -> void:
	var root := with_script(Control.new(), "ui/MainMenu.gd") as Control
	root.name = "MainMenu"
	root.theme = theme
	full_rect(root)

	var container := SubViewportContainer.new()
	container.stretch = true
	full_rect(container)
	attach(root, container, "Backdrop")
	var viewport := SubViewport.new()
	viewport.size = Vector2i(1600, 900)
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_2X
	attach(container, viewport, "SubViewport")
	var stage := node3d("Showcase", viewport)
	environment_node(stage, Color(0.05, 0.035, 0.03), Color(0.6, 0.45, 0.35), 0.5, 0.0, 0.9)
	sun(stage, Color(1.0, 0.8, 0.6), 0.9, Vector3(-40, -20, 0))
	var floor_mesh := lp(301)
	floor_mesh.cylinder(T(Vector3(0, -0.15, 0)), 6.0, 6.5, 0.3, 10, C.stone_dark)
	floor_mesh.cylinder(T(Vector3(0, 0.02, 0)), 4.0, 4.0, 0.06, 10, C.stone)
	for i in 10:
		var angle := TAU * i / 10.0
		floor_mesh.sphere(T(Vector3(cos(angle) * 5.6, 0.2, sin(angle) * 5.6)), 0.45, C.stone_dark, "main", 0, 0.3)
	mesh_node("Plinth", floor_mesh.commit(), stage, Vector3(2.4, 0, 0))
	var buggy := node3d("Buggy", stage, Vector3(2.4, 0.06, 0), Vector3(0, -30, 0))
	with_script(buggy, "effects/Spin.gd", {"speed": Vector3(0, 0.35, 0)})
	mesh_node("Body", meshes["buggy_body"], buggy)
	for x in [-0.95, 0.95]:
		for z in [-1.05, 1.05]:
			mesh_node("Wheel", meshes["wheel"], buggy, Vector3(x, 0.45, z))
	mesh_node("Turret", meshes["autocannon"], buggy, Vector3(0, 1.88, 0.35))
	mesh_node("Rockets", meshes["rocket_pod"], buggy, Vector3(0, 0.97, -1.0))
	omni(stage, Vector3(5.5, 3.0, 2.5), Color(1.0, 0.6, 0.3), 4.0, 12.0, "KeyLight")
	omni(stage, Vector3(-1.0, 2.5, -3.0), Color(0.3, 0.7, 1.0), 3.0, 10.0, "RimLight")
	instance("Torch", stage, Vector3(-0.5, 1.5, -4.2))
	var camera := Camera3D.new()
	camera.fov = 50.0
	attach(stage, camera, "Camera")
	camera.position = Vector3(0, 3.0, 8.0)
	camera.rotation_degrees = Vector3(-14, 0, 0)

	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", 12)
	place(menu, Vector4(0, 0.5, 0, 0.5), Vector4(80, -330, 520, 330))
	attach(root, menu, "Menu")
	var title := label(menu, "TORQUE\n& TOMBS", 76, "Title")
	title.add_theme_color_override("font_color", Color(1.0, 0.6, 0.15))
	title.add_theme_constant_override("outline_size", 14)
	var subtitle := label(menu, "Drive. Drift. Loot the tombs.", 22, "Subtitle")
	subtitle.modulate = Color(1, 1, 1, 0.8)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 16)
	attach(menu, spacer, "Spacer")
	var play := button(menu, "Play", "PlayButton")
	var tutorial := button(menu, "Tutorial", "TutorialButton")
	var options := button(menu, "Options", "OptionsButton")
	var reset := button(menu, "Reset Save", "ResetButton")
	var quit := button(menu, "Quit", "QuitButton")
	var scrap := label(menu, "Scrap: 0", 20, "ScrapLabel")
	scrap.add_theme_color_override("font_color", Color(1.0, 0.8, 0.3))
	var options_menu := instance_control("OptionsMenu", root)
	set_props(root, {"play_button": play, "tutorial_button": tutorial, "options_button": options, "reset_button": reset,
		"quit_button": quit, "main_panel": menu, "options_menu": options_menu, "scrap_label": scrap})
	save_scene(root, "res://scenes/ui/MainMenu.tscn", "MainMenu")


# ==========================================================================
# Room building helpers
# ==========================================================================

func _room_begin(room_name: String, script_file: String, seed_value: int, props: Dictionary = {}) -> Dictionary:
	var root := with_script(Node3D.new(), script_file, props) as Node3D
	root.name = room_name
	root.set("room_footprint", Vector2(ROOM_HALF * 2.0, ROOM_HALF * 2.0))
	var region := NavigationRegion3D.new()
	region.name = "NavigationRegion3D"
	region.navigation_mesh = new_navmesh()
	var body := static_body("Geometry", region)
	return {"root": root, "region": region, "body": body, "lp": lp(seed_value), "key": room_name}


func _room_finish(ctx: Dictionary, path: String) -> void:
	var region: NavigationRegion3D = ctx.region
	var mesh := save_res((ctx.lp as LowPolyMesh).commit(), "res://models/rooms/%s.tres" % ctx.key) as Mesh
	mesh_node("GeometryMesh", mesh, region)
	var polygons := bake_region(region)
	if polygons == 0:
		fail("Navmesh for %s is empty" % ctx.key)
	print("    %s navmesh polygons: %d" % [ctx.key, polygons])
	var root: Node3D = ctx.root
	root.add_child(region)
	root.move_child(region, 0)
	save_scene(root, path, ctx.key)


## Tiled stone floor. `rect` is in X/Z. `pattern` tints tiles ("arena", "exit").
func _tile_floor(ctx: Dictionary, rect: Rect2, top: float = 0.0, thickness: float = 1.0, tint: Color = C.floor, tile: float = 5.0, pattern: String = "", collide: bool = true) -> void:
	var m: LowPolyMesh = ctx.lp
	var center := rect.get_center()
	var nx := maxi(int(round(rect.size.x / tile)), 1)
	var nz := maxi(int(round(rect.size.y / tile)), 1)
	var tw := rect.size.x / nx
	var td := rect.size.y / nz
	m.box(T(Vector3(center.x, top - 0.16, center.y)), Vector3(rect.size.x, 0.1, rect.size.y), C.grout)
	for ix in nx:
		for iz in nz:
			var cx := rect.position.x + tw * (ix + 0.5)
			var cz := rect.position.y + td * (iz + 0.5)
			var color := tint.lerp(C.stone_dark, m.rng.randf() * 0.3)
			var dist := Vector2(cx, cz).length()
			if pattern == "arena" and dist > 5.0 and dist < 9.5:
				color = Color(0.5, 0.24, 0.16).lerp(color, 0.35)
			elif pattern == "exit" and dist < 9.0:
				color = C.purple_dark.lerp(color, 0.5)
			m.box(T(Vector3(cx, top - 0.09, cz)), Vector3(tw - 0.12, 0.18, td - 0.12), color)
	if thickness > 0.4:
		m.box(T(Vector3(center.x, top - 0.21 - (thickness - 0.21) * 0.5, center.y)), Vector3(rect.size.x, thickness - 0.21, rect.size.y), C.stone_dark)
	if collide:
		collision(ctx.body, box_shape(Vector3(rect.size.x, thickness, rect.size.y)), Vector3(center.x, top - thickness * 0.5, center.y))


## Stone wall / block built from staggered blocks. `center` is the box center.
func _wall(ctx: Dictionary, center: Vector3, size: Vector3, collide: bool = true, cap: bool = true) -> void:
	var m: LowPolyMesh = ctx.lp
	var along_x := size.x >= size.z
	var length := size.x if along_x else size.z
	var depth := size.z if along_x else size.x
	var rows := maxi(int(round(size.y)), 1)
	var row_height := size.y / rows
	for row in rows:
		var pos := -length * 0.5 - (0.0 if row % 2 == 0 else 0.7)
		while pos < length * 0.5 - 0.01:
			var segment := 1.4 + m.rng.randf() * 1.3
			var start := maxf(pos, -length * 0.5)
			var finish := minf(pos + segment, length * 0.5)
			if finish - start > 0.08:
				var mid := (start + finish) * 0.5
				var y := center.y - size.y * 0.5 + row_height * (row + 0.5)
				var color: Color = C.stone.lerp(C.stone_dark, m.rng.randf() * 0.7)
				if m.rng.randf() < 0.07:
					color = C.moss.lerp(color, 0.45)
				var d := depth + m.rng.randf_range(-0.04, 0.1)
				var p := Vector3(center.x + (mid if along_x else 0.0), y, center.z + (0.0 if along_x else mid))
				var s := Vector3(finish - start - 0.06, row_height - 0.06, d) if along_x else Vector3(d, row_height - 0.06, finish - start - 0.06)
				m.box(T(p), s, color)
			pos += segment
	if cap:
		m.box(T(Vector3(center.x, center.y + size.y * 0.5 + 0.12, center.z)), Vector3(size.x + 0.2, 0.25, size.z + 0.2), C.stone_light)
	if collide:
		# Invisible extra height so boost jumps can't sail over walls.
		collision(ctx.body, box_shape(size + Vector3(0, WALL_COLLIDER_EXTRA, 0)), center + Vector3(0, WALL_COLLIDER_EXTRA * 0.5, 0))


func _room_shell(ctx: Dictionary, with_floor: bool = true, pattern: String = "", tint: Color = C.floor) -> void:
	var m: LowPolyMesh = ctx.lp
	var h := ROOM_HALF
	if with_floor:
		_tile_floor(ctx, Rect2(-h, -h, h * 2.0, h * 2.0), 0.0, 1.0, tint, 5.0, pattern)
	var segment := (h * 2.0 - DOOR_GAP) * 0.5
	var offset := DOOR_GAP * 0.5 + segment * 0.5
	for side in [-1.0, 1.0]:
		for s in [-1.0, 1.0]:
			# The south (+Z) wall faces the camera, so keep it low to avoid hiding the action.
			var height := WALL_HEIGHT if side < 0.0 else LOW_WALL_HEIGHT
			_wall(ctx, Vector3(s * offset, height * 0.5, side * (h - 0.5)), Vector3(segment, height, 1.0))
			_wall(ctx, Vector3(side * (h - 0.5), WALL_HEIGHT * 0.5, s * offset), Vector3(1.0, WALL_HEIGHT, segment))
	# Doorway and corner pillars, rubble in the corners
	for side in [-1.0, 1.0]:
		for s in [-1.0, 1.0]:
			for p in [Vector3(s * 4.8, 0, side * (h - 0.6)), Vector3(side * (h - 0.6), 0, s * 4.8)]:
				m.box(T(p + Vector3(0, 2.3, 0)), Vector3(1.2, 4.6, 1.2), C.stone_dark)
				m.box(T(p + Vector3(0, 4.7, 0)), Vector3(1.5, 0.3, 1.5), C.stone_light)
			m.box(T(Vector3(s * (h - 0.8), 2.6, side * (h - 0.8))), Vector3(1.8, 5.2, 1.8), C.stone_dark)
			m.box(T(Vector3(s * (h - 0.8), 5.3, side * (h - 0.8))), Vector3(2.1, 0.3, 2.1), C.stone_light)
			for i in 3:
				var rock_pos := Vector3(s * (h - 2.6 - m.rng.randf() * 1.5), 0.2, side * (h - 2.6 - m.rng.randf() * 1.5))
				m.sphere(T(rock_pos, Vector3(0, m.rng.randf() * 90.0, 0), Vector3(1, 0.7, 1)), 0.3 + m.rng.randf() * 0.35, C.stone_dark, "main", 0, 0.3)
	_sockets(ctx)
	var trigger := make_area("EntranceTrigger", ctx.root, L_TRIGGER, L_PLAYER)
	collision(trigger, box_shape(Vector3(h * 2.0 - 8.0, 4, h * 2.0 - 8.0)), Vector3(0, 2, 0))


func _sockets(ctx: Dictionary) -> void:
	var sockets := node3d("Sockets", ctx.root)
	var h := ROOM_HALF
	var data := {"North": [Vector3(0, 0, -h), 0.0], "East": [Vector3(h, 0, 0), -90.0], "South": [Vector3(0, 0, h), 180.0], "West": [Vector3(-h, 0, 0), 90.0]}
	for socket_name in data:
		var socket := marker(socket_name, sockets, data[socket_name][0], Vector3(0, data[socket_name][1], 0))
		var blocker := static_body("Blocker", socket)
		collision(blocker, box_shape(Vector3(8.2, 4.0 + WALL_COLLIDER_EXTRA, 1.0)), Vector3(0, 2.0 + WALL_COLLIDER_EXTRA * 0.5, 0.5))
		mesh_node("Mesh", meshes["blocker"], blocker, Vector3(0, 0, 0.5))


func _torches(ctx: Dictionary) -> void:
	var x := ROOM_HALF * 0.5
	for spot in [Vector2(-x, -1), Vector2(x, -1), Vector2(-x, 1), Vector2(x, 1)]:
		var z: float = spot.y * (ROOM_HALF - 1.05)
		var height := 2.6 if spot.y < 0 else 1.3
		instance("Torch", ctx.root, Vector3(spot.x, height, z), Vector3(0, 0.0 if spot.y < 0 else 180.0, 0))


## Scales a layout position designed for the old 40 m room to the current room size.
func S(v: Vector3) -> Vector3:
	var k := ROOM_HALF / 20.0
	return Vector3(v.x * k, v.y, v.z * k)


func _crate(parent: Node, position: Vector3, key: String = "LootCrate") -> void:
	instance(key, parent, position, Vector3(0, randf() * 40.0 - 20.0, 0))


func _wave(groups: Array, delay: float = 1.5, interval: float = 0.5) -> WaveData:
	var wave := WaveData.new()
	var typed: Array[SpawnGroup] = []
	for g in groups:
		var spawn_group := SpawnGroup.new()
		spawn_group.enemy_scene = scenes[g[0]]
		spawn_group.count = g[1]
		typed.append(spawn_group)
	wave.groups = typed
	wave.delay_before_wave = delay
	wave.spawn_interval = interval
	return wave


func _spawner(parent: Node, waves: Array[WaveData], radius: float = ROOM_HALF * 0.7) -> Node:
	var spawner := WaveSpawner.new()
	spawner.name = "WaveSpawner"
	parent.add_child(spawner)
	spawner.waves = waves
	spawner.spawn_effect = scenes["SpawnPuff"]
	for i in 8:
		var angle := TAU * i / 8.0 + PI / 8.0
		marker("SpawnPoint%d" % (i + 1), spawner, Vector3(cos(angle) * radius, 0.6, sin(angle) * radius))
	return spawner


## A WaveSpawner that rolls random waves every time it starts (see WaveSpawner.generate_waves).
## Costs are threat points; the wave budget grows with wave number and run depth.
func _random_spawner(parent: Node, radius: float, min_waves: int, max_waves: int, boss_key: String = "") -> Node:
	var empty: Array[WaveData] = []
	var spawner := _spawner(parent, empty, radius)
	var options: Array[WaveEnemyOption] = []
	for entry in [["RammerEnemy", 2.0, 3.0, 0], ["FireCaster", 3.0, 2.0, 0], ["MortarBuggy", 5.0, 1.2, 0],
			["Juggernaut", 14.0, 0.35, 3], ["PyreArchon", 16.0, 0.2, 5], ["SiegeCrawler", 16.0, 0.2, 5]]:
		var option := WaveEnemyOption.new()
		option.enemy_scene = scenes[entry[0]]
		option.cost = entry[1]
		option.weight = entry[2]
		option.min_depth = entry[3]
		options.append(option)
	set_props(spawner, {"randomize_waves": true, "enemy_options": options, "min_waves": min_waves, "max_waves": max_waves,
		"boss_scene": scenes[boss_key] if boss_key != "" else null})
	return spawner


func make_lava_pit(parent: Node, node_name: String, size: Vector2, position: Vector3) -> Area3D:
	var pit := make_area(node_name, parent, L_TRIGGER, L_PLAYER | L_ENEMY, position)
	with_script(pit, "hazards/LavaPit.gd", {"damage": 30.0, "respawn_delay": 0.75, "splash_effect": scenes["FireImpact"],
		"splash_sound": sounds["fireball"]})
	collision(pit, box_shape(Vector3(size.x, 1.6, size.y)))
	var lava := lp(int(size.x * 10 + size.y))
	lava.jitter = 0.18
	lava.grid(T(Vector3.ZERO), size.x, size.y, maxi(int(size.x / 1.5), 2), maxi(int(size.y / 1.5), 2), Color(1.0, 0.5, 0.12), "lava", 0.12)
	mesh_node("LavaMesh", lava.commit(), pit)
	omni(pit, Vector3(0, 1.8, 0), Color(1.0, 0.45, 0.1), 3.0, maxf(size.x, size.y) * 0.9)
	particles("Embers", pit, {"amount": 24, "lifetime": 2.0, "spread": 15.0, "vel_min": 0.5, "vel_max": 1.5, "gravity": Vector3(0, 0.6, 0),
		"radius": minf(size.x, size.y) * 0.45, "size": 0.1, "color": Color(1, 0.6, 0.2), "color_end": Color(1, 0.2, 0.0, 0), "mat": "particle_glow"})
	return pit


# ==========================================================================
# Rooms (all ROOM_HALF * 2 wide; layouts scale with ROOM_HALF)
# ==========================================================================

func build_rooms() -> void:
	print("Rooms")
	_room_start()
	_room_maze_a()
	_room_maze_b()
	_room_platform()
	_room_arena()
	_room_treasure()
	_room_exit("ExitRoom", "Juggernaut", "The Juggernaut awakens!", 71)
	_room_exit("ExitRoomArchon", "PyreArchon", "The Pyre Archon rises from the flames!", 72)
	_room_exit("ExitRoomSiege", "SiegeCrawler", "The Siege Crawler rumbles in!", 73)
	var seed_value := 80
	for hazard in ["Lava", "Spike"]:
		for heading in ["North", "South", "East", "West"]:
			seed_value += 1
			_room_gauntlet("Gauntlet%s%s" % [hazard, heading], hazard, heading, seed_value)


func _room_start() -> void:
	var ctx := _room_begin("StartRoom", "world/BaseRoom.gd", 11)
	_room_shell(ctx)
	marker("PlayerSpawn", ctx.root, Vector3(0, 0.3, 6))
	label3d(ctx.root, "TORQUE & TOMBS", Vector3(0, 0.06, -7), Vector3(-90, 0, 0), 280, Color(1.0, 0.7, 0.3, 0.75))
	_crate(ctx.root, S(Vector3(-13, 0.7, -13)))
	_crate(ctx.root, S(Vector3(13, 0.7, 13)))
	_crate(ctx.root, S(Vector3(14.5, 0.7, 11.5)))
	_torches(ctx)
	_room_finish(ctx, "res://scenes/world/rooms/StartRoom.tscn")


func _room_maze_a() -> void:
	var ctx := _room_begin("MazeRoomA", "world/BaseRoom.gd", 21)
	_room_shell(ctx)
	var k := ROOM_HALF / 20.0
	for x in [-8.5, 8.5]:
		for z in [-8.5, 8.5]:
			_wall(ctx, S(Vector3(x, 2, z)), Vector3(7 * k, 4, 7 * k))
	instance("SpikeTrap", ctx.root, S(Vector3(15.5, 0, 8.5)))
	instance("SpikeTrap", ctx.root, S(Vector3(-15.5, 0, -8.5)), Vector3.ZERO, {"start_delay": 1.0})
	instance("SpikeTrap", ctx.root, Vector3.ZERO, Vector3.ZERO, {"mode": 1})
	var crawler := {"max_health": 22.0, "aggro_range": 24.0, "scrap_reward": 2}
	instance("RammerEnemy", ctx.root, S(Vector3(15.5, 0.3, -15.5)), Vector3.ZERO, crawler)
	instance("RammerEnemy", ctx.root, S(Vector3(-15.5, 0.3, 15.5)), Vector3.ZERO, crawler)
	_crate(ctx.root, S(Vector3(15.5, 0.7, 15.5)))
	_crate(ctx.root, S(Vector3(-15.5, 0.7, -15.5)))
	_torches(ctx)
	_room_finish(ctx, "res://scenes/world/rooms/MazeRoomA.tscn")


func _room_maze_b() -> void:
	var ctx := _room_begin("MazeRoomB", "world/BaseRoom.gd", 31)
	_room_shell(ctx)
	var k := ROOM_HALF / 20.0
	_wall(ctx, S(Vector3(-6.5, 2, -7)), Vector3(25 * k + 0.6, 4, 1.5))
	_wall(ctx, S(Vector3(6.5, 2, 7)), Vector3(25 * k + 0.6, 4, 1.5))
	instance("SpikeTrap", ctx.root, S(Vector3(12.5, 0, -7)), Vector3.ZERO, {"mode": 1})
	instance("SpikeTrap", ctx.root, S(Vector3(-12.5, 0, 7)), Vector3.ZERO, {"start_delay": 0.5})
	instance("FireCaster", ctx.root, Vector3(0, 0.3, 0), Vector3.ZERO, {"aggro_range": 26.0})
	instance("RammerEnemy", ctx.root, S(Vector3(-14, 0.3, -14)), Vector3.ZERO, {"max_health": 22.0, "aggro_range": 24.0, "scrap_reward": 2})
	_crate(ctx.root, S(Vector3(16, 0.7, -15)))
	_crate(ctx.root, S(Vector3(-16, 0.7, 15)))
	_torches(ctx)
	_room_finish(ctx, "res://scenes/world/rooms/MazeRoomB.tscn")


func _room_platform() -> void:
	var ctx := _room_begin("PlatformRoom", "world/BaseRoom.gd", 41, {"enter_message": "Hit a boost pad to jump the lava!"})
	var h := ROOM_HALF
	var pool := 9.0 * ROOM_HALF / 20.0
	for rect in [Rect2(-h, -h, h * 2.0, h - pool), Rect2(-h, pool, h * 2.0, h - pool), Rect2(-h, -pool, h - pool, pool * 2.0), Rect2(pool, -pool, h - pool, pool * 2.0)]:
		_tile_floor(ctx, rect, 0.0, 2.5)
	_room_shell(ctx, false)
	var root: Node3D = ctx.root
	var pool_floor := static_body("PoolFloor", root)
	pool_floor.add_to_group("unsafe_ground", true)
	collision(pool_floor, box_shape(Vector3(pool * 2.0, 0.5, pool * 2.0)), Vector3(0, -2.75, 0))
	(ctx.lp as LowPolyMesh).box(T(Vector3(0, -2.75, 0)), Vector3(pool * 2.0, 0.5, pool * 2.0), C.black)
	make_lava_pit(root, "LavaPit", Vector2(pool * 2.0, pool * 2.0), Vector3(0, -1.4, 0))
	# Two jump lanes aimed across the lava, set beside the doorways (not in front of them):
	# south -> north at x = +9 and west -> east at z = -9.
	var lane := 9.0
	instance("Ramp", root, Vector3(lane, 0, pool + 2.25))
	instance("BoostPad", root, Vector3(lane, 0, pool + 7.0), Vector3.ZERO, {"boost_speed": 30.0})
	instance("Ramp", root, Vector3(-(pool + 2.25), 0, -lane), Vector3(0, -90, 0))
	instance("BoostPad", root, Vector3(-(pool + 7.0), 0, -lane), Vector3(0, -90, 0), {"boost_speed": 30.0})
	_crate(root, S(Vector3(-15, 0.7, -15)))
	_crate(root, S(Vector3(15, 0.7, -15)))
	_torches(ctx)
	_room_finish(ctx, "res://scenes/world/rooms/PlatformRoom.tscn")


func _room_arena() -> void:
	var ctx := _room_begin("ArenaRoom", "world/ArenaRoom.gd", 51, {"clear_scrap_bonus": 8})
	_room_shell(ctx, true, "arena")
	var p := ROOM_HALF * 0.5
	for x in [-p, p]:
		for z in [-p, p]:
			_wall(ctx, Vector3(x, 2.5, z), Vector3(2.2, 5, 2.2))
			instance("Brazier", ctx.root, Vector3(x, 5.25, z))
	_random_spawner(ctx.root, ROOM_HALF * 0.7, 2, 4)
	var rewards := node3d("RewardPoints", ctx.root)
	marker("Reward1", rewards, Vector3(-5, 0.8, 0))
	marker("Reward2", rewards, Vector3(5, 0.8, 0))
	set_props(ctx.root, {"reward_crate_scene": scenes["LootCrate"], "scrap_pickup_scene": scenes["ScrapPickup"]})
	_room_finish(ctx, "res://scenes/world/rooms/ArenaRoom.tscn")


## Rare dead-end side room: gold crates and loose scrap worth roughly an extra upgrade or two.
func _room_treasure() -> void:
	var ctx := _room_begin("TreasureRoom", "world/BaseRoom.gd", 61, {"enter_message": "A treasure vault! Smash the gold crates."})
	_room_shell(ctx)
	for spot in [Vector3(-2.5, 0.7, -2.5), Vector3(2.5, 0.7, -2.5), Vector3(-2.5, 0.7, 2.5), Vector3(2.5, 0.7, 2.5)]:
		_crate(ctx.root, spot, "GoldCrate")
	for spot in [Vector3(0, 0.7, -6), Vector3(0, 0.7, 6), Vector3(-6, 0.7, 0)]:
		_crate(ctx.root, spot)
	var m: LowPolyMesh = ctx.lp
	for i in 12:
		var angle := TAU * i / 12.0 + 0.2
		var dist := 10.0 + m.rng.randf() * 4.0
		instance("ScrapPickup", ctx.root, Vector3(cos(angle) * dist, 0.4, sin(angle) * dist), Vector3.ZERO, {"value": 2})
	for i in 18:
		var angle := m.rng.randf() * TAU
		var dist := 7.0 + m.rng.randf() * 4.0
		var pile := T(Vector3(cos(angle) * dist, 0.1, sin(angle) * dist), Vector3(m.rng.randf() * 30.0, m.rng.randf() * 360.0, 0))
		m.cylinder(pile, 0.28, 0.28, 0.12, 8, C.gold, "metal")
	instance("SpikeTrap", ctx.root, S(Vector3(-9, 0, 0)))
	instance("SpikeTrap", ctx.root, S(Vector3(9, 0, 0)), Vector3.ZERO, {"start_delay": 1.0})
	_torches(ctx)
	_room_finish(ctx, "res://scenes/world/rooms/TreasureRoom.tscn")


func _room_exit(key: String, boss_key: String, boss_message: String, seed_value: int) -> void:
	var ctx := _room_begin(key, "world/ExitRoom.gd", seed_value, {"heavy_scrap_value": 25, "clear_scrap_bonus": 8,
		"lock_message": boss_message, "clear_message": "The guardian falls! Take the teleporter home."})
	_room_shell(ctx, true, "exit")
	var m: LowPolyMesh = ctx.lp
	var o := ROOM_HALF * 0.6
	for x in [-o, o]:
		for z in [-o, o]:
			_wall(ctx, Vector3(x, 3, z), Vector3(1.6, 6, 1.6))
			m.sphere(T(Vector3(x, 6.6, z)), 0.45, Color.WHITE, "glow_purple", 1)
			omni(ctx.root, Vector3(x, 6.6, z), Color(0.65, 0.3, 1.0), 2.5, 16.0, "ObeliskLight")
	var teleporter := instance("Teleporter", ctx.root, Vector3.ZERO)
	# Random warm-up waves; the final wave is always this room's boss plus random escorts.
	_random_spawner(ctx.root, ROOM_HALF * 0.72, 2, 3, boss_key)
	set_props(ctx.root, {"teleporter": teleporter, "scrap_pickup_scene": scenes["ScrapPickup"], "reward_crate_scene": scenes["LootCrate"]})
	var rewards := node3d("RewardPoints", ctx.root)
	marker("Reward1", rewards, Vector3(-7, 0.8, 7))
	marker("Reward2", rewards, Vector3(7, 0.8, 7))
	_torches(ctx)
	_room_finish(ctx, "res://scenes/world/rooms/%s.tscn" % key)


## One-way gauntlet: a 15 m lava / spike trench splits the room. The only way across is the boost
## pad + ramp lined up with the entry door (with ~11 m of floor to line up first).
## `heading` is the travel direction (North = toward -Z). The layout is designed heading North
## and rotated for the other directions; the room shell itself is not rotated, so the low
## camera-side wall stays on the south.
func _room_gauntlet(key: String, hazard: String, heading: String, seed_value: int) -> void:
	var ctx := _room_begin(key, "world/BaseRoom.gd", seed_value,
		{"enter_message": "No way around - hit the boost pad and jump the %s!" % ("lava" if hazard == "Lava" else "spikes")})
	var root: Node3D = ctx.root
	var m: LowPolyMesh = ctx.lp
	var h := ROOM_HALF
	var angle: float = {"North": 0.0, "West": 90.0, "South": 180.0, "East": -90.0}[heading]
	var basis := Basis(Vector3.UP, deg_to_rad(angle))
	var trench := 7.5
	var quarter_turn := absf(angle) == 90.0
	# Floor on both sides of the trench (3 m thick, so the trench has walls).
	for rect in [Rect2(-h, -h, h * 2.0, h - trench), Rect2(-h, trench, h * 2.0, h - trench)]:
		var r: Rect2 = rect
		if quarter_turn:
			r = Rect2(r.position.y, r.position.x, r.size.y, r.size.x)
		_tile_floor(ctx, r, 0.0, 3.0)
	_room_shell(ctx, false)
	# Side walls carry on down into the trench where they cross it.
	for side in [-1.0, 1.0]:
		var filler_size := Vector3(1, 3, trench * 2.0)
		m.box(T(basis * Vector3(side * (h - 0.5), -1.5, 0)), (basis * filler_size).abs(), C.stone_dark)
	var pit_size_3d := (basis * Vector3(h * 2.0 - 2.0, 0, trench * 2.0)).abs()
	var pit_size := Vector2(pit_size_3d.x, pit_size_3d.z)
	var pit_floor := static_body("PitFloor", root)
	pit_floor.add_to_group("unsafe_ground", true)
	collision(pit_floor, box_shape(Vector3(pit_size.x, 0.5, pit_size.y)), Vector3(0, -3.25, 0))
	m.box(T(Vector3(0, -3.25, 0)), Vector3(pit_size.x, 0.5, pit_size.y), C.black)
	if hazard == "Lava":
		make_lava_pit(root, "LavaPit", pit_size, Vector3(0, -1.6, 0))
	else:
		make_spike_pit(root, "SpikePit", pit_size, Vector3(0, -1.6, 0))
	# Ramp at the trench edge, two pads side by side covering the full doorway width.
	var yaw := Vector3(0, angle, 0)
	instance("Ramp", root, basis * Vector3(0, 0, trench + 2.25), yaw)
	for x in [-2.0, 2.0]:
		instance("BoostPad", root, basis * Vector3(x, 0, trench + 4.5 + 2.25), yaw, {"boost_speed": 24.0, "refill_boost": 30.0})
	label3d(root, "JUMP!", basis * Vector3(0, 0.06, trench + 10.5), Vector3(-90, angle, 0), 150, Color(0.4, 0.9, 1.0, 0.85))
	_torches(ctx)
	_room_finish(ctx, "res://scenes/world/rooms/gauntlets/%s.tscn" % key)


func make_spike_pit(parent: Node, node_name: String, size: Vector2, position: Vector3) -> Area3D:
	var pit := make_area(node_name, parent, L_TRIGGER, L_PLAYER | L_ENEMY, position)
	with_script(pit, "hazards/LavaPit.gd", {"damage": 25.0, "respawn_delay": 0.75, "splash_effect": scenes["SmallImpact"],
		"splash_sound": sounds["spike"]})
	collision(pit, box_shape(Vector3(size.x, 1.6, size.y)))
	var field := lp(int(size.x * 7 + size.y))
	field.jitter = 0.1
	var nx := int(size.x / 1.3)
	var nz := int(size.y / 1.3)
	for ix in nx:
		for iz in nz:
			var p := Vector3(-size.x * 0.5 + (ix + 0.5) * size.x / nx, 0, -size.y * 0.5 + (iz + 0.5) * size.y / nz)
			p += Vector3(field.rng.randf_range(-0.3, 0.3), 0, field.rng.randf_range(-0.3, 0.3))
			var height := field.rng.randf_range(1.0, 1.6)
			field.cylinder(T(p + Vector3(0, -1.4 + height * 0.5, 0)), 0.22, 0.0, height, 5, C.chrome, "metal")
			if field.rng.randf() < 0.15:
				field.sphere(T(p + Vector3(0.3, -1.25, 0.2)), 0.2, C.bone)
	mesh_node("Spikes", field.commit(), pit)
	omni(pit, Vector3(0, 0.5, 0), Color(0.9, 0.25, 0.15), 1.2, maxf(size.x, size.y) * 0.6)
	return pit


# ==========================================================================
# Levels
# ==========================================================================

func _camera(parent: Node) -> Camera3D:
	var camera := IsometricCamera.new()
	camera.name = "IsometricCamera"
	camera.current = true
	camera.fov = 55.0
	parent.add_child(camera)
	return camera


func build_dungeon() -> void:
	print("Dungeon")
	var root := node3d("Dungeon")
	environment_node(root, Color(0.035, 0.028, 0.03), Color(0.6, 0.48, 0.4), 0.5, 0.008, 0.8)
	sun(root, Color(1.0, 0.85, 0.7), 0.45)
	var generator := DungeonGenerator.new()
	generator.name = "DungeonGenerator"
	root.add_child(generator)
	var mazes: Array[PackedScene] = [scenes["MazeRoomA"], scenes["MazeRoomB"]]
	var platforms: Array[PackedScene] = [scenes["PlatformRoom"]]
	var arenas: Array[PackedScene] = [scenes["ArenaRoom"]]
	var treasure: Array[PackedScene] = [scenes["TreasureRoom"]]
	var exits: Array[PackedScene] = [scenes["ExitRoom"], scenes["ExitRoomArchon"], scenes["ExitRoomSiege"]]
	set_props(generator, {"start_room_scene": scenes["StartRoom"], "maze_room_scenes": mazes, "platform_room_scenes": platforms,
		"arena_room_scenes": arenas, "treasure_room_scenes": treasure, "exit_room_scene": scenes["ExitRoom"],
		"exit_room_scenes": exits, "door_scene": scenes["Door"], "player_scene": scenes["PlayerVehicle"],
		"cell_size": ROOM_HALF * 2.0, "main_path_length": 7, "branch_count": 2, "branch_length": 1, "min_arena_rooms": 1,
		"treasure_chance": 0.2})
	for heading in ["North", "South", "East", "West"]:
		var pool: Array[PackedScene] = [scenes["GauntletLava" + heading], scenes["GauntletSpike" + heading]]
		generator.set("gauntlet_%s_scenes" % heading.to_lower(), pool)
	_camera(root)
	instance_control("HUD", root)
	instance_control("PauseMenu", root)
	save_scene(root, "res://scenes/world/Dungeon.tscn", "Dungeon")


func build_garage() -> void:
	print("Garage")
	var root := with_script(node3d("GarageHub"), "garage/GarageHub.gd") as Node3D
	environment_node(root, Color(0.06, 0.06, 0.07), Color(0.65, 0.62, 0.58), 0.75, 0.0, 0.6)
	sun(root, Color(1.0, 0.95, 0.9), 0.35)
	var body := static_body("Geometry", root)
	var ctx := {"lp": lp(401), "body": body}
	var m: LowPolyMesh = ctx.lp
	_tile_floor(ctx, Rect2(-18, -14, 36, 28), 0.0, 1.0, C.concrete, 4.0)
	for i in 6:
		var stain := Vector3(m.rng.randf_range(-15, 15), 0.01, m.rng.randf_range(-11, 11))
		m.cylinder(T(stain), 0.5 + m.rng.randf() * 0.5, 0.5 + m.rng.randf() * 0.5, 0.02, 9, C.concrete_dark)
	# Corrugated metal walls (the camera-side south wall is kept low)
	for wall in [[Vector3(0, 2.5, -14.5), Vector3(37, 5, 1)], [Vector3(0, 0.75, 14.5), Vector3(37, 1.5, 1)], [Vector3(-18.5, 2.5, 0), Vector3(1, 5, 28)], [Vector3(18.5, 2.5, 0), Vector3(1, 5, 28)]]:
		var c: Vector3 = wall[0]
		var s: Vector3 = wall[1]
		m.box(T(c), s, C.concrete_dark, "metal")
		var along_x := s.x > s.z
		var length := s.x if along_x else s.z
		var count := int(length / 1.5)
		for i in count:
			var offset := -length * 0.5 + (i + 0.5) * length / count
			var inward := -signf(c.z) if along_x else -signf(c.x)
			var p := Vector3(offset, c.y, c.z + inward * 0.55) if along_x else Vector3(c.x + inward * 0.55, c.y, offset)
			m.box(T(p), Vector3(0.25, s.y - 0.4, 0.1) if along_x else Vector3(0.1, s.y - 0.4, 0.25), C.metal, "metal")
		m.box(T(Vector3(c.x, 0.4, c.z) + (Vector3(0, 0, -signf(c.z) * 0.52) if along_x else Vector3(-signf(c.x) * 0.52, 0, 0))), Vector3(s.x, 0.8, 0.06) if along_x else Vector3(0.06, 0.8, s.z), C.yellow)
		collision(body, box_shape(s + Vector3(0, WALL_COLLIDER_EXTRA, 0)), c + Vector3(0, WALL_COLLIDER_EXTRA * 0.5, 0))
	# Workbench + pegboard
	m.box(T(Vector3(-6, 1.0, -12.9)), Vector3(5, 0.15, 1.5), C.wood)
	for x in [-8.3, -3.7]:
		m.box(T(Vector3(x, 0.5, -12.9)), Vector3(0.15, 1.0, 1.3), C.metal_dark, "metal")
	m.box(T(Vector3(-6, 2.4, -13.95)), Vector3(5, 2, 0.1), C.wood_dark)
	for i in 6:
		m.box(T(Vector3(-8 + i * 0.8, 2.4 + (i % 2) * 0.3, -13.85)), Vector3(0.12, 0.7, 0.06), C.chrome, "metal")
	m.box(T(Vector3(-4.5, 1.25, -12.8)), Vector3(0.9, 0.35, 0.5), C.red, "metal")
	collision(body, box_shape(Vector3(5, 1.1, 1.5)), Vector3(-6, 0.55, -12.9))
	# Car lift
	for x in [3.2, 6.8]:
		m.box(T(Vector3(x, 1.6, -11)), Vector3(0.4, 3.2, 0.4), C.yellow, "metal")
		m.box(T(Vector3(x, 0.05, -11)), Vector3(1.0, 0.1, 1.0), C.metal_dark, "metal")
		collision(body, box_shape(Vector3(0.5, 3.2, 0.5)), Vector3(x, 1.6, -11))
	m.box(T(Vector3(5, 1.2, -11)), Vector3(3.2, 0.12, 0.25), C.metal, "metal")
	# Tires and barrels
	for stack in [Vector3(13, 0, -12), Vector3(14.4, 0, -12.3), Vector3(-15.5, 0, 12)]:
		for i in 4:
			m.cylinder(T(stack + Vector3(0, 0.2 + i * 0.36, 0)), 0.55, 0.55, 0.34, 10, C.tire)
		collision(body, box_shape(Vector3(1.1, 1.5, 1.1)), stack + Vector3(0, 0.75, 0))
	for barrel in [[Vector3(-16, 0, -12), C.red], [Vector3(-14.9, 0, -12.4), C.blue], [Vector3(16, 0, 12), C.red], [Vector3(14.9, 0, 12.3), C.green]]:
		var bp: Vector3 = barrel[0]
		m.cylinder(T(bp + Vector3(0, 0.65, 0)), 0.48, 0.48, 1.3, 9, barrel[1], "metal")
		for y in [0.3, 1.0]:
			m.cylinder(T(bp + Vector3(0, y, 0)), 0.5, 0.5, 0.06, 9, C.metal_dark, "metal")
		collision(body, box_shape(Vector3(1.0, 1.3, 1.0)), bp + Vector3(0, 0.65, 0))
	# Shop bay
	for line in [[Vector3(11, 0.01, -4.5), Vector3(8.2, 0.03, 0.2)], [Vector3(11, 0.01, 4.5), Vector3(8.2, 0.03, 0.2)], [Vector3(7, 0.01, 0), Vector3(0.2, 0.03, 9)]]:
		m.box(T(line[0]), line[1], C.yellow)
	m.box(T(Vector3(16.6, 0.55, 0)), Vector3(2.2, 1.1, 7), C.metal_dark, "metal")
	m.box(T(Vector3(16.6, 1.12, 0)), Vector3(2.3, 0.06, 7.1), C.orange)
	for i in 5:
		m.box(T(Vector3(16.4, 1.35, -2.6 + i * 1.3)), Vector3(0.6, 0.4, 0.6), [C.red, C.blue, C.green, C.yellow, C.chrome][i], "metal")
	collision(body, box_shape(Vector3(2.2, 1.1, 7)), Vector3(16.6, 0.55, 0))
	label3d(root, "SHOP", Vector3(11, 0.04, 0), Vector3(-90, 0, 0), 260, Color(1.0, 0.8, 0.2, 0.85))
	label3d(root, "UPGRADES", Vector3(17.25, 3.4, 0), Vector3(0, -90, 0), 140, Color(1.0, 0.6, 0.2))
	# Start-run teleporter
	for i in 12:
		var angle := TAU * i / 12.0
		m.box(T(Vector3(-12 + cos(angle) * 3.0, 0.01, sin(angle) * 3.0), Vector3(0, -rad_to_deg(angle), 0)), Vector3(0.25, 0.03, 0.9), C.yellow if i % 2 == 0 else C.black)
	instance("Teleporter", root, Vector3(-12, 0, 0), Vector3.ZERO, {"destination": 1, "activate_message": ""}, "StartRunTeleporter")
	var start_label := label3d(root, "START RUN", Vector3(-12, 3.6, 0), Vector3.ZERO, 120, Color(0.4, 0.9, 1.0))
	start_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	mesh_node("GeometryMesh", m.commit(), root)

	for p in [Vector3(-8, 4.6, -6), Vector3(8, 4.6, -6), Vector3(-8, 4.6, 6), Vector3(8, 4.6, 6)]:
		omni(root, p, Color(1.0, 0.92, 0.8), 1.8, 16.0, "Lamp")
	omni(root, Vector3(11, 3.0, 0), Color(1.0, 0.7, 0.3), 2.0, 9.0, "ShopLight")
	var spawn := marker("PlayerSpawn", root, Vector3(0, 0.3, 5))
	var zone := make_area("ShopZone", root, L_TRIGGER, L_PLAYER, Vector3(11, 1, 0))
	collision(zone, box_shape(Vector3(8, 2, 9)))
	_camera(root)
	instance_control("HUD", root)
	var ui := CanvasLayer.new()
	attach(root, ui, "UI")
	var prompt := PanelContainer.new()
	prompt.theme = theme
	place(prompt, Vector4(0.5, 1, 0.5, 1), Vector4(-330, -150, 330, -96))
	attach(ui, prompt, "ShopPrompt")
	var prompt_label := label(prompt, "Park in the bay or press F to open the shop  (TAB anywhere)", 20, "Text")
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var shop := instance_control("ShopUI", ui)
	var summary := instance_control("RunSummary", ui)
	instance_control("PauseMenu", root)
	set_props(root, {"shop_ui": shop, "shop_zone": zone, "prompt_label": prompt, "player_spawn": spawn,
		"player_scene": scenes["PlayerVehicle"], "purchase_effect": scenes["Sparkle"], "run_summary": summary})
	save_scene(root, "res://scenes/garage/GarageHub.tscn", "GarageHub")


func build_tutorial() -> void:
	print("Tutorial")
	var root := with_script(node3d("TutorialLevel"), "world/TutorialLevel.gd") as Node3D
	environment_node(root, Color(0.04, 0.032, 0.03), Color(0.6, 0.5, 0.42), 0.6, 0.006, 0.8)
	sun(root, Color(1.0, 0.85, 0.7), 0.55)
	var body := static_body("Geometry", root)
	var ctx := {"lp": lp(501), "body": body}
	var m: LowPolyMesh = ctx.lp
	# Course runs from z = 0 toward -Z, `w` metres either side of x = 0. Lava pit between z -81 and -95.
	var w := TUTORIAL_HALF_WIDTH
	_tile_floor(ctx, Rect2(-w, -81, w * 2.0, 82), 0.0, 3.0, C.floor, 5.0)
	_tile_floor(ctx, Rect2(-w, -201, w * 2.0, 106), 0.0, 3.0, C.floor, 5.0)
	var pit_floor := static_body("PitFloor", root)
	pit_floor.add_to_group("unsafe_ground", true)
	collision(pit_floor, box_shape(Vector3(w * 2.0, 0.5, 14)), Vector3(0, -3.25, -88))
	m.box(T(Vector3(0, -3.25, -88)), Vector3(w * 2.0, 0.5, 14), C.black)
	for x in [-w - 0.5, w + 0.5]:
		_wall(ctx, Vector3(x, 1.5, -100), Vector3(1, 3, 203))
	_wall(ctx, Vector3(0, 1.5, 1.5), Vector3(w * 2.0 + 2.0, 3, 1))
	_wall(ctx, Vector3(0, 1.5, -202), Vector3(w * 2.0 + 2.0, 3, 1))
	# S-curve stubs reach halfway across the track.
	_wall(ctx, Vector3(-w * 0.5, 1.5, -18), Vector3(w, 3, 1.5))
	_wall(ctx, Vector3(w * 0.5, 1.5, -34), Vector3(w, 3, 1.5))
	_wall(ctx, Vector3(-w * 0.5, 1.5, -50), Vector3(w, 3, 1.5))
	for gate_z in [-62.0, -143.0, -180.0]:
		for side in [-1.0, 1.0]:
			_wall(ctx, Vector3(side * (4.0 + (w - 3.5) * 0.5), 1.5, gate_z), Vector3(w - 3.5, 3, 1))
	make_lava_pit(root, "LavaPit", Vector2(w * 2.0, 14), Vector3(0, -1.6, -88))
	for x in [-2.0, 2.0]:
		instance("BoostPad", root, Vector3(x, 0, -71), Vector3.ZERO, {"boost_speed": 30.0})
	instance("Ramp", root, Vector3(0, 0, -78.75))
	mesh_node("GeometryMesh", m.commit(), root)

	var zone_texts := [["A  -  DRIFT", -14.0], ["B  -  JUMP", -67.0], ["C  -  SMASH", -112.0], ["D  -  SHOOT", -148.0], ["E  -  TELEPORT", -184.0]]
	for entry in zone_texts:
		label3d(root, entry[0], Vector3(0, 0.05, entry[1]), Vector3(-90, 0, 0), 180, Color(1.0, 0.75, 0.3, 0.8))
	var triggers := []
	for z in [-10.0, -66.0, -112.0, -147.0, -184.0]:
		var trigger := make_area("Trigger%d" % (triggers.size() + 1), root, L_TRIGGER, L_PLAYER, Vector3(0, 2, z))
		collision(trigger, box_shape(Vector3(w * 2.0, 4, 4)))
		triggers.append(trigger)

	var gates := []
	for gate_z in [-62.0, -143.0, -180.0]:
		gates.append(instance("Door", root, Vector3(0, 0, gate_z), Vector3.ZERO, {"start_locked": true}, "Gate"))
	var crates := node3d("Crates", root)
	var spread := w / 7.0
	for p in [Vector3(-4, 0.7, -120), Vector3(3, 0.7, -124), Vector3(-2, 0.7, -129), Vector3(4, 0.7, -133), Vector3(-4.5, 0.7, -136), Vector3(1, 0.7, -139)]:
		_crate(crates, Vector3(p.x * spread, p.y, p.z))
	var dummies := node3d("Dummies", root)
	for p in [Vector3(-4, 0, -152), Vector3(4, 0, -158), Vector3(-3, 0, -165), Vector3(4, 0, -171)]:
		instance("TrainingDummy", dummies, Vector3(p.x * spread, p.y, p.z))
	var teleporter := instance("Teleporter", root, Vector3(0, 0, -193), Vector3.ZERO, {"destination": 3, "activate_message": ""})
	for i in 9:
		var z := -8.0 - i * 23.0
		if z < -80.0 and z > -96.0:
			continue
		var left := i % 2 == 0
		instance("Torch", root, Vector3(-(w - 0.05) if left else w - 0.05, 2.2, z), Vector3(0, 90.0 if left else -90.0, 0))
	var spawn := marker("PlayerSpawn", root, Vector3(0, 0.3, -5))
	_camera(root)
	instance_control("HUD", root)
	instance_control("PauseMenu", root)
	set_props(root, {"player_spawn": spawn, "player_scene": scenes["PlayerVehicle"], "zone_a_trigger": triggers[0],
		"zone_b_trigger": triggers[1], "zone_c_trigger": triggers[2], "zone_d_trigger": triggers[3], "zone_e_trigger": triggers[4],
		"drift_gate": gates[0], "crate_gate": gates[1], "target_gate": gates[2], "crates_root": crates, "dummies_root": dummies,
		"teleporter": teleporter})
	save_scene(root, "res://scenes/world/TutorialLevel.tscn", "TutorialLevel")


# ==========================================================================
# Verification
# ==========================================================================

func verify() -> void:
	print("Verify")
	var player: Node = (scenes["PlayerVehicle"] as PackedScene).instantiate()
	_check(player.get("visual_root") != null, "player visual_root")
	_check((player.get("drift_particles") as Array).size() == 2, "player drift particles")
	_check((player.get("front_wheels") as Array).size() == 2, "player front wheels")
	var turret := player.get_node("VisualRoot/RoofTurret")
	_check(turret.get("weapon") != null and turret.get("detection_area") != null, "turret weapon/detection")
	player.free()

	var hud: Node = (scenes["HUD"] as PackedScene).instantiate()
	_check(hud.get("health_bar") != null and hud.get("message_label") != null, "HUD bindings")
	hud.free()
	var shop: Node = (scenes["ShopUI"] as PackedScene).instantiate()
	_check(shop.get("tab_container") != null, "Shop bindings")
	shop.free()
	for key in ["StartRoom", "MazeRoomA", "MazeRoomB", "PlatformRoom", "ArenaRoom", "TreasureRoom", "ExitRoom",
			"ExitRoomArchon", "ExitRoomSiege", "GauntletLavaNorth", "GauntletSpikeWest"]:
		var room: Node = (scenes[key] as PackedScene).instantiate()
		_check(room.get_node("Sockets").get_child_count() == 4, key + " sockets")
		var region := room.get_node("NavigationRegion3D") as NavigationRegion3D
		_check(region.navigation_mesh.get_polygon_count() > 0, key + " navmesh")
		room.free()
	var tutorial: Node = (scenes["TutorialLevel"] as PackedScene).instantiate()
	_check(tutorial.get("drift_gate") != null and tutorial.get("teleporter") != null, "tutorial bindings")
	tutorial.free()
	var garage: Node = (scenes["GarageHub"] as PackedScene).instantiate()
	_check(garage.get("shop_ui") != null and garage.get("shop_zone") != null, "garage bindings")
	garage.free()


func _check(condition: bool, what: String) -> void:
	if condition:
		print("  ok    ", what)
	else:
		fail("verify failed: " + what)
