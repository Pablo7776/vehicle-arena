extends Label3D

## Cartel sobre el kart del jugador.
##   Tu kart:           "TÚ" y tus balas
##   Karts de los demás: su nombre
## Va en el Label3D del kart, asignado desde la escena del jugador (player.tscn).
##
## Lee el estado que ya está en red (dueño, nombre) y lo muestra.
## No espera avisos de nadie: como dice la clase 10, la UI lee el estado.
## Las balas solo se muestran en TU kart: la munición la lleva cada dueño
## en su máquina y no viaja por red (no hace falta: es información tuya).

## Color del cartel sobre TU kart (los demás usan el color que ya tenga el Label3D)
@export var color_propio := Color(6.0, 5.0, 0.0)

var _weapon: Weapon
var _color_ajeno: Color


func _ready() -> void:
	# El Label3D es hijo del kart, que es el que tiene el arma
	_weapon = get_parent().get_node("weapon")
	_color_ajeno = modulate

	_weapon.municion_cambiada.connect(func(_actual, _maxima): _actualizar())
	# El dueño se asigna DESPUÉS de crear el kart, así que escuchamos cuando cambia
	# (como OnNetworkSpawn en la clase 10: recién ahí se sabe de quién es).
	GDSync.connect_gdsync_owner_changed(self, func(_dueno): _actualizar())
	# Si un jugador cambia su nombre (por ejemplo, en el lobby), se actualiza solo
	GDSync.player_data_changed.connect(_al_cambiar_datos_jugador)
	# Diferido: el arma es un nodo hermano que puede estar listo DESPUÉS que el cartel
	# (recién en su _ready carga la munición inicial)
	_actualizar.call_deferred()


func _actualizar() -> void:
	var es_mio: bool = GDSync.is_gdsync_owner(self)
	if es_mio:
		text = "%d balas" % _weapon.municion_actual
	else:
		text = _nombre_del_dueno()
	modulate = color_propio if es_mio else _color_ajeno


func _nombre_del_dueno() -> String:
	var dueno: int = GDSync.get_gdsync_owner(self)
	if dueno < 0:
		return "Jugador"
	return NetworkManager.nombre_de(dueno)


func _al_cambiar_datos_jugador(client_id: int, clave: String, _valor) -> void:
	if clave == "Username" and client_id == GDSync.get_gdsync_owner(self):
		_actualizar()
