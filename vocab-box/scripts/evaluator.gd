extends RefCounted
const LESSON = preload("res://lessons/banana.tres")
func evaluate(encounter_id: String, response_id: String) -> Dictionary:
	if not LESSON.encounters.has(encounter_id): return {}
	for choice in LESSON.encounters[encounter_id].choices:
		if choice[0] == response_id:
			return {"quality": choice[2], "feedback": choice[3], "suggested_wording": LESSON.encounters[encounter_id].choices[2][1], "allowed": choice[2] >= 1}
	return {}
