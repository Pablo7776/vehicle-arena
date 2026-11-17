extends Control

## Sala de espera (lobby): lista de jugadores, tu nombre, empezar y salir.
##
## Como el LobbyUIController de la clase 9: no le pregunta nada a la red.
## Se suscribe a las señales de NetworkManager y reacciona:
##   entraste_a_sala  -> se muestra
##   sala_actualizada -> redibuja la lista
##   partida_iniciada -> se oculta
##   saliste_de_sala  -> se oculta (el menú vuelve a verse solo)

@onready var titulo: Label = %Titulo
@onready var nombre_input: LineEdit = %NombreInput
@onready var boton_nombre: Button = %BotonNombre
@onready var lista: ItemList = %ListaJugadores
@onready var estado: Label = %Estado
@onready var boton_listo: Button = %BotonListo
@onready var boton_empezar: Button = %BotonEmpezar
@onready var boton_salir: Button = %BotonSalir


func _ready() -> void:
	hide()
	NetworkManager.entraste_a_sala.connect(_al_entrar)
	NetworkManager.sala_actualizada.connect(_refrescar)
	NetworkManager.partida_iniciada.connect(hide)
	NetworkManager.saliste_de_sala.connect(hide)

	boton_nombre.pressed.connect(_cambiar_nombre)
	nombre_input.text_submitted.connect(func(_texto): _cambiar_nombre())
	boton_listo.pressed.connect(_alternar_listo)
	boton_empezar.pressed.connect(NetworkManager.empezar_partida)
	boton_salir.pressed.connect(NetworkManager.salir_de_sala)


func _al_entrar() -> void:
	show()
	nombre_input.text = ""
	nombre_input.placeholder_text = NetworkManager.nombre_de(GDSync.get_client_id())
	_refrescar()


func _alternar_listo() -> void:
	var yo_listo: bool = NetworkManager.esta_listo(GDSync.get_client_id())
	NetworkManager.marcar_listo(not yo_listo)


func _cambiar_nombre() -> void:
	NetworkManager.cambiar_nombre(nombre_input.text)
	nombre_input.release_focus()


## Redibuja todo con el estado actual de la sala. Se llama cada vez que
## alguien entra, sale, cambia su nombre o marca "Listo".
func _refrescar() -> void:
	if not visible:
		return
	titulo.text = "Sala: " + NetworkManager.nombre_sala

	var mi_id := GDSync.get_client_id()
	var host_id := GDSync.get_host()
	var ids: Array = NetworkManager.jugadores_en_sala()

	lista.clear()
	for id in ids:
		var listo: bool = NetworkManager.esta_listo(id)
		var texto: String = ("✓  " if listo else "—  ") + NetworkManager.nombre_de(id)
		if id == host_id:
			texto += "  ★ host"
		if id == mi_id:
			texto += "  (vos)"
		lista.add_item(texto)

	# Mi botón de listo
	var yo_listo: bool = NetworkManager.esta_listo(mi_id)
	boton_listo.text = "Listo ✓" if yo_listo else "Marcar listo"

	# Solo el host ve "Empezar", y solo se habilita con todos listos
	var soy_host := GDSync.is_host()
	var se_puede: bool = NetworkManager.se_puede_empezar()
	boton_empezar.visible = soy_host
	boton_empezar.disabled = not se_puede

	var faltan: int = NetworkManager.cuantos_faltan_listos()
	if ids.size() < NetworkManager.MIN_JUGADORES:
		estado.text = "Esperando jugadores (mínimo %d)..." % NetworkManager.MIN_JUGADORES
	elif faltan > 0:
		estado.text = "Falta que %d jugador(es) marquen listo" % faltan
	elif soy_host:
		estado.text = "¡Todos listos! Podés empezar."
	else:
		estado.text = "¡Todos listos! Esperando al host..."
