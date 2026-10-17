extends RefCounted
static func material(color: Color) -> StandardMaterial3D:
	var m = StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.85
	return m
static func box(parent: Node3D, pos: Vector3, size: Vector3, color: Color, solid: bool = true) -> MeshInstance3D:
	var mesh = MeshInstance3D.new()
	var shape = BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = material(color)
	parent.add_child(mesh)
	mesh.position = pos
	if solid:
		var body = StaticBody3D.new()
		var collision = CollisionShape3D.new()
		var bounds = BoxShape3D.new()
		bounds.size = size
		collision.shape = bounds
		body.add_child(collision)
		mesh.add_child(body)
	return mesh
static func ball(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> MeshInstance3D:
	var m = MeshInstance3D.new()
	m.mesh = SphereMesh.new()
	m.mesh.radial_segments = 16
	m.mesh.rings = 8
	m.material_override = material(color)
	parent.add_child(m)
	m.position = pos
	m.scale = size
	return m
static func sign_text(parent: Node3D, text: String, pos: Vector3, size: int = 48) -> Label3D:
	var label = Label3D.new()
	label.text = text
	label.font_size = size
	label.pixel_size = 0.009
	label.no_depth_test = false
	label.shaded = false
	label.outline_size = 5
	label.modulate = Color("fff6d9")
	parent.add_child(label)
	label.position = pos
	return label
static func person(parent: Node3D, color: Color) -> Node3D:
	var model = Node3D.new()
	parent.add_child(model)
	ball(model, Vector3(0,0.025,0), Vector3(0.9,0.025,0.65), Color("8c9d8a"))
	ball(model, Vector3(0,1.45,0), Vector3(0.48,0.48,0.48), Color("c98d67"))
	ball(model, Vector3(0,1.63,0.02), Vector3(0.5,0.26,0.5), Color("3e3944"))
	box(model, Vector3(0,0.93,0), Vector3(0.52,0.65,0.32), color, false)
	for x in [-0.17,0.17]:
		var leg = box(model, Vector3(x,0.38,0), Vector3(0.21,0.55,0.23), Color("33485a"), false)
		leg.name = "LeftLeg" if x < 0 else "RightLeg"
		box(model, Vector3(x,0.1,0.08), Vector3(0.24,0.18,0.38), Color("fff6d9"), false)
		ball(model, Vector3(x * 0.7,1.47,0.215), Vector3(0.055,0.065,0.04), Color("283b45"))
	for x in [-0.36,0.36]:
		var arm = box(model, Vector3(x,0.95,0), Vector3(0.16,0.5,0.2), color, false)
		arm.name = "LeftArm" if x < 0 else "RightArm"
	return model
# Batch static repeated shapes while retaining each independent collision body.
static func batch_static(root: Node3D) -> void:
	var groups: Dictionary = {}
	for node in root.find_children("*", "MeshInstance3D", true, false):
		if not node.visible: continue
		if not (node.mesh is BoxMesh or node.mesh is SphereMesh): continue
		var key = str(node.mesh.get_class()) + str(node.material_override.albedo_color)
		if not groups.has(key): groups[key] = []
		groups[key].append(node)
	for key in groups:
		var nodes = groups[key]
		var multi = MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = BoxMesh.new() if nodes[0].mesh is BoxMesh else SphereMesh.new()
		if multi.mesh is BoxMesh: multi.mesh.size = Vector3.ONE
		else:
			multi.mesh.radial_segments = 16
			multi.mesh.rings = 8
		multi.instance_count = nodes.size()
		var instance = MultiMeshInstance3D.new()
		instance.multimesh = multi
		instance.material_override = nodes[0].material_override
		root.add_child(instance)
		for i in nodes.size():
			var node = nodes[i]
			var transform: Transform3D = root.global_transform.affine_inverse() * node.global_transform
			if node.mesh is BoxMesh: transform.basis = transform.basis.scaled_local(node.mesh.size)
			multi.set_instance_transform(i, transform)
			for child in node.get_children():
				if child is StaticBody3D: child.reparent(root, true)
			node.queue_free()
