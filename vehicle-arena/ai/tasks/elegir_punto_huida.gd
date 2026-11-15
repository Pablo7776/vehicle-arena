extends BTAction

@export var distancia: float = 25.0
@export var guardar_en: StringName = &"pos"

func _tick(_delta: float) -> Status:
	var mas_cercano: Node3D = null
	var mejor: float = INF
	for v: Node3D in agent.get_tree().get_nodes_in_group("vehiculos"):
		var d: float = agent.global_position.distance_to(v.global_position)
		if d < mejor:
			mejor = d
			mas_cercano = v
	if mas_cercano == null:
		return FAILURE
	var away: Vector3 = agent.global_position - mas_cercano.global_position
	away.y = 0.0
	away = away.normalized()
	var map: RID = agent.get_world_3d().navigation_map
	for ang in [0, 30, -30, 60, -60, 90, -90]:
		var p: Vector3 = agent.global_position + away.rotated(Vector3.UP, deg_to_rad(ang)) * distancia
		var c: Vector3 = NavigationServer3D.map_get_closest_point(map, p)
		if c != Vector3.ZERO and c.distance_to(p) < distancia * 0.4:
			blackboard.set_var(guardar_en, c)
			agent.set_estado("¡Huyendo!")
			return SUCCESS
	return FAILURE
