extends Node3D

## Círculo con una flecha alrededor del kart que muestra hacia dónde vas a disparar.
## La dirección se la pide a AimController (la misma que usa para disparar).
## Solo lo ve el dueño del kart y no se sincroniza por red: es una ayuda visual.
## Aparece mientras apuntás con el joystick (Android) y, al disparar,
## el círculo se contrae rápido hacia la flecha y desaparece (PC y Android).
## El círculo se va cerrando según cuánto estirás el joystick: apenas lo movés
## es un arco chico delante de la flecha; estirado del todo, el círculo completo.
## Cuando la ráfaga queda cargada hace un destello de luz y sigue brillando más.

@export var vehicle: Node3D          # Kart1
@export var aim_controller: Node     # AimController
## Radio del círculo, en metros (el kart mide unos 1,8 x 3,5).
@export var radio := 2.3
## Altura respecto del centro del kart (negativo = más cerca del piso).
@export var altura := -0.2
## Segundos que tarda el círculo en contraerse después de disparar
## (más chico = más rápido).
@export var duracion_contraccion := 0.15
## Tamaño del arco (en grados) cuando apenas estirás el joystick.
@export var arco_minimo := 40.0
## Grosor del aro, en metros (radio del "tubo").
@export var grosor := 0.08

@export_group("Destello de carga")
## Cuánto más brilla el aro en el destello (3 = cuatro veces el brillo normal)
@export var brillo_destello := 3.0
## Cuánto más brilla mientras está cargado (0,6 = 60 % más)
@export var brillo_cargado := 0.6
## Segundos que dura el destello
@export var duracion_destello := 0.3
## Intensidad máxima de la luz que ilumina el piso alrededor del kart
@export var energia_luz := 6.0

const SEGMENTOS_CIRCULO := 64   # cuántos tramos tiene el círculo completo
const LADOS_TUBO := 6           # lados del "tubo" del aro

var _momento_disparo := -1000.0     # cuándo fue el último disparo (en segundos)
var _ultima_direccion := Vector3.ZERO
var _material: StandardMaterial3D   # copia propia, para cambiarle la transparencia
var _alfa_base := 1.0
var _emision_base := 1.0
var _ultima_fuerza := 1.0
var _malla_arco := ImmediateMesh.new()   # el aro, armado por código
var _grados_dibujados := -1.0
var _frames_precalentar := 3   # se dibuja casi invisible al empezar, para compilar su shader
var _destello := 0.0           # 1 justo al cargar, baja a 0 en `duracion_destello`
var _luz := OmniLight3D.new()  # el destello de luz sobre el piso

@onready var circulo: MeshInstance3D = $Circulo
@onready var flecha: MeshInstance3D = $Flecha


func _ready() -> void:
	# No hereda la inclinación del kart: siempre queda plano.
	# La posición la copiamos a mano en _process.
	top_level = true
	visible = false
	# Lo movemos nosotros en _process (sigue al kart): sin interpolación de física
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF

	# La flecha (un prisma) queda acostada, con la punta hacia -Z,
	# justo afuera del círculo. Al girar este nodo, la flecha da la vuelta.
	flecha.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	flecha.position = Vector3(0.0, 0.0, -(radio + 0.45))

	# Copiamos el material para que el desvanecido no toque el recurso original
	# (lo comparten el círculo, la flecha y los indicadores de los otros karts).
	var original := circulo.mesh.surface_get_material(0) as StandardMaterial3D
	if original != null:
		_material = original.duplicate() as StandardMaterial3D
		_alfa_base = _material.albedo_color.a
		_emision_base = _material.emission_energy_multiplier
		_configurar_para_que_lo_tape_el_kart(_material)
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED   # el aro se ve de cualquier lado
		circulo.material_override = _material
		flecha.material_override = _material
	# El TorusMesh de la escena queda para verlo en el editor y tomar su material;
	# en el juego lo reemplazamos por el arco que armamos nosotros.
	circulo.mesh = _malla_arco
	_dibujar_arco(360.0)
	_marcar_kart(vehicle)

	if aim_controller != null:
		aim_controller.disparo.connect(_al_disparar)
		if aim_controller.has_signal("carga_completa"):
			aim_controller.carga_completa.connect(_al_cargar)

	# Luz del destello: mismo color que el brillo del aro, apagada hasta que cargues
	_luz.light_color = _material.emission if _material != null else Color.WHITE
	_luz.omni_range = radio * 3.0
	_luz.light_energy = 0.0
	_luz.shadow_enabled = false
	add_child(_luz)


