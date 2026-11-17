extends Node

## Toda la lógica de red del juego (GD-Sync) vive acá.
## El menú y la sala de espera solo llaman a estas funciones:
##   NetworkManager.crear_sala(nombre) / unirse_a_sala(nombre)
##   NetworkManager.cambiar_nombre(nombre)
##   NetworkManager.marcar_listo(true / false)
##   NetworkManager.empezar_partida()      (solo el host, con todos listos)
##   NetworkManager.salir_de_sala()
##   NetworkManager.probar_offline()
## y escuchan estas señales para actualizar la pantalla
## (como los eventos de LobbyConnection en la clase 9):

signal estado_cambiado(texto: String)   # mensajes para mostrar al jugador
signal entraste_a_sala                   # estás en la sala de espera: ocultar el menú
signal sala_actualizada                  # alguien entró, salió o cambió su nombre
signal saliste_de_sala                   # volviste al menú
signal partida_iniciada                  # arrancó la partida: ocultar menú y sala
signal conexion_fallida                  # algo salió mal: desbloquear el menú

# Se cargan por UID, así no se rompen si movés o renombrás los archivos.
const ESCENA_JUGADOR: PackedScene = preload("uid://bswy0tnc4txqv")   # scenes/player/player.tscn
const ESCENA_ARENA: PackedScene = preload("uid://dtfdnacujyrlc")     # scenes/main/main.tscn

const MAX_JUGADORES := 4
## Mínimo de jugadores para empezar (gana el último vivo: con 1 solo nunca termina)
const MIN_JUGADORES := 2
## Dato de cada jugador que dice si marcó "Listo" (como "IsReady" en la clase 9)
const CLAVE_LISTO := "listo"
## Nombre del nodo de la arena que agrupa los Marker3D de aparición de jugadores
const NODO_PUNTOS_SPAWN := "PuntosSpawnJugadores"
## Si la arena no tiene puntos de aparición, se usa este lugar
const SPAWN_POR_DEFECTO := Vector3(0.0, 2.0, 0.0)

var nombre_sala := "MiSala"
var soy_host := false
var _arena: Node = null
var _partida_en_curso := false


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
	GDSync.player_data_changed.connect(_al_cambiar_datos_jugador)
	GDSync.host_changed.connect(func(_es_host, _nuevo_host): sala_actualizada.emit())
	GDSync.expose_func(_iniciar_partida_remoto)
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
	var jugador: Node3D = ESCENA_JUGADOR.instantiate()
	jugador.transform = _transform_de_spawn(0)
	get_tree().current_scene.add_child(jugador)


# ---- Lo que llama la sala de espera -----------------------------------------

## IDs de los jugadores de la sala, SIEMPRE en el mismo orden en todas las máquinas
## (ordenados de menor a mayor). Ese orden decide el punto de aparición de cada uno.
func jugadores_en_sala() -> Array:
	var ids: Array = GDSync.lobby_get_all_clients()
	ids.sort()
	return ids


## El nombre que eligió el jugador, o "Jugador ###" si todavía no eligió uno.
func nombre_de(client_id: int) -> String:
	var nombre := str(GDSync.player_get_username(client_id, "")).strip_edges()
	if nombre.is_empty():
		nombre = "Jugador %d" % (client_id % 1000)
	return nombre


func cambiar_nombre(nombre: String) -> void:
	nombre = nombre.strip_edges()
	if nombre.is_empty():
		return
	# Se guarda como dato del jugador y les llega a todos (señal player_data_changed),
	# igual que el dato "IsReady" de la clase 9.
	GDSync.player_set_username(nombre)


## Marca o desmarca "Listo". Es un dato del jugador: les llega a todos solo
## (señal player_data_changed), igual que "IsReady" con UpdatePlayerAsync en la clase 9.
func marcar_listo(listo: bool) -> void:
	GDSync.player_set_data(CLAVE_LISTO, listo)


func esta_listo(client_id: int) -> bool:
	return bool(GDSync.player_get_data(client_id, CLAVE_LISTO, false))


## Cuántos jugadores de la sala todavía no marcaron "Listo"
func cuantos_faltan_listos() -> int:
	var faltan := 0
	for id in jugadores_en_sala():
		if not esta_listo(id):
			faltan += 1
	return faltan


## Se puede empezar si hay suficientes jugadores y TODOS marcaron "Listo"
## (TodosListos() de la clase 9)
func se_puede_empezar() -> bool:
	return jugadores_en_sala().size() >= MIN_JUGADORES and cuantos_faltan_listos() == 0


