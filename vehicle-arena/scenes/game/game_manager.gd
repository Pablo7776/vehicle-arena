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
## Cuenta regresiva: una barra fina arriba al centro que se achica desde
## los dos lados hacia el medio (sin números). Se crea por código.
@export_group("Barra de tiempo")
## Ancho de la barra llena, como fracción del ancho de la pantalla
@export_range(0.1, 1.0) var ancho_barra_tiempo := 0.6
## Alto en píxeles y distancia al borde de arriba
@export var alto_barra_tiempo := 6.0
@export var margen_barra_tiempo := 12.0
@export var color_barra_tiempo := Color(0.85, 0.95, 1.0, 0.9)
## En los últimos segundos se pone roja y parpadea
@export var segundos_aviso := 30.0
@export var color_aviso := Color(1.0, 0.2, 0.15, 1.0)
@export_group("")
## Opcional: el botón "Volver a la sala". Si no asignás ninguno, se crea uno
## debajo del resultado.
@export var boton_volver: Button

var _terminada := false
var _tiempo_restante := DURACION
var _jabali: Node = null
var _barra_tiempo: ColorRect   # la parte que se achica


func _ready() -> void:
	add_to_group("game_manager")
	GDSync.expose_func(_mostrar_resultado, ENUMS.EXPOSE_PERMISSION.HOST)   # solo el host anuncia el resultado
	if label_resultado:
		label_resultado.hide()
	_crear_barra_tiempo()
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
	if _barra_tiempo == null:
		return
	# 1 = partida recién empezada, 0 = tiempo terminado.
	# La barra queda centrada: se achica igual de los dos lados hacia el medio.
	var mitad := ancho_barra_tiempo * (_tiempo_restante / DURACION) / 2.0
	_barra_tiempo.anchor_left = 0.5 - mitad
	_barra_tiempo.anchor_right = 0.5 + mitad
	if _tiempo_restante <= segundos_aviso:
		var c := color_aviso
		c.a = 0.4 + 0.6 * absf(sin(Time.get_ticks_msec() / 1000.0 * 5.0))   # parpadeo
		_barra_tiempo.color = c
	else:
		_barra_tiempo.color = color_barra_tiempo


# Riel tenue (el largo total) + la barra que se achica encima, arriba al centro
func _crear_barra_tiempo() -> void:
	var riel := _crear_franja(ancho_barra_tiempo, Color(1, 1, 1, 0.12))
	_barra_tiempo = _crear_franja(ancho_barra_tiempo, color_barra_tiempo)
	# En la misma capa que el resultado, para que se dibuje arriba del juego
	var padre: Node = label_resultado.get_parent() if label_resultado else self
	padre.add_child.call_deferred(riel)
	padre.add_child.call_deferred(_barra_tiempo)


func _crear_franja(ancho: float, color: Color) -> ColorRect:
	var franja := ColorRect.new()
	franja.color = color
	franja.mouse_filter = Control.MOUSE_FILTER_IGNORE   # no le quita toques al juego
	franja.anchor_left = 0.5 - ancho / 2.0
	franja.anchor_right = 0.5 + ancho / 2.0
	franja.anchor_top = 0.0
	franja.anchor_bottom = 0.0
	franja.offset_left = 0.0
	franja.offset_right = 0.0
	franja.offset_top = margen_barra_tiempo
	franja.offset_bottom = margen_barra_tiempo + alto_barra_tiempo
	return franja


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
