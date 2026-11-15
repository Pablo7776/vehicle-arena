extends BTAction

@export var pos_var: StringName = &"pos"

func _enter() -> void:
	var p: Vector3 = blackboard.get_var(pos_var, Vector3.ZERO)
	agent.go_to(p)

func _tick(_delta: float) -> Status:
	if agent.has_arrived():
		agent.stop()
		return SUCCESS
	return RUNNING
