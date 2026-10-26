extends Control
## Main menu: Play (Garage), Tutorial, Options, Reset Save (click twice), Quit.

@export var play_button: Button
@export var tutorial_button: Button
@export var options_button: Button
@export var reset_button: Button
@export var quit_button: Button
## Hidden while the options menu is open.
@export var main_panel: Control
@export var options_menu: OptionsMenu
@export var scrap_label: Label

var _reset_armed: bool = false


func _ready() -> void:
	get_tree().paused = false
	_connect(play_button, _on_play_pressed)
	_connect(tutorial_button, GameManager.start_tutorial)
	_connect(options_button, _on_options_pressed)
	_connect(reset_button, _on_reset_pressed)
	_connect(quit_button, GameManager.quit_game)
	if quit_button != null and OS.has_feature("web"):
		quit_button.hide()
	if options_menu != null:
		options_menu.hide()
		options_menu.closed.connect(_on_options_closed)
	_refresh()
	if play_button != null:
		play_button.grab_focus()


func _refresh() -> void:
	var has_progress: bool = PlayerData.scrap_currency > 0 or not PlayerData.purchased_tiers.is_empty()
	if play_button != null:
		play_button.text = "Continue" if has_progress else "Play"
	if tutorial_button != null and not PlayerData.tutorial_completed:
		tutorial_button.text = "Tutorial (recommended)"
	if scrap_label != null:
		scrap_label.text = "Scrap: %d" % PlayerData.scrap_currency
	if reset_button != null:
		reset_button.text = "Reset Save"


func _on_play_pressed() -> void:
	GameManager.go_to_garage()


func _on_options_pressed() -> void:
	if options_menu == null:
		return
	if main_panel != null:
		main_panel.hide()
	options_menu.open()


func _on_options_closed() -> void:
	if main_panel != null:
		main_panel.show()
	if options_button != null:
		options_button.grab_focus()


func _on_reset_pressed() -> void:
	if not _reset_armed:
		_reset_armed = true
		reset_button.text = "Click again to erase ALL progress"
		return
	_reset_armed = false
	PlayerData.reset_save()
	_refresh()


func _connect(button: BaseButton, callable: Callable) -> void:
	if button != null:
		button.pressed.connect(callable)
