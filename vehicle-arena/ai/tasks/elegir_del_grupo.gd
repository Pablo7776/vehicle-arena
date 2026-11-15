extends BTAction

@export var grupo: StringName = &"pasto"
@export var guardar_en: StringName = &"pos"

func _tick(_delta: float) -> Status:
	var mejor: float = INF
	var res: Vector3 = Vector3.ZERO
	var hallado: bool = false
	for n: Node3D in agent.get_tree().get_nodes_in_group(grupo):
		var d: float = agent.global_position.distance_to(n.global_position)
		if d < mejor:
			mejor = d
			res = n.global_position
			hallado = true
	if not hallado:
		return FAILURE
	blackboard.set_var(guardar_en, res)
	agent.set_estado("Yendo a buscar comida")
	return SUCCESS