# Queremos que el kart tape al indicador, pero el piso y el resto del mundo no.
# Para eso usamos el stencil buffer (Godot 4.5+):
#   1. El kart "marca" con un 1 los píxeles donde se dibuja (_marcar_kart).
#   2. El indicador se dibuja sin prueba de profundidad (nada del mundo lo tapa)
#      pero solo en los píxeles que NO tienen esa marca.
const MARCA_KART := 1

func _configurar_para_que_lo_tape_el_kart(material: StandardMaterial3D) -> void:
	material.no_depth_test = true
	material.stencil_mode = BaseMaterial3D.STENCIL_MODE_CUSTOM
	material.stencil_flags = BaseMaterial3D.STENCIL_FLAG_READ
	material.stencil_compare = BaseMaterial3D.STENCIL_COMPARE_NOT_EQUAL
	material.stencil_reference = MARCA_KART
	material.render_priority = 1   # después de la marca del kart


# A cada pieza del kart le agregamos una pasada invisible que escribe la marca.
# Va como material_overlay para no tocar los materiales del modelo.
func _marcar_kart(kart: Node) -> void:
	if kart == null:
		return
	var marca := StandardMaterial3D.new()
	marca.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	marca.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	marca.albedo_color = Color(0, 0, 0, 0)   # invisible
	marca.stencil_mode = BaseMaterial3D.STENCIL_MODE_CUSTOM
	marca.stencil_flags = BaseMaterial3D.STENCIL_FLAG_WRITE
	marca.stencil_compare = BaseMaterial3D.STENCIL_COMPARE_ALWAYS
	marca.stencil_reference = MARCA_KART
	marca.render_priority = -1   # antes que el indicador
	for pieza in kart.find_children("*", "MeshInstance3D", true, false):
		(pieza as MeshInstance3D).material_overlay = marca


func _al_disparar(direccion: Vector3, fuerza: float) -> void:
	_ultima_direccion = direccion
	_ultima_fuerza = fuerza
	_momento_disparo = _ahora()


func _al_cargar() -> void:
	_destello = 1.0


