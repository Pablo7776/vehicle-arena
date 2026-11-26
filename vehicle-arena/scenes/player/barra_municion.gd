extends Node3D

## Barra de munición sobre el kart: segmentos que brillan del color de la bala
## y se van apagando a medida que disparás.
##   - Con poca munición (menos de `umbral_bajo`) se pone roja y parpadea.
##   - Al recargar (ítem de munición) hace un destello.
##   - Cada disparo hace un pequeño pulso de brillo.
## Solo la ve el dueño del kart: la munición no viaja por red (es información tuya).
## Va como hija de Kart1 en la escena del jugador, así se mueve con el auto.

@export var weapon: Weapon            # el arma de este kart
@export var segmentos := 10
## Ancho total y alto de la barra, en metros
@export var ancho := 1.6
@export var alto := 0.12
## Mismo color que la bala (el brillo de bullet_1.tscn)
@export var color := Color(0.105882354, 0.8901961, 0.7921569)
@export var color_bajo := Color(1.0, 0.15, 0.1)
## Fracción de munición desde la que avisa que queda poca (0,15 = 15 %)
@export_range(0.0, 1.0) var umbral_bajo := 0.15
## Qué tanto brilla (tu arena tiene la exposición baja: hace falta un valor alto)
@export var brillo := 8.0

var _segmentos: Array[MeshInstance3D] = []
var _material_encendido := StandardMaterial3D.new()
var _material_apagado := StandardMaterial3D.new()
var _fraccion := 1.0
var _municion_anterior := -1
var _destello := 0.0   # 1 al recargar, baja a 0
var _pulso := 0.0      # 1 al disparar, baja a 0 más rápido


func _ready() -> void:
	visible = false
	_material_encendido.albedo_color = Color(0.02, 0.02, 0.02)
	_material_encendido.emission_enabled = true
	_material_apagado.albedo_color = Color(0.03, 0.03, 0.03)
	_material_apagado.emission_enabled = true
	_material_apagado.emission = color
	_material_apagado.emission_energy_multiplier = 0.15   # el "riel" vacío, casi apagado

	# Armamos los segmentos de izquierda a derecha, vistos desde atrás del kart
	# (la cámara mira hacia +Z, así que +X queda a la izquierda de la pantalla)
	var paso := ancho / segmentos
	var malla := BoxMesh.new()
	malla.size = Vector3(paso * 0.8, alto, 0.04)
	for i in segmentos:
		var s := MeshInstance3D.new()
		s.mesh = malla
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.position.x = ancho / 2.0 - paso * (i + 0.5)
		add_child(s)
		_segmentos.append(s)

	if weapon != null:
		weapon.municion_cambiada.connect(_al_cambiar_municion)
		_al_cambiar_municion.call_deferred(weapon.municion_actual, weapon.municion_maxima)


func _al_cambiar_municion(actual: int, maxima: int) -> void:
	if _municion_anterior >= 0:
		if actual > _municion_anterior:
			_destello = 1.0   # recargaste
		elif actual < _municion_anterior:
			_pulso = 1.0      # disparaste
	_municion_anterior = actual
	_fraccion = float(actual) / maxima if maxima > 0 else 0.0
	var encendidos := ceili(_fraccion * segmentos)
	for i in segmentos:
		_segmentos[i].material_override = _material_encendido if i < encendidos else _material_apagado


func _process(delta: float) -> void:
	var kart := get_parent()
	visible = kart != null and GDSync.is_gdsync_owner(kart)
	if not visible:
		return
	_destello = move_toward(_destello, 0.0, delta / 0.4)
	_pulso = move_toward(_pulso, 0.0, delta / 0.12)

	var c := color
	var intensidad := brillo * (1.0 + 3.0 * _destello + 0.5 * _pulso)
	if _fraccion <= umbral_bajo:
		# Poca munición: rojo y parpadeando
		c = color_bajo
		intensidad *= 0.35 + 0.65 * absf(sin(Time.get_ticks_msec() / 1000.0 * 6.0))
	_material_encendido.emission = c
	_material_encendido.emission_energy_multiplier = intensidad
