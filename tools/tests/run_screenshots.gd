extends SceneTree
## Renders review screenshots (needs a window, not --headless):
##   Godot.exe --path . -s res://tools/tests/run_screenshots.gd -- <output_dir>

func _init() -> void:
	process_frame.connect(_boot, CONNECT_ONE_SHOT)


func _boot() -> void:
	var shots: Node = load("res://tools/tests/screenshot_body.gd").new()
	root.add_child(shots)
