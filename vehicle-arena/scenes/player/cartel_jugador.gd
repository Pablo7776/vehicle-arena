extends Label3D

## Cartel sobre el kart del jugador: "TÚ" o su nombre, y su vida.
## Va en el Label3D del kart, asignado desde la escena del jugador (player.tscn).
##
## Lee el estado que ya está en red (dueño, nombre, vida) y lo muestra.
## No espera avisos de nadie: como dice la clase 10, la UI lee el estado.

## Color del cartel sobre TU kart (los demás usan el color que ya tenga el Label3D)
@export var color_propio := Color(6.0, 5.0, 0.0)

var _health: HealthComponent
var _color_ajeno: Color


func _ready() -> void:
	# El Label3D es hijo del kart, que es el que tiene la vida
	_health = get_parent().get_node("HealthComponent")
	_color_ajeno = modulate

	_health.health_changed.connect(func(_actual, _maximo): _actualizar())
	# El dueño se asigna DESPUÉS de crear el kart, así que escuchamos cuando cambia
	# (como OnNetworkSpawn en la clase 10: recién ahí se sabe de quién es).
	GDSync.connect_gdsync_owner_changed(self, func(_dueno): _actualizar())
	# Si un jugador cambia su nombre (por ejemplo, en el lobby), se actualiza solo
	GDSync.player_data_changed.connect(_al_cambiar_datos_jugador)
	_actualizar()


func _actualizar() -> void:
	var es_mio := GDSync.is_gdsync_owner(self)
	var nombre := "TÚ" if es_mio else _nombre_del_dueno()
	text = "%s\nHP: %d / %d" % [nombre, _health.current, _health.max_health]
	modulate = color_propio if es_mio else _color_ajeno


func _nombre_del_dueno() -> String:
	var dueno := GDSync.get_gdsync_owner(self)
	if dueno < 0:
		return ""
	# El nombre lo va a poner cada jugador en el lobby (player_set_username).
	# Mientras no tenga uno, mostramos "Jugador" + las últimas cifras de su ID.
	return GDSync.player_get_username(dueno, "Jugador %d" % (dueno % 1000))


func _al_cambiar_datos_jugador(client_id: int, clave: String, _valor) -> void:
	if clave == "Username" and client_id == GDSync.get_gdsync_owner(self):
		_actualizar()
