## Funciones para que el jabalí no se acerque a los bordes del mapa.
## Las usan elegir_punto_huida.gd y elegir_pos_aleatoria.gd.
##
## Antes se medía con el mapa de navegación (map_get_closest_point), pero en
## esta arena cada consulta tarda ~0,5 ms (el navmesh tiene más de 3000
## polígonos) y se hacían ~100 por decisión: tirones de 50 ms en la física.
## Ahora se mide con rayos contra las paredes invisibles (nodo "Limites"),
## que tardan microsegundos.
extends RefCounted

## Capa de física de las paredes invisibles (Limites): capa 8 (valor 128).
const CAPA_LIMITES := 128
const SONDAS := 8          # cuántas direcciones mira alrededor del punto
const ALTURA_RAYO := 3.0   # los rayos van a esta altura sobre el punto


## Qué tan "libre" está el lugar alrededor de `punto`, de 0 a 1.
## Tira 8 rayos en círculo de `margen` metros: cada uno que NO choca con una
## pared suma. 1 = campo abierto, ~0.6 = contra una pared, menos = en una esquina.
static func espacio_libre(mundo: World3D, punto: Vector3, margen: float) -> float:
	var libres := 0
	for i in SONDAS:
		var ang := TAU * i / SONDAS
		var hasta := punto + Vector3(cos(ang), 0.0, sin(ang)) * margen
		if not hay_pared(mundo, punto, hasta):
			libres += 1
	return float(libres) / SONDAS


## true si entre `desde` y `hasta` hay una pared invisible (Limites).
static func hay_pared(mundo: World3D, desde: Vector3, hasta: Vector3) -> bool:
	var arriba := Vector3.UP * ALTURA_RAYO
	var consulta := PhysicsRayQueryParameters3D.create(desde + arriba, hasta + arriba, CAPA_LIMITES)
	return not mundo.direct_space_state.intersect_ray(consulta).is_empty()
