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
	boton_empezar.pressed.connect(NetworkManager.empezar_partida)
	boton_salir.pressed.connect(NetworkManager.salir_de_sala)


func _al_entrar() -> void:
	show()
	nombre_input.text = ""
	nombre_input.placeholder_text = NetworkManager.nombre_de(GDSync.get_client_id())
	_refrescar()


func _cambiar_nombre() -> void:
	NetworkManager.cambiar_nombre(nombre_input.text)
	nombre_input.release_focus()


## Redibuja todo con el estado actual de la sala. Se llama cada vez que
## alguien entra, sale o cambia su nombre.
func _refrescar() -> void:
	if not visible:
		return
	titulo.text = "Sala: " + NetworkManager.nombre_sala

	var mi_id := GDSync.get_client_id()
	var host_id := GDSync.get_host()
	var ids : Array = NetworkManager.jugadores_en_sala()

	lista.clear()
	for id in ids:
		var texto : String = NetworkManager.nombre_de(id)
		if id == host_id:
			texto += "  ★ host"
		if id == mi_id:
			texto += "  (vos)"
		lista.add_item(texto)

	# Solo el host puede empezar
	var soy_host := GDSync.is_host()
	boton_empezar.visible = soy_host
	if soy_host:
		estado.text = "%d jugador(es). Empezá cuando estén todos." % ids.size()
	else:
		estado.text = "%d jugador(es). Esperando al host..." % ids.size()
