extends Node

## Toda la lógica de red del juego (GD-Sync) vive acá.
## El menú (o el lobby, más adelante) solo llama a:
##   NetworkManager.crear_sala(nombre)
##   NetworkManager.unirse_a_sala(nombre)
##   NetworkManager.probar_offline()
## y escucha estas señales para actualizar la pantalla:

signal estado_cambiado(texto: String)   # mensajes para mostrar al jugador
signal partida_iniciada                  # entraste a la partida: ocultar el menú
signal conexion_fallida                  # algo salió mal: desbloquear el menú

# Se cargan por UID, así no se rompen si movés o renombrás los archivos.
const ESCENA_JUGADOR: PackedScene = preload("uid://bswy0tnc4txqv")   # scenes/player/player.tscn
const ESCENA_ARENA: PackedScene = preload("uid://dtfdnacujyrlc")     # scenes/main/main.tscn

const MAX_JUGADORES := 4

var nombre_sala := "MiSala"
var soy_host := false
var _arena: Node = null


func _ready() -> void:
	# Diferido para que GDSync (otro autoload) ya esté listo cuando nos conectamos
	_conectar_senales.call_deferred()


func _conectar_senales() -> void:
	GDSync.connected.connect(_al_conectar)
	GDSync.connection_failed.connect(_al_fallar_conexion)
	GDSync.lobby_created.connect(_al_crear_sala)
	GDSync.lobby_creation_failed.connect(_al_fallar_crear_sala)
	GDSync.lobby_join_failed.connect(_al_fallar_unirse)
	GDSync.client_joined.connect(_al_entrar_cliente)
	GDSync.client_left.connect(_al_salir_cliente)
	_estado("SISTEMA DE RED LISTO")


# ---- Lo que llama el menú ---------------------------------------------------

func crear_sala(nombre: String) -> void:
	_iniciar(nombre, true)


func unirse_a_sala(nombre: String) -> void:
	_iniciar(nombre, false)


## Botón "Test": arena + jugador sin conectarse a ningún servidor.
func probar_offline() -> void:
	partida_iniciada.emit()
	if _arena != null:
		return
	_crear_arena()
	get_tree().current_scene.add_child(ESCENA_JUGADOR.instantiate())


# ---- Conexión y salas -------------------------------------------------------

func _iniciar(nombre: String, como_host: bool) -> void:
	nombre = nombre.strip_edges()
	if not nombre.is_empty():
		nombre_sala = nombre
	soy_host = como_host
	_estado("CONECTANDO (host)..." if como_host else "CONECTANDO (cliente)...")
	GDSync.start_multiplayer()


func _al_conectar() -> void:
	_estado("CONECTADO. Sala: " + nombre_sala)
	if soy_host:
		GDSync.lobby_create(nombre_sala, "", true, MAX_JUGADORES)
	else:
		GDSync.lobby_join(nombre_sala, "")


func _al_crear_sala(lobby_name: String) -> void:
	_estado("SALA CREADA: " + lobby_name)
	GDSync.lobby_join(lobby_name, "")


# ---- Jugadores ----------------------------------------------------------------

func _al_entrar_cliente(client_id: int) -> void:
	_estado("JUGADOR ENTRO: " + str(client_id))
	var es_mio := client_id == GDSync.get_client_id()

	# Si el que entró soy yo: arranca la partida en mi pantalla
	if es_mio:
		partida_iniciada.emit()
		if _arena == null:
			_crear_arena()

	# Crear el vehículo de ese jugador (el mío o el de otro)
	var jugador: Node3D = ESCENA_JUGADOR.instantiate()
	jugador.name = str(client_id)
	jugador.position = Vector3((client_id % 5) * 4.0, 2.0, 0.0)
	# Primero agregarlo al árbol, después asignar el dueño (si no, GD-Sync da error)
	get_tree().current_scene.add_child(jugador)
	GDSync.set_gdsync_owner(jugador, client_id)

	# Los jugadores de otros no muestran su HUD ni leen los toques de esta pantalla
	if not es_mio:
		_desactivar_controles_locales(jugador)

	# Solo la cámara de MI vehículo queda activa
	var cam = jugador.find_child("Camera3D", true, false)
	if cam:
		cam.current = es_mio
	else:
		push_error("No se encontró 'Camera3D' en el vehículo instanciado.")


## Cada jugador es un player.tscn completo, con HUD y controles táctiles.
## En la pantalla de cada uno, solo el propio debe verse y responder.
func _desactivar_controles_locales(jugador: Node) -> void:
	var hud = jugador.get_node_or_null("hud")
	if hud:
		hud.hide()
		# Un CanvasLayer no se oculta cuando se oculta su padre: hay que ocultarlo aparte
		var capa = hud.get_node_or_null("CanvasLayer")
		if capa:
			capa.hide()
	var touch = jugador.get_node_or_null("TouchGestureController")
	if touch:
		touch.process_mode = Node.PROCESS_MODE_DISABLED


func _al_salir_cliente(client_id: int) -> void:
	_estado("JUGADOR SALIO: " + str(client_id))
	var nodo = get_tree().current_scene.get_node_or_null(str(client_id))
	if nodo:
		nodo.queue_free()


func _crear_arena() -> void:
	_arena = ESCENA_ARENA.instantiate()
	get_tree().current_scene.add_child(_arena)


# ---- Errores y mensajes --------------------------------------------------------

func _al_fallar_conexion(error: int) -> void:
	_fallo("FALLO LA CONEXIÓN: " + str(error))


func _al_fallar_crear_sala(_lobby_name: String, error: int) -> void:
	_fallo("NO SE PUDO CREAR LA SALA: " + str(error))


func _al_fallar_unirse(_lobby_name: String, error: int) -> void:
	_fallo("NO SE PUDO ENTRAR A LA SALA: " + str(error))


func _fallo(texto: String) -> void:
	_estado(texto)
	conexion_fallida.emit()


func _estado(texto: String) -> void:
	print(texto)
	estado_cambiado.emit(texto)
