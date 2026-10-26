extends SceneTree
## Headless playtest: Godot_console.exe --headless --path . -s res://tools/tests/run_tests.gd

func _init() -> void:
	process_frame.connect(_boot, CONNECT_ONE_SHOT)


func _boot() -> void:
	var tests: Node = load("res://tools/tests/test_body.gd").new()
	root.add_child(tests)
