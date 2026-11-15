extends BTAction

var _t := 0.0

func _enter() -> void:
	_t = 0.0
	agent.set_estado("Pastando...")

func _tick(delta: float) -> Status:
	_t += delta
	if _t < 3.0:
		return RUNNING
	agent.hambre = 0.0
	return SUCCESS
