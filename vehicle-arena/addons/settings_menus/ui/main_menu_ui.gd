class_name MainMenuUI
extends Control

signal play_pressed
signal quit_pressed

@export var theme_data: MenuTheme
@export_file("*.tscn") var play_scene_path: String = ""
@export var show_options: bool = true
@export var show_credits: bool = true
@export var show_quit: bool = true
@export var escena_jugador: PackedScene
@export var escena_arena: PackedScene
var _sala_input: LineEdit
var _status_label: Label
var _options_layer: CanvasLayer
var _credits_layer: CanvasLayer
var _options_ui: OptionsMenuUI
var _credits_ui: CreditsUI
var _first_button: Button
var _btn_join: Button
var _focus_return: Control
var arena_instanciada: Node = null
# --- Variables de Red ---
var nombre_sala := "MiSala"
var soy_host := false

func _ready() -> void:
	if theme_data == null:
		theme_data = MenuTheme.new()
	_build()
	_apply_font_scale()
	focus_default()

	# Conectar señales de GDSync
	GDSync.connected.connect(_al_conectar)
	GDSync.connection_failed.connect(_conexion_fallida)
	GDSync.lobby_created.connect(_sala_creada)
	GDSync.lobby_creation_failed.connect(_sala_fallo)
	GDSync.lobby_join_failed.connect(_union_fallo)
	GDSync.client_joined.connect(_cliente_entro)

	_actualizar_log("SISTEMA DE RED LISTO")

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and _first_button != null and is_visible_in_tree():
		focus_default()

func focus_default() -> void:
	if _first_button != null:
		call_deferred("_grab_if_shown", _first_button)

func _grab_if_shown(c: Control) -> void:
	if is_instance_valid(c) and c.is_visible_in_tree():
		c.grab_focus()

func _build() -> void:
	var bg := ColorRect.new()
	bg.color = theme_data.bg_color
	bg.anchor_right = 1
	bg.anchor_bottom = 1
	add_child(bg)
	if theme_data.background_texture != null:
		var bg_tex := TextureRect.new()
		bg_tex.texture = theme_data.background_texture
		bg_tex.anchor_right = 1
		bg_tex.anchor_bottom = 1
		bg_tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		bg_tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		bg_tex.modulate = Color(1, 1, 1, 0.6)
		add_child(bg_tex)

	var center := CenterContainer.new()
	center.anchor_right = 1
	center.anchor_bottom = 1
	add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", theme_data.panel_stylebox())
	panel.custom_minimum_size = Vector2(theme_data.menu_max_width, 0)
	center.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	panel.add_child(col)

	var title := Label.new()
	title.text = theme_data.game_title
	title.add_theme_font_size_override("font_size", theme_data.title_font_size)
	title.add_theme_color_override("font_color", theme_data.text)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)

	if theme_data.game_subtitle != "":
		var sub := Label.new()
		sub.text = theme_data.game_subtitle
		sub.add_theme_font_size_override("font_size", theme_data.body_font_size)
		sub.add_theme_color_override("font_color", theme_data.text_dim)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sub.custom_minimum_size = Vector2(theme_data.menu_max_width - 32, 0)
		col.add_child(sub)

	col.add_child(_spacer(8))
	
	# Adaptado para GD-Sync: Input de Nombre de Sala
	_sala_input = LineEdit.new()
	_sala_input.placeholder_text = "Nombre de la Sala (ej. Arena01)"
	_sala_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sala_input.custom_minimum_size = Vector2(0, 40)
	col.add_child(_sala_input)
	
	col.add_child(_spacer(8))
	
	# Botones principales GDSync
	_first_button = _add_button(col, "Crear Sala (Host)", _on_host)
	_btn_join = _add_button(col, "Unirse a Partida", _on_join)
	
	if show_options:
		_add_button(col, "Opciones", _open_options)
	if show_credits:
		_add_button(col, "Créditos", _open_credits)
	if show_quit:
		_add_button(col, "Salir", _on_quit)

	col.add_child(_spacer(8))
	
	# Label para los logs de red (Reemplaza label_log)
	_status_label = Label.new()
	_status_label.text = ""
	_status_label.add_theme_font_size_override("font_size", theme_data.body_font_size)
	_status_label.add_theme_color_override("font_color", theme_data.text_dim)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_status_label)

