## godot --path . --headless --script .github/check_scripts.gd
## Loads scripts inside the project because `--check-only` cannot resolve autoloads.
extends SceneTree

const ROOTS := ["res://scripts", "res://audio"]


func _initialize() -> void:
	var failed: Array[String] = []
	var checked := 0
	for root in ROOTS:
		for path in _find_scripts(root):
			checked += 1
			var script := load(path) as Script
			if script == null or not script.can_instantiate():
				failed.append(path)
	for path in failed:
		printerr("PARSE FAIL: ", path)
	print("check_scripts: %d scripts checked, %d failed" % [checked, failed.size()])
	quit(1 if failed.size() > 0 else 0)


func _find_scripts(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		printerr("check_scripts: cannot open ", dir_path)
		return found
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		var path := dir_path.path_join(name)
		if dir.current_is_dir():
			found.append_array(_find_scripts(path))
		elif name.ends_with(".gd"):
			found.append(path)
		name = dir.get_next()
	found.sort()
	return found
