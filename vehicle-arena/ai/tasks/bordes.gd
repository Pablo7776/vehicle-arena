## Funciones para que el jabalí no se acerque a los bordes del mapa.
## Las usan elegir_punto_huida.gd y elegir_pos_aleatoria.gd.
extends RefCounted

const SONDAS := 8   # cuántas direcciones mira alrededor del punto


## Qué tan "libre" está el lugar alrededor de `punto`, de 0 a 1.
## Mira 8 puntos en círculo a `margen` metros: cada uno que cae dentro del
## mapa de navegación suma. 1 = campo abierto, 0.5 = contra una pared,
## menos = en una esquina.
static func espacio_libre(map: RID, punto: Vector3, margen: float) -> float:
	var libres := 0
	for i in SONDAS:
		var ang := TAU * i / SONDAS
		var sonda := punto + Vector3(cos(ang), 0.0, sin(ang)) * margen
		if dentro_del_mapa(map, sonda, margen * 0.25):
			libres += 1
	return float(libres) / SONDAS


## true si el punto del mapa de navegación más cercano a `p` está a menos
## de `tolerancia` metros (en horizontal). Si está más lejos, `p` cae afuera
## (más allá de un borde o una pared).
static func dentro_del_mapa(map: RID, p: Vector3, tolerancia: float) -> bool:
	var c := NavigationServer3D.map_get_closest_point(map, p)
	if c == Vector3.ZERO:
		return false
	return Vector2(c.x - p.x, c.z - p.z).length() <= tolerancia