func _add_button(parent: Container, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	theme_data.apply_to_button(b)
	parent.add_child(b)
	return b

func _spacer(h: int) -> Control:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	return s

func _apply_font_scale() -> void:
	var settings := get_node_or_null("/root/Settings")
	if settings == null: return
	var scale: float = settings.get_font_scale()
	if not is_equal_approx(scale, 1.0):
		_scale_fonts(self, scale)

func _scale_fonts(node: Node, scale: float) -> void:
	if node is Label or node is Button:
		var fs: int = int(node.get_theme_font_size("font_size"))
		if fs > 0:
			node.add_theme_font_size_override("font_size", maxi(8, int(round(fs * scale))))
	for c in node.get_children():
		_scale_fonts(c, scale)

# ---- Acciones UI Base --------------------------------------------------------

func _on_quit() -> void:
	quit_pressed.emit()
	get_tree().quit()

func _open_options() -> void:
	_focus_return = get_viewport().gui_get_focus_owner()
	if _options_layer == null:
		_options_layer = CanvasLayer.new()
		add_child(_options_layer)
		_options_ui = OptionsMenuUI.new()
		_options_ui.theme_data = theme_data
		_options_ui.close_requested.connect(_close_options)
		_options_layer.add_child(_options_ui)
	_options_layer.visible = true
	if _options_ui != null:
		_options_ui.visible = true
		_options_ui.focus_default()

func _close_options() -> void:
	if _options_layer != null: _options_layer.visible = false
	if _options_ui != null: _options_ui.visible = false
	_restore_focus()

func _open_credits() -> void:
	_focus_return = get_viewport().gui_get_focus_owner()
	if _credits_layer == null:
		_credits_layer = CanvasLayer.new()
		add_child(_credits_layer)
		_credits_ui = CreditsUI.new()
		_credits_ui.theme_data = theme_data
		_credits_ui.close_requested.connect(_close_credits)
		_credits_layer.add_child(_credits_ui)
	_credits_layer.visible = true
	if _credits_ui != null:
		_credits_ui.visible = true
		_credits_ui.focus_default()

func _close_credits() -> void:
	if _credits_layer != null: _credits_layer.visible = false
	if _credits_ui != null: _credits_ui.visible = false
	_restore_focus()

func _restore_focus() -> void:
	if is_instance_valid(_focus_return):
		_focus_return.grab_focus()
	elif _first_button != null:
		_first_button.grab_focus()
	_focus_return = null

# ---- Lógica de Red (GD-Sync) ------------------------------------------------

func _leer_nombre_sala() -> void:
	if _sala_input:
		var texto := _sala_input.text.strip_edges()
		if not texto.is_empty():
			nombre_sala = texto

func _bloquear_menu(bloqueado: bool) -> void:
	if _first_button: _first_button.disabled = bloqueado
	if _btn_join: _btn_join.disabled = bloqueado
	if _sala_input: _sala_input.editable = not bloqueado

func _on_host() -> void:
	_leer_nombre_sala()
	soy_host = true
	_bloquear_menu(true)
	_actualizar_log("CONECTANDO (host)...")
	GDSync.start_multiplayer()

func _on_join() -> void:
	_leer_nombre_sala()
	soy_host = false
	_bloquear_menu(true)
	_actualizar_log("CONECTANDO (cliente)...")
	GDSync.start_multiplayer()

func _al_conectar() -> void:
	_actualizar_log("CONECTADO. Sala: " + nombre_sala)
	if soy_host:
		GDSync.lobby_create(nombre_sala, "", true, 4)
	else:
		GDSync.lobby_join(nombre_sala, "")

func _sala_creada(lobby_name: String) -> void:
	_actualizar_log("SALA CREADA: " + lobby_name)
	GDSync.lobby_join(lobby_name, "")

func _cliente_entro(client_id: int) -> void:
	_actualizar_log("JUGADOR ENTRO: " + str(client_id))
	
	var es_mio := client_id == GDSync.get_client_id()
	
	# 1. Si el que acaba de entrar soy yo mismo:
	if es_mio:
		self.hide() # Ocultamos el menú
		
		# Generamos la Arena 3D si asignaste una y si no existe ya
		if escena_arena and arena_instanciada == null:
			arena_instanciada = escena_arena.instantiate()
			get_tree().current_scene.call_deferred("add_child", arena_instanciada)
			
	# 2. Generamos el vehículo
	if escena_jugador:
		var jugador = escena_jugador.instantiate()
		jugador.name = str(client_id)
		
		# Asignamos posición y lo añadimos a la escena actual
		jugador.position = Vector3((client_id % 5) * 4.0, 2.0, 0.0) 
		get_tree().current_scene.call_deferred("add_child", jugador)
		
		GDSync.set_gdsync_owner(jugador, client_id)

		# Buscamos y activamos la cámara si es nuestro vehículo
		var cam = jugador.find_child("Camera3D", true, false)
		if cam:
			cam.current = es_mio
		else:
				print("ERROR: Falta asignar 'Escena Jugador' en el Inspector.")

func _cliente_salio(client_id: int) -> void:
	_actualizar_log("JUGADOR SALIO: " + str(client_id))
	var nodo = get_tree().current_scene.get_node_or_null(str(client_id))
	if nodo:
		nodo.queue_free()
			
func _conexion_fallida(error: int) -> void:
	_actualizar_log("FALLO LA CONEXIÓN: " + str(error))
	_bloquear_menu(false)

func _sala_fallo(_lobby_name: String, error: int) -> void:
	_actualizar_log("NO SE PUDO CREAR LA SALA: " + str(error))
	_bloquear_menu(false)

func _union_fallo(_lobby_name: String, error: int) -> void:
	_actualizar_log("NO SE PUDO ENTRAR A LA SALA: " + str(error))
	_bloquear_menu(false)

func _actualizar_log(texto: String) -> void:
	print(texto)
	if _status_label:
		_status_label.text = texto
