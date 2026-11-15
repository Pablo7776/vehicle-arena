extends BTAction

@export var rango: float = 300.0
@export var guardar_en: StringName = &"pos"

func _tick(_delta: float) -> Status:
	var map: RID = agent.get_world_3d().navigation_map
	agent.set_estado("Deambulando")
	for i in 10:
		var p: Vector3 = agent.global_position + Vector3(
			randf_range(-rango, rango), 0.0, randf_range(-rango, rango))
		var c := NavigationServer3D.map_get_closest_point(map, p)
		if c != Vector3.ZERO and c.distance_to(p) <= rango * 0.5:
			blackboard.set_var(guardar_en, c)
			return SUCCESS
	return FAILURE
