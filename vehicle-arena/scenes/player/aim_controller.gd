extends Node

## Calcula hacia dónde apunta el jugador y dispara hacia ahí.
## - Android: joystick derecho. Tirás para un lado y al soltarlo dispara
##   (igual que antes). Mientras lo arrastrás, direccion_apuntado() ya da
##   la dirección, así el indicador puede mostrarla.
## - PC: el mouse. Se dispara con clic izquierdo o con Espacio.
## El IndicadorApuntado le pregunta la dirección a este nodo.

# Acciones que mueve el joystick. Las creamos por código para no tocar el
# Input Map; así el joystick no usa las ui_* (flechas del teclado).
const APUNTAR_IZQUIERDA := &"apuntar_izquierda"
const APUNTAR_DERECHA := &"apuntar_derecha"
const APUNTAR_ARRIBA := &"apuntar_arriba"
const APUNTAR_ABAJO := &"apuntar_abajo"

## Se emite cada vez que sale una bala (el indicador lo usa para mostrarse).
## `fuerza` va de 0 a 1: cuánto estiraste el joystick (en PC siempre 1).
signal disparo(direccion: Vector3, fuerza: float)
## Se emite cuando el disparo queda cargado (el indicador hace un destello).
signal carga_completa

## Por debajo de esto (0 a 1) el joystick se considera suelto.
const ZONA_MUERTA_JOYSTICK := 0.2
## Un toque más corto que esto (en segundos) y casi sin mover el dedo
## cuenta como "toque": hace explotar las balas en vez de apuntar.
const DURACION_MAXIMA_TOQUE := 0.25
## Desde qué fuerza (0 a 1) se considera que el círculo está cerrado
const FUERZA_PARA_CARGAR := 0.95

@export var joystick: VirtualJoystick
@export var weapon: Weapon
@export var camera: Camera3D
@export var vehicle: Node3D   # arrastrá acá Kart1 (el VehicleBody3D)
@export var boton_explotar: BaseButton   # botón del HUD que hace explotar la última bala

## true en PC (apunta con el mouse), false en Android (joystick).
var usar_mouse := not OS.has_feature("mobile")

@export_group("Ráfaga (Android)")
## Segundos que hay que mantener el círculo cerrado para cargar la ráfaga
@export var tiempo_carga := 0.5
## Cuántas balas salen en la ráfaga
@export var balas_rafaga := 3
## Segundos entre bala y bala de la ráfaga (más de 0,08 para que el host
## no descarte golpes: el validador rechaza dos golpes en menos de 80 ms)
@export var intervalo_rafaga := 0.12

var _cargando_desde := -1.0   # cuándo cerraste el círculo (-1 = no está cerrado)
var _cargado := false

var _inicio_toque := 0.0   # cuándo apoyaste el dedo en el joystick


func _ready() -> void:
	_crear_acciones_apuntar()
	joystick.action_left = APUNTAR_IZQUIERDA
	joystick.action_right = APUNTAR_DERECHA
	joystick.action_up = APUNTAR_ARRIBA
	joystick.action_down = APUNTAR_ABAJO
	joystick.flicked.connect(_on_flicked)
	joystick.pressed.connect(func(): _inicio_toque = _ahora())
	joystick.released.connect(_al_soltar_joystick)
	if boton_explotar != null:
		boton_explotar.pressed.connect(_explotar_bala)
		# En Android se explota tocando el lado derecho de la pantalla (el joystick);
		# el botón queda solo para PC.
		boton_explotar.visible = usar_mouse

	if usar_mouse:
		_apagar_joystick()   # en PC no se usa
		return
	# GD-Sync puede tardar un momento en asignar el dueño
	await get_tree().create_timer(0.5).timeout
	if vehicle != null and not GDSync.is_gdsync_owner(vehicle):
		_apagar_joystick()


func _process(_delta: float) -> void:
	if usar_mouse:
		return
	# Carga de la ráfaga: círculo cerrado (joystick al máximo) durante `tiempo_carga`
	if apuntando_con_joystick() and fuerza_apuntado() >= FUERZA_PARA_CARGAR:
		if _cargando_desde < 0.0:
			_cargando_desde = _ahora()
		elif not _cargado and _ahora() - _cargando_desde >= tiempo_carga:
			_cargado = true
			carga_completa.emit()
	elif apuntando_con_joystick():
		# Aflojaste: el círculo se abrió y se pierde la carga
		_cargando_desde = -1.0
		_cargado = false
	# (si soltaste el joystick no tocamos nada: _on_flicked usa la carga y la reinicia)


## true si la ráfaga está cargada (el indicador lo usa para brillar más).
func esta_cargado() -> bool:
	return _cargado


func _physics_process(_delta: float) -> void:
	# Espacio: dispara hacia donde apunta el mouse en PC
	# (en Android no hay teclado, así que esto no corre)
	if Input.is_action_just_pressed("disparar"):
		_disparar(direccion_apuntado(), fuerza_apuntado())


func _unhandled_input(event: InputEvent) -> void:
	# Clic izquierdo en PC. Va en _unhandled_input para que tocar un botón
	# de la interfaz (LOG, Volver a la sala...) no dispare.
	if not usar_mouse:
		return
	var boton := event as InputEventMouseButton
	if boton == null or not boton.pressed:
		return
	if boton.button_index == MOUSE_BUTTON_LEFT:
		_disparar(direccion_apuntado(), fuerza_apuntado())
	elif boton.button_index == MOUSE_BUTTON_RIGHT:
		_explotar_bala()   # clic derecho: hace explotar las balas


