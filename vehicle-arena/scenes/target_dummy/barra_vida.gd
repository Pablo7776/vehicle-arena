extends Node3D

## Barra de vida del jabalí, en su cuerpo: columnas verticales de segmentos
## verdes (como el rastro de olor) que se apagan de arriba hacia abajo a medida
## que pierde vida. Hay varias copias alrededor del cuerpo para verla desde
## cualquier ángulo.
##   - Con poca vida (menos de `umbral_bajo`) se pone roja y parpadea.
##   - Cada golpe hace un destello.
## La vida ya viaja por red (HealthComponent, When Host): cada jugador dibuja
## la barra a partir de ese valor, sin mandar nada nuevo.

@export var health: HealthComponent
@export var segmentos := 10
## Cuántas columnas alrededor del cuerpo (3 = una cada 120°)
@export var caras := 3
## Distancia del centro del jabalí a cada columna (su cápsula mide 5 de radio)
@export var radio := 5.2
## Alto total de cada columna, y ancho de los segmentos, en metros
@export var alto := 8.0
@export var ancho := 0.8
## Verde del rastro de olor
@export var color := Color(0.4, 1.0, 0.27)
@export var color_bajo := Color(1.0, 0.15, 0.1)
@export_range(0.0, 1.0) var umbral_bajo := 0.25
@export var brillo := 8.0

var _columnas: Array = []   # una lista de segmentos por cada cara
var _material_encendido := StandardMaterial3D.new()
var _material_apagado := StandardMaterial3D.new()
var _fraccion := 1.0
var _vida_anterior := -1.0
var _golpe := 0.0   # 1 al recibir daño, baja a 0


func _ready() -> void:
	_material_encendido.albedo_color = Color(0.02, 0.02, 0.02)
	_material_encendido.emission_enabled = true
	_material_apagado.albedo_color = Color(0.03, 0.03, 0.03)
	_material_apagado.emission_enabled = true
	_material_apagado.emission = color
	_material_apagado.emission_energy_multiplier = 0.15   # el "riel" vacío, casi apagado

	var paso := alto / segmentos
	var malla := BoxMesh.new()
	malla.size = Vector3(ancho, paso * 0.8, 0.1)
	for c in caras:
		# Cada cara es un nodo girado alrededor del jabalí, con la columna hacia afuera
		var cara := Node3D.new()
		cara.rotation.y = TAU * c / caras
		add_child(cara)
		var columna: Array[MeshInstance3D] = []
		for i in segmentos:
			var s := MeshInstance3D.new()
			s.mesh = malla
			s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			# i = 0 abajo; se apagan de arriba hacia abajo
			s.position = Vector3(0.0, -alto / 2.0 + paso * (i + 0.5), radio)
			cara.add_child(s)
			columna.append(s)
		_columnas.append(columna)

	if health != null:
		health.health_changed.connect(_al_cambiar_vida)
		_al_cambiar_vida.call_deferred(health.current, health.max_health)


func _al_cambiar_vida(actual: float, maxima: float) -> void:
	if _vida_anterior >= 0.0 and actual < _vida_anterior:
		_golpe = 1.0
	_vida_anterior = actual
	_fraccion = clampf(actual / maxima, 0.0, 1.0) if maxima > 0.0 else 0.0
	var encendidos := ceili(_fraccion * segmentos)
	for columna in _columnas:
		for i in segmentos:
			columna[i].material_override = _material_encendido if i < encendidos else _material_apagado


func _process(delta: float) -> void:
	_golpe = move_toward(_golpe, 0.0, delta / 0.25)
	var c := color
	var intensidad := brillo * (1.0 + 3.0 * _golpe)
	if _fraccion <= umbral_bajo:
		# Poca vida: rojo y parpadeando
		c = color_bajo
		intensidad *= 0.35 + 0.65 * absf(sin(Time.get_ticks_msec() / 1000.0 * 6.0))
	_material_encendido.emission = c
	_material_encendido.emission_energy_multiplier = intensidad