## SOLO el host. Cierra la sala y arranca la partida en todas las máquinas.
func empezar_partida() -> void:
	if not GDSync.is_host() or _partida_en_curso:
		return
	# El host vuelve a validar: aunque el botón esté deshabilitado, no le creemos a la UI
	if not se_puede_empezar():
		_estado("Todavía no están todos listos")
		return
	GDSync.lobby_close()   # = IsLocked de la clase 9: nadie más entra con la partida empezada
	GDSync.call_func(_iniciar_partida_remoto)   # los demás
	_iniciar_partida()                           # yo


func salir_de_sala() -> void:
	GDSync.lobby_leave()
	_estado("Saliste de la sala")
	saliste_de_sala.emit()


# ---- Conexión y salas -------------------------------------------------------

func _iniciar(nombre: String, como_host: bool) -> void:
	nombre = nombre.strip_edges()
	if not nombre.is_empty():
		nombre_sala = nombre
	soy_host = como_host
	if GDSync.is_active():
		# Ya estamos conectados (por ejemplo, volviste de otra sala): directo a la sala
		_al_conectar()
		return
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


# ---- Sala de espera -----------------------------------------------------------

func _al_entrar_cliente(client_id: int) -> void:
	_estado("JUGADOR ENTRO: " + nombre_de(client_id))
	if client_id == GDSync.get_client_id():
		marcar_listo(false)   # al entrar a una sala, siempre arrancás "no listo"
		entraste_a_sala.emit()
	sala_actualizada.emit()


func _al_salir_cliente(client_id: int) -> void:
	_estado("JUGADOR SALIO: " + nombre_de(client_id))
	# Si ya estábamos jugando, sacamos su kart
	var nodo = get_tree().current_scene.get_node_or_null(str(client_id))
	if nodo:
		nodo.queue_free()
	sala_actualizada.emit()


func _al_cambiar_datos_jugador(_client_id: int, _clave: String, _valor) -> void:
	sala_actualizada.emit()


# ---- Partida ------------------------------------------------------------------

# Los parámetros de call_func pueden llegar empaquetados: no los usamos
func _iniciar_partida_remoto(_data = null) -> void:
	_iniciar_partida()


## Corre en TODAS las máquinas a la vez. Cada una crea la arena y los karts de todos,
## en el mismo orden, así que todas coinciden en el punto de aparición de cada jugador.
func _iniciar_partida() -> void:
	if _partida_en_curso:
		return
	_partida_en_curso = true
	partida_iniciada.emit()
	if _arena == null:
		_crear_arena()
	var ids := jugadores_en_sala()
	for i in ids.size():
		_crear_jugador(ids[i], i)


func _crear_jugador(client_id: int, indice_spawn: int) -> void:
	var es_mio := client_id == GDSync.get_client_id()
	var jugador: Node3D = ESCENA_JUGADOR.instantiate()
	jugador.name = str(client_id)
	jugador.transform = _transform_de_spawn(indice_spawn)
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


## Posición y rotación del punto de aparición número `indice`.
## Si hay más jugadores que puntos, rota: el quinto vuelve al primero.
func _transform_de_spawn(indice: int) -> Transform3D:
	var puntos := _puntos_de_spawn()
	if puntos.is_empty():
		push_warning("La arena no tiene '%s': uso el spawn por defecto." % NODO_PUNTOS_SPAWN)
		return Transform3D(Basis.IDENTITY, SPAWN_POR_DEFECTO)
	var t := puntos[indice % puntos.size()].global_transform
	# Solo la POSICIÓN y el giro horizontal del marcador: si tiene escala o
	# inclinación, no se la pasamos al kart (rompería la física y la cámara).
	var giro_y := t.basis.orthonormalized().get_euler().y
	return Transform3D(Basis(Vector3.UP, giro_y), t.origin)


func _puntos_de_spawn() -> Array[Marker3D]:
	var resultado: Array[Marker3D] = []
	if _arena == null:
		return resultado
	# owned = false: los nodos de una escena instanciada no son "propios" de la raíz
	var contenedor := _arena.find_child(NODO_PUNTOS_SPAWN, true, false)
	if contenedor == null:
		return resultado
	for hijo in contenedor.get_children():
		if hijo is Marker3D:
			resultado.append(hijo)
	return resultado


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
