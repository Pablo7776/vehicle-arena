extends BTAction

## Elige un punto al azar para deambular, evitando los bordes del mapa.

const Bordes := preload("res://ai/tasks/bordes.gd")

@export var rango: float = 300.0
@export var guardar_en: StringName = &"pos"
## Metros libres que quiere tener alrededor del punto elegido
@export var margen_borde: float = 20.0

func _tick(_delta: float) -> Status:
	var map: RID = agent.get_world_3d().navigation_map
	# En los primeros frames el mapa de navegación todavía no está listo:
	# esperamos en vez de consultarlo (si no, Godot tira un error).
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return RUNNING
	agent.set_estado("Deambulando")
	# Probamos varios puntos al azar y nos quedamos con el que tenga más
	# espacio libre alrededor (si encontramos uno en campo abierto, listo).
	var mundo: World3D = agent.get_world_3d()
	var mejor_punto := Vector3.ZERO
	var mejor_libre := -1.0
	for i in 10:
		var p: Vector3 = agent.global_position + Vector3(
			randf_range(-rango, rango), 0.0, randf_range(-rango, rango))
		# Puntos del otro lado de una pared (fuera de la arena) no sirven
		if Bordes.hay_pared(mundo, agent.global_position, p):
			continue
		var libre := Bordes.espacio_libre(mundo, p, margen_borde)
		if libre > mejor_libre:
			mejor_libre = libre
			mejor_punto = p
		if libre >= 1.0:
			break
	if mejor_punto == Vector3.ZERO:
		return FAILURE
	# Una sola consulta al mapa de navegación, para el punto elegido
	var c := NavigationServer3D.map_get_closest_point(map, mejor_punto)
	if c == Vector3.ZERO:
		return FAILURE
	blackboard.set_var(guardar_en, c)
	return SUCCESS
