class_name OptionsMenu
extends Control
## Audio / display options, saved to user://settings.cfg.
## GameManager calls OptionsMenu.apply_saved_settings() at startup.
## Volume sliders drive the "Master", "Music" and "SFX" audio buses (missing buses are skipped).

signal closed

const SETTINGS_PATH: String = "user://settings.cfg"

@export var master_slider: Range
@export var music_slider: Range
@export var sfx_slider: Range
@export var fullscreen_toggle: BaseButton
@export var vsync_toggle: BaseButton
@export var back_button: BaseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var config := _load_config()
	_setup_slider(master_slider, config.get_value("audio", "master", 1.0), "Master")
	_setup_slider(music_slider, config.get_value("audio", "music", 0.8), "Music")
	_setup_slider(sfx_slider, config.get_value("audio", "sfx", 1.0), "SFX")
	if fullscreen_toggle != null:
		fullscreen_toggle.toggle_mode = true
		fullscreen_toggle.button_pressed = config.get_value("display", "fullscreen", false)
		fullscreen_toggle.toggled.connect(_apply_fullscreen)
	if vsync_toggle != null:
		vsync_toggle.toggle_mode = true
		vsync_toggle.button_pressed = config.get_value("display", "vsync", true)
		vsync_toggle.toggled.connect(_apply_vsync)
	if back_button != null:
		back_button.pressed.connect(close)


func open() -> void:
	show()
	if master_slider != null:
		master_slider.grab_focus()


func close() -> void:
	_save()
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _setup_slider(slider: Range, value: float, bus_name: String) -> void:
	if slider == null:
		return
	slider.min_value = 0.0
	slider.max_value = 1.0
	slider.step = 0.01
	slider.value = value
	slider.value_changed.connect(func(new_value: float) -> void: _set_bus_volume(bus_name, new_value))


func _save() -> void:
	var config := _load_config()
	if master_slider != null:
		config.set_value("audio", "master", master_slider.value)
	if music_slider != null:
		config.set_value("audio", "music", music_slider.value)
	if sfx_slider != null:
		config.set_value("audio", "sfx", sfx_slider.value)
	if fullscreen_toggle != null:
		config.set_value("display", "fullscreen", fullscreen_toggle.button_pressed)
	if vsync_toggle != null:
		config.set_value("display", "vsync", vsync_toggle.button_pressed)
	config.save(SETTINGS_PATH)


static func apply_saved_settings() -> void:
	var config := _load_config()
	_set_bus_volume("Master", config.get_value("audio", "master", 1.0))
	_set_bus_volume("Music", config.get_value("audio", "music", 0.8))
	_set_bus_volume("SFX", config.get_value("audio", "sfx", 1.0))
	if config.has_section("display"):
		_apply_fullscreen(config.get_value("display", "fullscreen", false))
		_apply_vsync(config.get_value("display", "vsync", true))


static func _load_config() -> ConfigFile:
	var config := ConfigFile.new()
	config.load(SETTINGS_PATH)
	return config


static func _set_bus_volume(bus_name: String, linear: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(index, linear <= 0.001)


static func _apply_fullscreen(enabled: bool) -> void:
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if enabled else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


static func _apply_vsync(enabled: bool) -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if enabled else DisplayServer.VSYNC_DISABLED)
