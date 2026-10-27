extends Control

const EMPTY_BOX = preload("res://assets/ui/notebook_box_empty.svg")
const CHECKED_BOX = preload("res://assets/ui/notebook_box_checked.svg")

@onready var objective_label: Label = %Objective
@onready var task_labels: Array[Label] = [%Task1, %Task2, %Task3, %Task4]
@onready var task_boxes: Array[TextureRect] = [%Box1, %Box2, %Box3, %Box4]

# The lesson supplies wording; the mission stage supplies completion state.
func set_progress(stage: int, objectives: Dictionary) -> void:
	objective_label.text = objectives[stage]
	for index in range(4):
		task_labels[index].text = objectives[index + 1]
		task_boxes[index].texture = CHECKED_BOX if stage > index + 1 else EMPTY_BOX
