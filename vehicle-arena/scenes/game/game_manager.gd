extends Node

## Reglas de la partida "Cazar al jabalí":
##   - Dura DURACION segundos.
##   - El primero que mata al jabalí gana.
##   - Si se acaba el tiempo, el jabalí se escapa y pierden todos.
##
## RED (clase 8, "estado del mundo compartido"): SOLO EL HOST DECIDE.
##   - El host escucha la muerte del jabalí (died solo se emite en el host)
##     y sabe quién dio el último golpe (HealthComponent.ultimo_atacante).
##   - El reloj corre en todas las máquinas para mostrar la cuenta regresiva,
##     pero solo el del host termina la partida.
##   - El resultado se avisa a todos con call_func (un evento puntual).

## Duración de la partida en segundos
const DURACION := 180.0
## Resultado especial: nadie cazó al jabalí. Es -2 (y no -1) porque sin conexión
## (botón Test) el ID del jugador es -1, y se confundiría con "nadie".
const NADIE := -2

## Se emite en TODAS las máquinas cuando termina la partida
## (cazador = ID del que lo cazó, o NADIE si se escapó)
signal partida_terminada(cazador: int)

@export var label_resultado: Label
## Opcional: un Label para la cuenta regresiva. Si no asignás ninguno,
## se crea uno arriba al centro, en la misma capa que el resultado.
@export var label_tiempo: Label
## Opcional: el botón "Volver a la sala". Si no asignás ninguno, se crea uno
## debajo del resultado.
@export var boton_volver: Button

var _terminada := false
var _tiempo_restante := DURACION
var _jabali: Node = null


func _ready() -> void:
	add_to_group("game_manager")
	GDSync.expose_func(_mostrar_resultado, ENUMS.EXPOSE_PERMISSION.HOST)   # solo el host anuncia el resultado
	if label_resultado:
		label_resultado.hide()
	if label_tiempo == null:
		label_tiempo = _crear_label_tiempo()
	if boton_volver == null:
		boton_volver = _crear_boton_volver()
	boton_volver.hide()
	boton_volver.pressed.connect(NetworkManager.volver_a_sala)
	# Si el host se va en la pantalla final, el nuevo host pasa a tener el botón
	GDSync.host_changed.connect(func(_es_host, _nuevo_host): _actualizar_boton_volver())

	# El jabalí está en la misma partida (main.tscn). died solo se emite en el host.
	_jabali = get_tree().get_first_node_in_group("jabali")
	if _jabali == null:
		push_warning("game_manager: no encontré ningún nodo en el grupo 'jabali'")
		return
	# El jabalí está DESPUÉS en el árbol: puede que todavía no corrió su _ready
	# (y su variable health siga vacía). Lo esperamos, como hicimos con el HUD.
	if not _jabali.is_node_ready():
		await _jabali.ready
	_jabali.health.died.connect(_al_cazar_jabali)


func _process(delta: float) -> void:
	if _terminada:
		return
	_tiempo_restante = maxf(_tiempo_restante - delta, 0.0)
	_mostrar_tiempo()
	# Todos ven la cuenta regresiva, pero solo el host decide que se terminó
	if _tiempo_restante <= 0.0 and GDSync.is_host():
		_terminar(NADIE)


# ---- Decisiones (solo el host) -------------------------------------------------

func _al_cazar_jabali() -> void:
	if not GDSync.is_host():
		return
	_terminar(_jabali.health.ultimo_atacante)


func _terminar(cazador: int) -> void:
	if _terminada:
		return
	_mostrar_resultado(cazador)                     # el host
	GDSync.call_func(_mostrar_resultado, [cazador]) # los demás


# ---- Lo que ven todos -----------------------------------------------------------

# Los parámetros llegan empaquetados en un Array
func _mostrar_resultado(data = null) -> void:
	if _terminada:
		return
	_terminada = true
	var cazador: int = int(data[0]) if data is Array else int(data)

	# Los karts se quedan quietos y dejan de disparar
	get_tree().call_group("vehiculos", "detener")
	# El jabalí deja de moverse; si lo cazaron, desaparece
	if _jabali:
		_jabali.bt_player.active = false
		if cazador != NADIE:
			_jabali.hide()

	if label_resultado:
		label_resultado.show()
		if cazador == NADIE:
			label_resultado.text = "¡El jabalí se escapó!"
		elif cazador == GDSync.get_client_id():
			label_resultado.text = "¡Cazaste al jabalí!"
		else:
			label_resultado.text = "¡%s cazó al jabalí!" % NetworkManager.nombre_de(cazador)

	# Solo el host puede volver a la sala (así vuelven todos juntos)
	boton_volver.show()
	_actualizar_boton_volver()

	partida_terminada.emit(cazador)


func _actualizar_boton_volver() -> void:
	if boton_volver == null:
		return
	var soy_host: bool = GDSync.is_host()
	boton_volver.disabled = not soy_host
	boton_volver.text = "Volver a la sala" if soy_host else "Esperando al host..."


func _mostrar_tiempo() -> void:
	if label_tiempo == null:
		return
	var segundos := ceili(_tiempo_restante)
	label_tiempo.text = "%d:%02d" % [segundos / 60, segundos % 60]
	# Los últimos 30 segundos, en rojo
	label_tiempo.modulate = Color.RED if segundos <= 30 else Color.WHITE


func _crear_label_tiempo() -> Label:
	var label := Label.new()
	label.name = "LabelTiempo"
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 6)
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	label.offset_top = 8
	# En la misma capa que el resultado, para que se dibuje arriba del juego
	var padre: Node = label_resultado.get_parent() if label_resultado else self
	padre.add_child.call_deferred(label)
	return label


func _crear_boton_volver() -> Button:
	var boton := Button.new()
	boton.name = "BotonVolver"
	boton.add_theme_font_size_override("font_size", 22)
	boton.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	boton.grow_horizontal = Control.GROW_DIRECTION_BOTH
	boton.grow_vertical = Control.GROW_DIRECTION_BEGIN
	boton.offset_bottom = -24
	var padre: Node = label_resultado.get_parent() if label_resultado else self
	padre.add_child.call_deferred(boton)
	return boton
