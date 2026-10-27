extends SceneTree
var count: int = 0
var failures: int = 0
func check(condition: bool, message: String) -> void:
	count += 1
	if not condition:
		push_error("FAIL: "+message)
		failures += 1
func _initialize() -> void:
	var lesson=load("res://lessons/banana.tres")
	check(lesson.objectives.size()==6 and lesson.hints.size()==6,"all stage resources survive export")
	check(lesson.voice_paths.size()==37,"voice reference count")
	var Model=load("res://scripts/mission.gd")
	var evaluator=load("res://scripts/evaluator.gd").new()
	check(evaluator.evaluate("invalid","clear").is_empty(),"unknown encounter")
	check(evaluator.evaluate("worker","invalid").is_empty(),"unknown response")
	for id in ["worker","customer","cashier"]:
		for choice in ["unclear","clear","strong"]:
			var value=evaluator.evaluate(id,choice)
			check(value.allowed==(choice!="unclear"),"evaluation allowed")
			check(not value.feedback.is_empty() and not value.suggested_wording.is_empty(),"feedback present")
	# All 27 score combinations, plus failed tries, duplicate and premature actions.
	for w in [0,1,2]:
		for c in [0,1,2]:
			for j in [0,1,2]:
				var m=Model.new()
				check(not m.collect(),"cannot collect outside")
				check(not m.respond("cashier",2),"cannot check out early")
				m.enter()
				m.enter()
				check(m.stage==1,"entry idempotent")
				check(not m.respond("customer",2),"customer order")
				for id in ["worker","customer","cashier"]:
					var quality={"worker":w,"customer":c,"cashier":j}[id]
					if quality==0:
						check(not m.respond(id,0),"failed answer")
						check(not m.respond(id,0),"failed retry")
						check(m.failures[id]==2,"assistance threshold")
						quality=1
					check(m.respond(id,quality),"success")
					if id=="worker":
						check(m.collect(),"one bunch")
						check(not m.collect() and m.bananas==1,"duplicate guarded")
				var strong=[w,c,j].count(2)
				check(m.stars()==(3 if strong==3 else 2 if strong>=2 else 1),"star thresholds")
				check(m.respond("cashier",2),"optional checkout retry before results")
				check(m.stage==5,"retry preserves completion")
				m.finalized=true
				check(not m.respond("cashier",2),"finalized once")
				m.reset()
				check(m.stage==0 and m.bananas==0 and m.stars()==0 and not m.finalized,"clean replay")
	var Save=load("res://scripts/save.gd")
	var saved=Save.new()
	saved.path="user://test-save.json"
	check(saved.write_save(3),"save write")
	check(saved.write_save(1),"save lower score")
	var loaded=Save.new()
	loaded.path=saved.path
	loaded.read_save()
	check(loaded.best_stars==3,"persistent maximum")
	var f=FileAccess.open(saved.path,FileAccess.WRITE)
	f.store_string('{"best_stars": "bad", "volumes": {"Voice": 9, "Music": "bad"}}')
	f.close()
	loaded=Save.new()
	loaded.path=saved.path
	loaded.read_save()
	check(loaded.best_stars==0 and loaded.volumes.Voice==1 and loaded.volumes.Music==0.25,"malformed save fields")
	f=FileAccess.open(saved.path,FileAccess.WRITE)
	f.store_string('broken')
	f.close()
	loaded.read_save()
	check(loaded.best_stars==0,"broken JSON safe")
	DirAccess.remove_absolute(saved.path)
	# Every authored line has a bundled clip with imported audio.
	var lines=JSON.parse_string(FileAccess.get_file_as_string("res://audio/manifest.json"))
	for line in lines:
		check(ResourceLoader.exists("res://audio/"+line.sha256_text()+".wav"),"voice exists: "+line)
	# Shared answer text has a separate Pip recording for hints and results practice.
	for encounter in lesson.encounters.values():
		for choice in encounter.choices:
			if choice[2] >= 1:
				check(ResourceLoader.exists("res://audio/pip/"+choice[1].sha256_text()+".wav"),"Pip phrase exists: "+choice[1])
	print("PASS: " if failures == 0 else "FAIL: ",count," checks; failures=",failures)
	quit(0 if failures == 0 else 1)