func _process(delta: float) -> void:
	_destello = move_toward(_destello, 0.0, delta / maxf(duracion_destello, 0.01))
	if vehicle == null or aim_controller == null:
		return
	if not GDSync.is_gdsync_owner(vehicle) or vehicle._muerto:
		visible = false
		return
	var dir: Vector3 = aim_controller.direccion_apuntado()
	if dir != Vector3.ZERO:
		_ultima_direccion = dir   # en PC sigue al mouse mientras está visible

	# Tamaño del arco según cuánto estirás el joystick
	var grados := lerpf(arco_minimo, 360.0, _ultima_fuerza)
	# 1 = se ve entero, 0 = invisible
	var opacidad := 1.0
	if aim_controller.apuntando_con_joystick():
		_ultima_fuerza = aim_controller.fuerza_apuntado()
		grados = lerpf(arco_minimo, 360.0, _ultima_fuerza)
	else:
		# Después de disparar: `queda` baja de 1 a 0 en `duracion_contraccion`.
		# El arco se achica hacia la flecha y en el último tramo se apaga.
		var pasado := _ahora() - _momento_disparo
		var queda := 1.0 - clampf(pasado / maxf(duracion_contraccion, 0.01), 0.0, 1.0)
		grados *= queda
		opacidad = clampf(queda * 3.0, 0.0, 1.0)

	# Los primeros frames se dibuja casi invisible para que Godot compile su shader
	# ahora y no en el primer disparo (ver precalentar_shaders.gd).
	if _frames_precalentar > 0:
		_frames_precalentar -= 1
		opacidad = maxf(opacidad, 0.01)

	visible = opacidad > 0.0
	if not visible:
		return
	# Brillo extra: el destello al cargar, y un poco más mientras siga cargado
	var cargado: bool = aim_controller.has_method("esta_cargado") and aim_controller.esta_cargado()
	var extra := brillo_destello * _destello + (brillo_cargado if cargado else 0.0)
	if _material != null:
		_material.albedo_color.a = _alfa_base * opacidad
		_material.emission_energy_multiplier = _emision_base * opacidad * (1.0 + extra)
	_luz.light_energy = energia_luz * _destello

	_dibujar_arco(grados)
	# Posición interpolada del kart, igual que la cámara (si no, tiembla respecto del auto)
	global_position = vehicle.get_global_transform_interpolated().origin + Vector3.UP * altura
	if _ultima_direccion != Vector3.ZERO:
		global_basis = Basis.looking_at(_ultima_direccion, Vector3.UP)   # -Z mira hacia la dirección
	# En el destello el aro se agranda un poquito y vuelve
	global_basis = global_basis.orthonormalized().scaled(Vector3.ONE * (1.0 + 0.15 * _destello))


func _ahora() -> float:
	return Time.get_ticks_msec() / 1000.0


# Arma el aro como un "tubo" curvo de `grados` de largo, centrado delante
# de la flecha (hacia -Z). Con 360 queda el círculo completo.
func _dibujar_arco(grados: float) -> void:
	grados = clampf(grados, 1.0, 360.0)
	if absf(grados - _grados_dibujados) < 0.5:
		return   # no cambió: no hace falta rearmarlo
	_grados_dibujados = grados

	var tramos := maxi(2, ceili(SEGMENTOS_CIRCULO * grados / 360.0))
	var desde := deg_to_rad(-grados / 2.0)
	var hasta := deg_to_rad(grados / 2.0)

	_malla_arco.clear_surfaces()
	_malla_arco.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in tramos:
		var a0 := lerpf(desde, hasta, float(i) / tramos)
		var a1 := lerpf(desde, hasta, float(i + 1) / tramos)
		for j in LADOS_TUBO:
			var t0 := TAU * j / LADOS_TUBO
			var t1 := TAU * (j + 1) / LADOS_TUBO
			var p00 := _punto_tubo(a0, t0)
			var p01 := _punto_tubo(a0, t1)
			var p10 := _punto_tubo(a1, t0)
			var p11 := _punto_tubo(a1, t1)
			_vertice(p00, a0, t0)
			_vertice(p10, a1, t0)
			_vertice(p11, a1, t1)
			_vertice(p00, a0, t0)
			_vertice(p11, a1, t1)
			_vertice(p01, a0, t1)
	_malla_arco.surface_end()


# Hacia afuera del círculo, para el ángulo `a` (0 = delante, hacia -Z)
func _afuera(a: float) -> Vector3:
	return Vector3(sin(a), 0.0, -cos(a))


# Dirección "hacia afuera" de la superficie del tubo.
# `a` dice en qué parte del círculo, `t` en qué parte del grosor.
func _normal_tubo(a: float, t: float) -> Vector3:
	return _afuera(a) * cos(t) + Vector3.UP * sin(t)


# Punto de la superficie del tubo
func _punto_tubo(a: float, t: float) -> Vector3:
	return _afuera(a) * radio + _normal_tubo(a, t) * grosor


func _vertice(punto: Vector3, a: float, t: float) -> void:
	_malla_arco.surface_set_normal(_normal_tubo(a, t))
	_malla_arco.surface_add_vertex(punto)
