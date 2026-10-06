extends Node

@export var boton_host: Button
@export var boton_cliente: Button
@export var campo_sala: LineEdit
@export var label_log: Label
@export var panel_menu: Control
@export var escena_jugador: PackedScene

var nombre_sala := "MiSala"
var soy_host := false


func _ready() -> void:
	boton_host.pressed.connect(crear_host)
	boton_cliente.pressed.connect(unirse_cliente)

	GDSync.connected.connect(_al_conectar)
	GDSync.connection_failed.connect(_conexion_fallida)
	GDSync.lobby_created.connect(_sala_creada)
	GDSync.lobby_creation_failed.connect(_sala_fallo)
	GDSync.lobby_join_failed.connect(_union_fallo)
	GDSync.client_joined.connect(_cliente_entro)
	GDSync.client_left.connect(_cliente_salio)

	log_pantalla("LISTO")


func _leer_nombre_sala() -> void:
	var texto := campo_sala.text.strip_edges()
	if not texto.is_empty():
		nombre_sala = texto


func _bloquear_menu(bloqueado: bool) -> void:
	boton_host.disabled = bloqueado
	boton_cliente.disabled = bloqueado
	campo_sala.editable = not bloqueado


func crear_host() -> void:
	_leer_nombre_sala()
	soy_host = true
	_bloquear_menu(true)
	log_pantalla("CONECTANDO (host)...")
	GDSync.start_multiplayer()


func unirse_cliente() -> void:
	_leer_nombre_sala()
	soy_host = false
	_bloquear_menu(true)
	log_pantalla("CONECTANDO (cliente)...")
	GDSync.start_multiplayer()


func _al_conectar() -> void:
	log_pantalla("CONECTADO. Sala: " + nombre_sala)
	if soy_host:
		GDSync.lobby_create(nombre_sala, "", true, 4)
	else:
		GDSync.lobby_join(nombre_sala, "")


func _sala_creada(lobby_name: String) -> void:
	log_pantalla("SALA CREADA: " + lobby_name)
	GDSync.lobby_join(lobby_name, "")


func _cliente_entro(client_id: int) -> void:
	log_pantalla("JUGADOR ENTRO: " + str(client_id))

	var es_mio := client_id == GDSync.get_client_id()
	if es_mio:
		panel_menu.hide()

	var jugador = escena_jugador.instantiate()
	jugador.name = str(client_id)
	jugador.position = Vector3((client_id % 5) * 4.0, 2.0, 0.0)  # ajusta a tu arena
	add_child(jugador)

	GDSync.set_gdsync_owner(jugador, client_id)

	# Solo mi cámara debe estar activa
	var cam = jugador.find_child("Camera3D", true, false)
	if cam:
		cam.current = es_mio


func _cliente_salio(client_id: int) -> void:
	log_pantalla("JUGADOR SALIO: " + str(client_id))
	var nodo = get_node_or_null(str(client_id))
	if nodo:
		nodo.queue_free()


func _conexion_fallida(error: int) -> void:
	log_pantalla("FALLO LA CONEXION: " + str(error))
	_bloquear_menu(false)

func _sala_fallo(lobby_name: String, error: int) -> void:
	log_pantalla("NO SE PUDO CREAR LA SALA: " + str(error))
	_bloquear_menu(false)

func _union_fallo(lobby_name: String, error: int) -> void:
	log_pantalla("NO SE PUDO ENTRAR A LA SALA: " + str(error))
	_bloquear_menu(false)


func log_pantalla(texto: String) -> void:
	print(texto)
	if label_log:
		label_log.text += texto + "\n"
