extends Node

const PORT := 7777
const MAX_PLAYERS := 8

signal player_connected(peer_id: int)
signal player_disconnected(peer_id: int)
signal connection_failed
signal connection_succeeded

func _ready() -> void:
	# Conectar señales nativas de GD-Sync para lobbies
	if GDSync:
		# Nota: Dependiendo de la versión exacta del plugin de GD-Sync, 
		# algunas de estas señales se configuran aquí o se escuchan directamente.
		pass

# Crear una sala (Lobby)
func host_game(lobby_name: String = "Sala de Damián", password: String = "", public: bool = true, player_limit: int = 4) -> void:
	# GD-Sync permite crear lobbies públicos o privados fácilmente
	GDSync.lobby_create(lobby_name, password, public, player_limit, {})
	print("Intentando crear el lobby: ", lobby_name)
	
	# Opcional: Tras crear el lobby con GDSync.lobby_create(), 
	# la API suele requerir unirse inmediatamente a la sala recién creada (dentro de los primeros segundos).
	# Puedes autounirte llamando a join_game(lobby_name, password) justo después si tu versión lo requiere.

# Unirse a una sala existente por nombre/ID
func join_game(lobby_name: String, password: String = "") -> void:
	print("Intentando unirse al lobby: ", lobby_name)
	GDSync.lobby_join(lobby_name, password)

# Obtener la lista de salas públicas disponibles para mostrar en pantalla
func fetch_public_lobbies() -> void:
	GDSync.get_public_lobbies()
func _on_peer_connected(id: int) -> void:
	player_connected.emit(id)

func _on_peer_disconnected(id: int) -> void:
	player_disconnected.emit(id)
