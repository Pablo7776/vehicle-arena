extends BTCondition

@export var radio: float = 30.0
@export var memoria: float = 0.0   # segundos que sigue "viendo" al kart tras perderlo

var _hasta: float = 0.0

func _tick(_delta: float) -> Status:
	var ahora: float = Time.get_ticks_msec() / 1000.0
	var vs := agent.get_tree().get_nodes_in_group("vehiculos")
	#print("vehiculos en grupo: ", vs.size())
	for v: Node3D in vs:
		var d: float = agent.global_position.distance_to(v.global_position)
		#print("dist: ", d, " radio: ", radio)
		if d < radio:
			_hasta = ahora + memoria
			return SUCCESS
	if ahora < _hasta:
		#print("memoria activa, quedan: ", _hasta - ahora)
		return SUCCESS
	return FAILURE
