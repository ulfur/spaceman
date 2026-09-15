extends SceneTree
## Editor import does not compile every non-global script. Check the actual sources.
var failures := 0
var checked := 0

func _initialize() -> void:
	for folder in ["res://scripts", "res://tests"]:
		for filename in DirAccess.get_files_at(folder):
			if not filename.ends_with(".gd"): continue
			var script: GDScript = load(folder.path_join(filename))
			checked += 1
			if script == null or not script.can_instantiate():
				failures += 1
				printerr("FAIL: Compile " + filename)
	print("Script compilation: %d checked, %d failures" % [checked, failures])
	quit(1 if failures else 0)
