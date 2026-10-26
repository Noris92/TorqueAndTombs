extends CanvasLayer
## Pause menu (Esc / P / Start). Add one to the Dungeon, Garage and Tutorial scenes.

@export var panel: Control
@export var resume_button: Button
@export var options_button: Button
## "Abandon Run" during a run (scrap penalty applies), "Leave Tutorial" in the tutorial.
@export var abandon_button: Button
@export var main_menu_button: Button
@export var options_menu: OptionsMenu

var is_open: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50
	if panel != null:
		panel.hide()
	if options_menu != null:
		options_menu.hide()
		options_menu.closed.connect(_on_options_closed)
	if resume_button != null:
		resume_button.pressed.connect(close)
	if options_button != null:
		options_button.pressed.connect(_on_options_pressed)
	if abandon_button != null:
		abandon_button.pressed.connect(_on_abandon_pressed)
	if main_menu_button != null:
		main_menu_button.pressed.connect(_on_main_menu_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("pause"):
		return
	if is_open:
		if options_menu != null and options_menu.visible:
			options_menu.close()
		else:
			close()
		get_viewport().set_input_as_handled()
	elif not get_tree().paused:
		# Something else (e.g. the shop) may already have paused the game; leave it alone.
		open()
		get_viewport().set_input_as_handled()


func open() -> void:
	is_open = true
	get_tree().paused = true
	if panel != null:
		panel.show()
	if abandon_button != null:
		abandon_button.visible = GameManager.run_active or GameManager.in_tutorial
		abandon_button.text = "Leave Tutorial" if GameManager.in_tutorial else "Abandon Run"
	if resume_button != null:
		resume_button.grab_focus()


func close() -> void:
	is_open = false
	if panel != null:
		panel.hide()
	if options_menu != null:
		options_menu.hide()
	get_tree().paused = false


func _on_options_pressed() -> void:
	if options_menu == null:
		return
	if panel != null:
		panel.hide()
	options_menu.open()


func _on_options_closed() -> void:
	if is_open and panel != null:
		panel.show()
		if options_button != null:
			options_button.grab_focus()


func _on_abandon_pressed() -> void:
	close()
	if GameManager.in_tutorial:
		GameManager.go_to_garage()
	else:
		GameManager.end_run(false)


func _on_main_menu_pressed() -> void:
	close()
	GameManager.go_to_main_menu()