## Cuánto estás estirando el joystick, de 0 (apenas) a 1 (al máximo).
## En PC siempre 1 (por ahora el mouse no tiene fuerza).
func fuerza_apuntado() -> float:
	if usar_mouse:
		return 1.0
	var v := Input.get_vector(APUNTAR_IZQUIERDA, APUNTAR_DERECHA, APUNTAR_ARRIBA, APUNTAR_ABAJO)
	return _fuerza_desde(v.length())


# El largo del joystick va de 0 a 1, pero por debajo de la zona muerta no cuenta:
# lo pasamos a 0 (justo al salir de la zona muerta) .. 1 (estirado del todo).
func _fuerza_desde(largo: float) -> float:
	return clampf(inverse_lerp(ZONA_MUERTA_JOYSTICK, 1.0, largo), 0.0, 1.0)


## Dirección (en el mundo, plana) hacia donde saldría la bala ahora mismo.
## Vector3.ZERO si en este momento no se está apuntando
## (por ejemplo, el joystick suelto en Android).
func direccion_apuntado() -> Vector3:
	if usar_mouse:
		return _direccion_mouse()
	var v := Input.get_vector(APUNTAR_IZQUIERDA, APUNTAR_DERECHA, APUNTAR_ARRIBA, APUNTAR_ABAJO)
	if v.length() < ZONA_MUERTA_JOYSTICK:
		return Vector3.ZERO
	return _screen_to_world(-v)


func _on_flicked(input_vector: Vector2) -> void:
	var estaba_cargado := _cargado
	_cargando_desde = -1.0
	_cargado = false
	# Si el dedo casi no se movió, fue un toque (lo maneja _al_soltar_joystick)
	if input_vector.length() < ZONA_MUERTA_JOYSTICK:
		return
	var direccion := _screen_to_world(-input_vector)
	var fuerza := _fuerza_desde(input_vector.length())
	if estaba_cargado:
		_rafaga(direccion, fuerza)
	else:
		_disparar(direccion, fuerza)


# Varias balas seguidas en la misma dirección
func _rafaga(direccion: Vector3, fuerza: float) -> void:
	for i in balas_rafaga:
		if i > 0:
			await get_tree().create_timer(intervalo_rafaga).timeout
		_disparar(direccion, fuerza, true)   # true: no espera la cadencia normal


func _disparar(direccion: Vector3, fuerza: float, ignorar_cadencia := false) -> void:
	if vehicle == null or not GDSync.is_gdsync_owner(vehicle):
		return
	if vehicle._muerto:
		return
	if direccion == Vector3.ZERO:
		direccion = vehicle.global_transform.basis.z   # sin apuntar: para adelante
	if weapon.shoot(direccion, ignorar_cadencia):
		disparo.emit(direccion, fuerza)


# Al soltar el joystick: si fue un toque rápido y sin arrastrar, explotan las balas.
# Si arrastraste, ya disparó _on_flicked y acá no hacemos nada.
func _al_soltar_joystick(input_vector: Vector2) -> void:
	var fue_rapido := _ahora() - _inicio_toque <= DURACION_MAXIMA_TOQUE
	if fue_rapido and input_vector.length() < ZONA_MUERTA_JOYSTICK:
		_explotar_bala()


func _ahora() -> float:
	return Time.get_ticks_msec() / 1000.0


func _explotar_bala() -> void:
	if vehicle == null or not GDSync.is_gdsync_owner(vehicle):
		return
	if vehicle._muerto:
		return
	weapon.detonar()


## true mientras estás arrastrando el joystick (solo Android).
func apuntando_con_joystick() -> bool:
	return not usar_mouse and direccion_apuntado() != Vector3.ZERO


# Tira un rayo desde la cámara por donde está el mouse y ve dónde corta
# un plano horizontal a la altura del kart.
func _direccion_mouse() -> Vector3:
	var cam := _camara()
	if cam == null or vehicle == null:
		return Vector3.ZERO
	var mouse := get_viewport().get_mouse_position()
	var origen := cam.project_ray_origin(mouse)
	var normal := cam.project_ray_normal(mouse)
	var plano := Plane(Vector3.UP, vehicle.global_position.y)
	var punto = plano.intersects_ray(origen, normal)   # null si el rayo no corta el plano
	if punto == null:
		return Vector3.ZERO
	var dir: Vector3 = punto - vehicle.global_position
	dir.y = 0.0
	if dir.length() < 0.5:   # mouse justo encima del kart: no hay dirección clara
		return Vector3.ZERO
	return dir.normalized()


func _screen_to_world(dir2d: Vector2) -> Vector3:
	var cam := _camara()
	if cam == null:
		return Vector3.ZERO
	var right := cam.global_transform.basis.x
	var forward := -cam.global_transform.basis.z
	right.y = 0.0
	forward.y = 0.0
	right = right.normalized()
	forward = forward.normalized()
	return right * dir2d.x + forward * -dir2d.y


func _camara() -> Camera3D:
	return camera if camera != null else get_viewport().get_camera_3d()


func _apagar_joystick() -> void:
	joystick.hide()                      # deja de recibir toques
	joystick.process_mode = Node.PROCESS_MODE_DISABLED


func _crear_acciones_apuntar() -> void:
	for accion in [APUNTAR_IZQUIERDA, APUNTAR_DERECHA, APUNTAR_ARRIBA, APUNTAR_ABAJO]:
		if not InputMap.has_action(accion):
			InputMap.add_action(accion, 0.0)
