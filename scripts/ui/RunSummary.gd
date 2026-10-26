class_name RunSummary
extends Control
## End-of-run score screen, shown in the garage after a run. Fill it with
## GameManager.consume_run_summary() (GarageHub does this automatically).

signal closed

@export var title_label: Label
@export var subtitle_label: Label
## Two-column GridContainer; rows are rebuilt for every summary.
@export var stats_grid: GridContainer
@export var score_label: Label
@export var best_label: Label
@export var continue_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hide()
	if continue_button != null:
		continue_button.pressed.connect(close)


func show_summary(summary: Dictionary) -> void:
	var success: bool = summary.get("success", false)
	if title_label != null:
		title_label.text = "RUN COMPLETE" if success else "RUN FAILED"
		title_label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.55) if success else Color(1.0, 0.4, 0.3))
	if subtitle_label != null:
		subtitle_label.text = "Depth %d" % int(summary.get("depth", 1))
	if stats_grid != null:
		for child in stats_grid.get_children():
			stats_grid.remove_child(child)
			child.queue_free()
		var seconds := int(summary.get("time", 0.0))
		_add_row("Time", "%d:%02d" % [seconds / 60, seconds % 60])
		_add_row("Scrap collected", str(int(summary.get("scrap", 0))))
		if int(summary.get("scrap_lost", 0)) > 0:
			_add_row("Scrap lost", "-%d" % int(summary.get("scrap_lost", 0)), Color(1.0, 0.45, 0.4))
		_add_row("Enemies destroyed", str(int(summary.get("kills", 0))))
		_add_row("Rooms cleared", str(int(summary.get("rooms", 0))))
		_add_row("Best combo", "x%d" % int(summary.get("best_combo", 0)))
		_add_row("Boss defeated", "YES" if summary.get("boss", false) else "no")
		_add_row("Hull damage taken", str(roundi(float(summary.get("damage", 0.0)))))
	if score_label != null:
		score_label.text = "SCORE  %d" % int(summary.get("score", 0))
	if best_label != null:
		var new_best: bool = summary.get("new_best", false)
		best_label.text = "NEW BEST!" if new_best else "Best: %d" % int(summary.get("best_score", 0))
		best_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3) if new_best else Color(0.8, 0.75, 0.7))
	show()
	if continue_button != null:
		continue_button.grab_focus()


func close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()


func _add_row(label_text: String, value: String, color: Color = Color(1, 1, 1)) -> void:
	var name_label := Label.new()
	name_label.text = label_text
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.modulate = Color(1, 1, 1, 0.8)
	stats_grid.add_child(name_label)
	var value_label := Label.new()
	value_label.text = value
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	value_label.add_theme_color_override("font_color", color)
	stats_grid.add_child(value_label)
