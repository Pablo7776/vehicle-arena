extends BTAction

## Elige hacia dónde huir del kart más cercano SIN meterse contra los bordes.
## Prueba muchas direcciones (no solo "para atrás") y a cada una le pone un
## puntaje: gana la que deja más espacio libre alrededor y más lejos del kart.
## Así, si atrás hay una pared, escapa de costado o incluso pasando al lado del kart.

const Bordes := preload("res://ai/tasks/bordes.gd")

@export var distancia: float = 25.0
@export var guardar_en: StringName = &"pos"
## Metros libres que el jabalí quiere tener alrededor del punto al que huye
@export var margen_borde: float = 20.0

# Primero las direcciones "para atrás", después las de costado, al final las de frente
const ANGULOS := [0, 30, -30, 60, -60, 90, -90, 120, -120, 150, -150, 180]


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

	var mejor_punto := Vector3.ZERO
	var mejor_puntaje := -INF
	for ang in ANGULOS:
		var p: Vector3 = agent.global_position + away.rotated(Vector3.UP, deg_to_rad(ang)) * distancia
		var c: Vector3 = NavigationServer3D.map_get_closest_point(map, p)
		if c == Vector3.ZERO:
			continue
		# Si el punto quedó muy cerca de donde está, es porque atrás hay pared: no sirve
		if Vector2(c.x - agent.global_position.x, c.z - agent.global_position.z).length() < distancia * 0.5:
			continue
		var libre := Bordes.espacio_libre(map, c, margen_borde)            # 0..1
		var lejos := c.distance_to(mas_cercano.global_position) / (distancia * 2.0)
		# Lo más importante: no ir a un borde. Después: alejarse del kart.
		var puntaje := libre * 3.0 + lejos
		if puntaje > mejor_puntaje:
			mejor_puntaje = puntaje
			mejor_punto = c

	if mejor_punto == Vector3.ZERO:
		return FAILURE
	blackboard.set_var(guardar_en, mejor_punto)
	agent.set_estado("¡Huyendo!")
	return SUCCESS
