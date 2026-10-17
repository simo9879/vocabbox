extends SceneTree
func _initialize() -> void:
	var f=FileAccess.open("res://../builds/linux/GODOT-LICENSES.txt",FileAccess.WRITE)
	f.store_string(Engine.get_license_text()+"\n\n"+JSON.stringify(Engine.get_copyright_info(),"  ")+"\n\n"+JSON.stringify(Engine.get_license_info(),"  "))
	f.close()
	quit()
