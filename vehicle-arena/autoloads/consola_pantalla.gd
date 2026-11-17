extends CanvasLayer

## Muestra en pantalla lo que se imprime en la consola (print, push_warning,
## errores), para poder verlo en la build y en el celular.
##
## Se abre y se cierra con F1 o con el botón "LOG" (arriba a la derecha).
## El texto aparece abajo a la derecha.
## Arranca visible solo en el editor; en la build arranca oculta.
##
## Cómo funciona: Godot permite agregar un "Logger" propio (OS.add_logger).
## Godot le pasa cada mensaje que se imprime, y acá lo agregamos a un Label.

## Cuántas líneas se muestran como máximo (las más viejas se van borrando)
@export var max_lineas := 12

var _lineas: Array[String] = []
var _panel: PanelContainer
var _texto: Label


func _ready() -> void:
	layer = 100   # arriba de todo: menú, sala, HUD
	process_mode = Node.PROCESS_MODE_ALWAYS
	_crear_interfaz()
	_panel.visible = OS.is_debug_build()

	var logger := _LoggerPantalla.new()
	logger.consola = self
	OS.add_logger(logger)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		_alternar()


func _alternar() -> void:
	_panel.visible = not _panel.visible


## Lo llama el logger. Puede venir de otro hilo, por eso siempre llega diferido.
func _agregar(texto: String, color_error: bool) -> void:
	texto = texto.strip_edges()
	if texto.is_empty():
		return
	if color_error:
		texto = "⚠ " + texto
	_lineas.append(texto)
	while _lineas.size() > max_lineas:
		_lineas.pop_front()
	_texto.text = "\n".join(_lineas)


func _crear_interfaz() -> void:
	# Panel semitransparente abajo a la derecha
	_panel = PanelContainer.new()
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0, 0, 0, 0.6)
	fondo.set_content_margin_all(4)
	_panel.add_theme_stylebox_override("panel", fondo)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE   # no tapa los clics del juego
	_panel.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN   # crece hacia la izquierda
	_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN     # crece hacia arriba
	_panel.offset_right = -4
	_panel.offset_bottom = -4
	add_child(_panel)

	_texto = Label.new()
	_texto.add_theme_font_size_override("font_size", 7)
	_texto.custom_minimum_size = Vector2(260, 0)
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_texto)

	# Botón chiquito para abrir y cerrar (sirve en el celular, que no tiene F1)
	var boton := Button.new()
	boton.text = "LOG"
	boton.add_theme_font_size_override("font_size", 7)
	boton.focus_mode = Control.FOCUS_NONE
	boton.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	boton.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	boton.offset_right = -4
	boton.offset_top = 4
	boton.pressed.connect(_alternar)
	add_child(boton)


## Recibe todo lo que Godot imprime y se lo pasa a la consola en pantalla.
class _LoggerPantalla extends Logger:
	var consola: Node

	func _log_message(message: String, error: bool) -> void:
		consola._agregar.call_deferred(message, error)

	func _log_error(_function: String, file: String, line: int, code: String, rationale: String,
			_editor_notify: bool, error_type: int, _script_backtraces: Array) -> void:
		var texto := rationale if not rationale.is_empty() else code
		var tipo := "AVISO" if error_type == ERROR_TYPE_WARNING else "ERROR"
		# Si el error viene del motor (archivo .cpp), el lugar no le sirve al jugador
		var donde := "" if file.ends_with(".cpp") or file.ends_with(".h") else " (%s:%d)" % [file.get_file(), line]
		consola._agregar.call_deferred("%s: %s%s" % [tipo, texto, donde], true)
