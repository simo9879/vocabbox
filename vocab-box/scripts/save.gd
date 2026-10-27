extends RefCounted
var path: String = "user://vocab-box.json"
var best_stars: int = 0
var volumes: Dictionary = {"Voice": 0.85, "Music": 0.25, "Effects": 0.5}

func read_save() -> void:
	if not FileAccess.file_exists(path): return
	var parser = JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return
	var data = parser.data
	if not data is Dictionary: return
	if data.get("best_stars") is float or data.get("best_stars") is int:
		best_stars = clampi(int(data.best_stars), 0, 3)
	if data.get("volumes") is Dictionary:
		for key in volumes:
			var value = data.volumes.get(key)
			if value is float or value is int: volumes[key] = clampf(float(value), 0, 1)
			
func write_save(stars: int = 0) -> bool:
	best_stars = maxi(best_stars, clampi(stars, 0, 3))
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify({"best_stars": best_stars, "volumes": volumes}))
	file.close()
	return DirAccess.rename_absolute(path + ".tmp", path) == OK
