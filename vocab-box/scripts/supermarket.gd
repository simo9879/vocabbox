extends Node3D
const Art = preload("res://scripts/art.gd")
func target(id: String, title: String, pos: Vector3, person: bool = false, color: Color = Color.WHITE) -> void:
	var node = preload("res://scenes/interactable.tscn").instantiate()
	node.encounter_id = id
	node.title = title
	add_child(node)
	node.position = pos
	if person:
		Art.person(node,color)
		Art.box(self,pos+Vector3(0,0.8,0),Vector3(0.6,1.6,0.5),Color(0,0,0,0)).visible = false
func _ready() -> void:
	Art.box(self,Vector3(0,-0.2,0),Vector3(20,0.4,20),Color("ede1c7"))
	for x in range(-9,10,2):
		for z in range(-9,10,2): Art.box(self,Vector3(x,0.005,z),Vector3(1.95,0.01,1.95),Color("e3d7bd"),false)
	for x in [-10,10]: Art.box(self,Vector3(x,2,0),Vector3(0.4,4,20),Color("8cbcb1"))
	Art.box(self,Vector3(0,2,-10),Vector3(20,4,0.4),Color("8cbcb1"))
	Art.box(self,Vector3(0,2,10),Vector3(20,4,0.4),Color("8cbcb1"))
	Art.sign_text(self,"SUNNY MARKET  /  FRESH & FRIENDLY",Vector3(0,3.3,-9.7),54)
	for x in [-2,2]:
		Art.box(self,Vector3(x,0.75,0),Vector3(1.3,1.5,6),Color("b78561"))
		for z in [-2,-1,0,1,2]:
			for h in [0.8,1.6]:
				Art.box(self,Vector3(x,h,z),Vector3(1.5,0.12,0.8),Color("f9eac7"))
				for dx in [-0.4,0,0.4]: Art.box(self,Vector3(x+dx,h+0.2,z),Vector3(0.25,0.35,0.4),Color("e9af63") if z%2==0 else Color("7bafa2"),false)
	for x in [-6,6]:
		Art.box(self,Vector3(x,0.5,-6),Vector3(3,1,2),Color("af825c"))
		for i in range(12):
			var pos = Vector3(x-1+(i%4)*0.6,1.15,-6.5+(i/4)*0.45)
			var fruit = Art.ball(self,pos,Vector3(0.45,0.25,0.18) if x<0 else Vector3(0.3,0.3,0.3),Color("ffcf4d") if x<0 else Color("d86b57"))
			fruit.rotation.z = 0.3
		Art.sign_text(self,"PRODUCE · BANANAS" if x<0 else "FRESH APPLES",Vector3(x,2.5,-7),40)
	target("worker","Alex · Ask for help",Vector3(-6,0,3),true,Color("4aa98e"))
	target("bananas","Take one bunch",Vector3(-6,0,-4.3))
	target("customer","Sam · Say hello",Vector3(6,0,-3.7),true,Color("be8bc2"))
	Art.box(self,Vector3(6,0.55,4),Vector3(3.5,1.1,1),Color("4d9388"))
	Art.box(self,Vector3(7,1.3,4),Vector3(0.6,0.4,0.4),Color("354b57"))
	target("cashier","Jo · Check out",Vector3(6,0,2.8),true,Color("e5b453"))
	Art.sign_text(self,"CHECKOUT",Vector3(6,3,4),44)
	target("exit","Return to city",Vector3(0,0,8))
	var entry = Marker3D.new()
	entry.name = "Entry"
	entry.position = Vector3(0,0.2,6)
	add_child(entry)
