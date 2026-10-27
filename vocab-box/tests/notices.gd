extends SceneTree
# Writes engine and third-party notices next to an exported bundle. The path after
# "--" selects the target; the Linux bundle location stays the default.
func _initialize() -> void:
	var path := "res://../builds/linux/GODOT-LICENSES.txt"
	var arguments := OS.get_cmdline_user_args()
	if arguments.size() > 0:
		path = arguments[0]
	var f=FileAccess.open(path,FileAccess.WRITE)
	f.store_string(Engine.get_license_text()+"\n\n"+JSON.stringify(Engine.get_copyright_info(),"  ")+"\n\n"+JSON.stringify(Engine.get_license_info(),"  "))
	f.close()
	quit()
