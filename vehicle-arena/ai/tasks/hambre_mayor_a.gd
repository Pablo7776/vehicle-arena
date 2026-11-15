extends BTCondition

@export var umbral: float = 40.0

func _tick(_delta: float) -> Status:
	return SUCCESS if agent.hambre > umbral else FAILURE
