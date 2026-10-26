extends SceneTree
## Regenerates every model, scene and data file in this project.
## Run from the project folder:
##   Godot_v4.x_console.exe --headless --path . -s res://tools/build.gd
## WARNING: this overwrites scenes/, models/, materials/, audio/, data/ and ui/.

func _init() -> void:
	# Wait one frame so the PlayerData / GameManager autoloads exist before game scripts compile.
	process_frame.connect(_run, CONNECT_ONE_SHOT)


func _run() -> void:
	var builder: Node = load("res://tools/builder_levels.gd").new()
	root.add_child(builder)
	var ok: bool = builder.build_all()
	quit(0 if ok else 1)
