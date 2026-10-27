extends RefCounted

const DOTENV_NAME := ".env"

static func get_value(name: String) -> String:
	var process_value := OS.get_environment(name)
	if not process_value.is_empty():
		return process_value
	var project_directory := ProjectSettings.globalize_path("res://")
	return read_file(project_directory.path_join("..").path_join(DOTENV_NAME).simplify_path(), name)

static func read_file(path: String, name: String) -> String:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return ""
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue
		if line.begins_with("export "):
			line = line.substr(7).strip_edges()
		var separator := line.find("=")
		if separator < 0 or line.substr(0, separator).strip_edges() != name:
			continue
		var value := line.substr(separator + 1).strip_edges()
		if value.length() >= 2:
			var quote := value.substr(0, 1)
			if quote in ["\"", "'"] and value.ends_with(quote):
				return value.substr(1, value.length() - 2)
		return value
	return ""
